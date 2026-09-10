import hashlib
import time
import uuid
from contextlib import suppress

import structlog
from fastapi import HTTPException
from redis.asyncio import Redis
from redis.exceptions import RedisError
from starlette.middleware.base import BaseHTTPMiddleware, RequestResponseEndpoint
from starlette.requests import Request
from starlette.responses import JSONResponse, Response

from app.core.config import get_settings
from app.core.security import decode_dev_access_token

log = structlog.get_logger()
WINDOW_SCRIPT = """
local count = redis.call('INCR', KEYS[1])
if count == 1 then redis.call('EXPIRE', KEYS[1], ARGV[1]) end
return count
"""


def configure_logging() -> None:
    structlog.configure(
        processors=[
            structlog.processors.TimeStamper(fmt="iso", utc=True),
            structlog.processors.add_log_level,
            structlog.processors.JSONRenderer(),
        ],
        logger_factory=structlog.PrintLoggerFactory(),
        cache_logger_on_first_use=True,
    )


class RequestMiddleware(BaseHTTPMiddleware):
    def __init__(self, app: object, redis: Redis) -> None:
        super().__init__(app)
        self.redis = redis
        self._last_redis_warning = float("-inf")

    async def dispatch(self, request: Request, call_next: RequestResponseEndpoint) -> Response:
        started = time.monotonic()
        request_id = uuid.uuid4().hex
        try:
            limited = await self._limit(request)
            response = limited if limited is not None else await call_next(request)
        except Exception as exc:
            # Never log request bodies, tokens, email addresses or route samples.
            log.error("request_failed", request_id=request_id, error_type=type(exc).__name__)
            response = JSONResponse(
                {
                    "error": {
                        "code": "INTERNAL_ERROR",
                        "message": "An unexpected error occurred",
                        "request_id": request_id,
                    }
                },
                status_code=500,
            )
        response.headers["X-Request-ID"] = request_id
        route = request.scope.get("route")
        log.info(
            "request_completed",
            request_id=request_id,
            method=request.method,
            path=getattr(route, "path", "/unmatched"),
            status=response.status_code,
            duration_ms=round((time.monotonic() - started) * 1000, 2),
        )
        return response

    async def _limit(self, request: Request) -> Response | None:
        settings = get_settings()
        if not settings.rate_limit_enabled or not request.url.path.startswith("/v1"):
            return None
        ip = request.client.host if request.client else "unknown"
        identity = f"ip:{ip}"
        auth = request.url.path == "/v1/auth/direct"
        if not auth:
            header = request.headers.get("authorization", "")
            if header.lower().startswith("bearer "):
                with suppress(HTTPException):
                    identity = f"user:{decode_dev_access_token(header[7:])}"
        budget = settings.rate_limit_auth_per_minute if auth else settings.rate_limit_api_per_minute
        now = int(time.time())
        digest = hashlib.sha256(identity.encode()).hexdigest()
        key = f"runova:limit:{'auth' if auth else 'api'}:{digest}:{now // 60}"
        try:
            count = int(await self.redis.eval(WINDOW_SCRIPT, 1, key, 120))
        except (RedisError, OSError):
            if time.monotonic() - self._last_redis_warning > 60:
                log.warning("rate_limit_unavailable", action="allow")
                self._last_redis_warning = time.monotonic()
            return None
        if count > budget:
            return JSONResponse(
                {"detail": "Too many requests. Please retry shortly."},
                status_code=429,
                headers={"Retry-After": str(60 - now % 60)},
            )
        return None
