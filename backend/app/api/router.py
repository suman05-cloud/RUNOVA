from fastapi import APIRouter

from app.api.routes.auth import router as auth_router
from app.api.routes.health import router as health_router
from app.api.routes.leaderboards import router as leaderboard_router
from app.api.routes.runs import router as runs_router
from app.api.routes.territories import router as territories_router

api_router = APIRouter()
api_router.include_router(health_router)
api_router.include_router(auth_router, prefix="/v1")
api_router.include_router(runs_router, prefix="/v1")
api_router.include_router(leaderboard_router, prefix="/v1")
api_router.include_router(territories_router, prefix="/v1")
