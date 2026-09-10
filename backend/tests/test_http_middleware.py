from unittest.mock import AsyncMock

from httpx import ASGITransport, AsyncClient
from redis.exceptions import ConnectionError as RedisConnectionError

from app.core.config import get_settings
from app.core.http_middleware import RequestMiddleware
from app.main import create_app


async def test_fixed_window_rate_limit_and_retry_after(monkeypatch):
    monkeypatch.setattr(get_settings(), "rate_limit_enabled", True)
    application = create_app()
    fake = AsyncMock()
    fake.eval.return_value = 11
    # Replace the constructed client, without making network calls.
    for middleware in application.user_middleware:
        if middleware.cls is RequestMiddleware:
            middleware.kwargs["redis"] = fake
    async with AsyncClient(
        transport=ASGITransport(app=application), base_url="http://test"
    ) as client:
        response = await client.post("/v1/auth/direct", json={})
        assert response.status_code == 429
        assert 1 <= int(response.headers["Retry-After"]) <= 60
        assert response.headers["X-Request-ID"]
    assert fake.eval.call_args.args[-1] == 120
    await application.state.redis.aclose()


async def test_redis_failure_allows_request_and_error_is_structured(monkeypatch):
    monkeypatch.setattr(get_settings(), "rate_limit_enabled", True)
    application = create_app()
    fake = AsyncMock()
    fake.eval.side_effect = RedisConnectionError("offline")
    for middleware in application.user_middleware:
        if middleware.cls is RequestMiddleware:
            middleware.kwargs["redis"] = fake

    @application.get("/v1/test-error")
    async def fail():
        raise RuntimeError("private internal details")

    async with AsyncClient(
        transport=ASGITransport(app=application), base_url="http://test"
    ) as client:
        response = await client.get("/v1/test-error")
        assert response.status_code == 500
        assert response.json()["error"]["code"] == "INTERNAL_ERROR"
        assert "private internal details" not in response.text
        assert response.headers["X-Request-ID"] == response.json()["error"]["request_id"]
    await application.state.redis.aclose()
