from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.config import get_settings
from app.core.security import CurrentUserId, create_dev_access_token
from app.db.session import get_db_session
from app.modules.profiles.models import Account, Profile
from app.modules.profiles.schemas import DevLoginRequest, LoginResponse, ProfileResponse
from app.modules.profiles.service import UsernameUnavailableError, direct_login
from app.modules.progression.models import PlayerProgress
from app.modules.progression.schemas import ProgressResponse

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
    progress = await session.get(PlayerProgress, user_id)
    if progress is None:
        return ProgressResponse(
            fitness_xp=0,
            level=1,
            current_streak_days=0,
            longest_streak_days=0,
        )
    return ProgressResponse(
        fitness_xp=progress.fitness_xp,
        level=progress.level,
        current_streak_days=progress.current_streak_days,
        longest_streak_days=progress.longest_streak_days,
    )


def _profile_response(profile: Profile, email: str) -> ProfileResponse:
    return ProfileResponse(
        id=profile.id,
        email=email,
        username=profile.username,
        display_name=profile.display_name,
        country_code=profile.country_code,
        city=profile.city,
        profile_is_public=profile.profile_is_public,
    )
