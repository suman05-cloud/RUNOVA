import asyncio

from app.api.routes.health import liveness
from app.core.config import get_settings


def test_liveness() -> None:
    response = asyncio.run(liveness(get_settings()))

    assert response.model_dump() == {
        "status": "ok",
        "service": "Runova API",
        "version": "0.1.0",
    }
