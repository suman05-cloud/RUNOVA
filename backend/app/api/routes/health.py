from typing import Annotated, Literal

from fastapi import APIRouter, Depends, HTTPException, status
from pydantic import BaseModel
from sqlalchemy import text
from sqlalchemy.exc import SQLAlchemyError
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import Settings, get_settings
from app.db.session import get_db_session

router = APIRouter(prefix="/health", tags=["health"])
SettingsDependency = Annotated[Settings, Depends(get_settings)]
SessionDependency = Annotated[AsyncSession, Depends(get_db_session)]


class HealthResponse(BaseModel):
    status: Literal["ok"] = "ok"
    service: str
    version: str


@router.get("/live", response_model=HealthResponse)
async def liveness(settings: SettingsDependency) -> HealthResponse:
    return HealthResponse(service=settings.app_name, version=settings.version)


@router.get("/ready", response_model=HealthResponse)
async def readiness(
    settings: SettingsDependency,
    session: SessionDependency,
) -> HealthResponse:
    try:
        await session.execute(text("SELECT 1"))
    except SQLAlchemyError as exc:
        raise HTTPException(
            status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
            detail="Database is unavailable",
        ) from exc
    return HealthResponse(service=settings.app_name, version=settings.version)
