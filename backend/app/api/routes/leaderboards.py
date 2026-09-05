from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import CurrentUserId
from app.db.session import get_db_session
from app.modules.leaderboards.models import LeaderboardScore
from app.modules.leaderboards.schemas import LeaderboardEntryResponse, LeaderboardResponse
from app.modules.profiles.models import Profile

router = APIRouter(prefix="/leaderboards", tags=["leaderboards"])
SessionDependency = Annotated[AsyncSession, Depends(get_db_session)]


@router.get("", response_model=LeaderboardResponse)
async def get_leaderboard(
    user_id: CurrentUserId,
    session: SessionDependency,
    scope: Literal["GLOBAL", "CITY"] = "GLOBAL",
    scope_key: str = "global",
    category: Literal["FITNESS_XP", "COMPETITIVE_SCORE"] = "FITNESS_XP",
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> LeaderboardResponse:
    rows = (
        await session.execute(
            select(LeaderboardScore, Profile)
            .join(Profile, Profile.id == LeaderboardScore.user_id)
            .where(
                LeaderboardScore.scope == scope,
                LeaderboardScore.scope_key == scope_key,
                LeaderboardScore.category == category,
                LeaderboardScore.period_start == date(1970, 1, 1),
            )
            .order_by(LeaderboardScore.score.desc(), Profile.username)
            .limit(limit)
        )
    ).all()
    return LeaderboardResponse(
        scope=scope,
        scope_key=scope_key,
        category=category,
        entries=[
            LeaderboardEntryResponse(
                rank=index,
                user_id=score.user_id,
                username=profile.username,
                display_name=profile.display_name,
                score=float(score.score),
                is_current_user=score.user_id == user_id,
            )
            for index, (score, profile) in enumerate(rows, start=1)
        ],
    )
