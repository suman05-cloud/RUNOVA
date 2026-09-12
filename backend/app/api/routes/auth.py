from datetime import UTC, datetime
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import CurrentUserId, create_dev_access_token
from app.db.session import get_db_session
from app.modules.profiles.models import Account, Profile
from app.modules.profiles.schemas import (
    DevLoginRequest,
    LoginResponse,
    ProfileResponse,
    ProfileUpdateRequest,
)
from app.modules.profiles.service import UsernameUnavailableError, direct_login
from app.modules.progression.models import PlayerProgress
from app.modules.progression.schemas import ProgressResponse
from app.modules.progression.service import current_streak, refresh_city_scores
from app.modules.territories.game import expire_territories
from app.modules.territories.models import Territory

router = APIRouter(tags=["authentication"])
SessionDependency = Annotated[AsyncSession, Depends(get_db_session)]


@router.post("/auth/direct", response_model=LoginResponse)
async def development_login(
    request: DevLoginRequest,
    session: SessionDependency,
) -> LoginResponse:
    if not get_settings().dev_login_enabled:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND)
    try:
        profile = await direct_login(session, request)
    except UsernameUnavailableError as exc:
        raise HTTPException(
            status_code=status.HTTP_409_CONFLICT,
            detail="Username is already taken",
        ) from exc
    token, expires_at = create_dev_access_token(profile.id)
    account = await session.get(Account, profile.id)
    if account is None:
        raise HTTPException(status_code=500, detail="Account record is missing")
    return LoginResponse(
        access_token=token,
        expires_at=expires_at,
        profile=_profile_response(profile, account.email),
    )


@router.get("/me", response_model=ProfileResponse)
async def current_profile(
    user_id: CurrentUserId,
    session: SessionDependency,
) -> ProfileResponse:
    profile = await session.get(Profile, user_id)
    if profile is None:
        raise HTTPException(status_code=status.HTTP_404_NOT_FOUND, detail="Profile not found")
    account = await session.get(Account, user_id)
    if account is None:
        raise HTTPException(status_code=500, detail="Account record is missing")
    return _profile_response(profile, account.email)


@router.get("/me/progression", response_model=ProgressResponse)
async def current_progression(
    user_id: CurrentUserId,
    session: SessionDependency,
) -> ProgressResponse:
    await expire_territories(session)
    progress = await session.get(PlayerProgress, user_id)
    owned = (
        await session.scalar(
            select(func.count()).select_from(Territory).where(Territory.owner_id == user_id)
        )
        or 0
    )
    territory_points = await session.scalar(
        select(func.coalesce(func.sum(Territory.reward_points), 0)).where(
            Territory.owner_id == user_id
        )
    )
    await session.commit()
    if progress is None:
        return ProgressResponse(
            fitness_xp=0,
            level=1,
            current_streak_days=0,
            longest_streak_days=0,
            territories_owned=owned,
            territory_points=territory_points,
        )
    return ProgressResponse(
        fitness_xp=progress.fitness_xp,
        level=progress.level,
        current_streak_days=current_streak(progress, datetime.now(UTC)),
        longest_streak_days=progress.longest_streak_days,
        territories_owned=owned,
        territory_points=territory_points,
    )


@router.patch("/me", response_model=ProfileResponse)
async def update_profile(
    request: ProfileUpdateRequest,
    user_id: CurrentUserId,
    session: SessionDependency,
) -> ProfileResponse:
    profile = await session.scalar(select(Profile).where(Profile.id == user_id).with_for_update())
    account = await session.get(Account, user_id)
    if profile is None or account is None:
        raise HTTPException(status_code=404, detail="Profile not found")
    changes = request.model_dump(exclude_unset=True)
    for key, value in changes.items():
        if key in {"country_code", "profile_is_public"} and value is None:
            raise HTTPException(status_code=422, detail=f"{key} cannot be null")
        if isinstance(value, str):
            value = value.strip()
            if not value:
                raise HTTPException(status_code=422, detail=f"{key} cannot be blank")
            if key == "country_code":
                value = value.upper()
        setattr(profile, key, value)
    await session.flush()
    if "city" in changes:
        await refresh_city_scores(session, user_id)
    await session.commit()
    return _profile_response(profile, account.email)


def _profile_response(profile: Profile, email: str) -> ProfileResponse:
    return ProfileResponse(
        id=profile.id,
        email=email,
        username=profile.username,
        display_name=profile.display_name,
        country_code=profile.country_code,
        city=profile.city,
        state_region=profile.state_region,
        profile_is_public=profile.profile_is_public,
    )
