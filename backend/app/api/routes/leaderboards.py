from datetime import date
from typing import Annotated, Literal

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import CurrentUserId
from app.db.session import get_db_session
from app.modules.leaderboards.models import LeaderboardScore
from app.modules.leaderboards.schemas import LeaderboardEntryResponse, LeaderboardResponse
from app.modules.profiles.models import Profile
from app.modules.territories.game import expire_territories
from app.modules.territories.models import Territory

router = APIRouter(prefix="/leaderboards", tags=["leaderboards"])
SessionDependency = Annotated[AsyncSession, Depends(get_db_session)]


@router.get("", response_model=LeaderboardResponse)
async def get_leaderboard(
    user_id: CurrentUserId,
    session: SessionDependency,
    scope: Literal["GLOBAL", "COUNTRY", "STATE", "CITY"] = "GLOBAL",
    scope_key: str = "global",
    category: Literal["FITNESS_XP", "COMPETITIVE_SCORE", "TERRITORY_POINTS"] = "FITNESS_XP",
    limit: Annotated[int, Query(ge=1, le=100)] = 50,
) -> LeaderboardResponse:
    if category == "TERRITORY_POINTS":
        await expire_territories(session)
        viewer = await session.get(Profile, user_id)
        score = func.sum(Territory.reward_points).label("score")
        query = select(Profile, score).join(Territory, Territory.owner_id == Profile.id)
        key = "global"
        if scope != "GLOBAL":
            query = query.where(Profile.country_code == viewer.country_code)
            key = viewer.country_code
        if scope in {"STATE", "CITY"}:
            if not viewer.state_region:
                await session.commit()
                return LeaderboardResponse(scope=scope, scope_key="", category=category, entries=[])
            query = query.where(
                func.lower(func.trim(Profile.state_region)) == viewer.state_region.strip().lower()
            )
            key += "/" + viewer.state_region.strip().lower()
        if scope == "CITY":
            if not viewer.city:
                await session.commit()
                return LeaderboardResponse(scope=scope, scope_key="", category=category, entries=[])
            query = query.where(func.lower(func.trim(Profile.city)) == viewer.city.strip().lower())
            key += "/" + viewer.city.strip().lower()
        rows = (
            await session.execute(
                query.group_by(Profile.id).order_by(score.desc(), Profile.username).limit(limit)
            )
        ).all()
        result = LeaderboardResponse(
            scope=scope,
            scope_key=key,
            category=category,
            entries=[
                LeaderboardEntryResponse(
                    rank=i,
                    user_id=p.id,
                    username=p.username,
                    display_name=p.display_name,
                    score=float(points),
                    is_current_user=p.id == user_id,
                )
                for i, (p, points) in enumerate(rows, 1)
            ],
        )
        await session.commit()
        return result
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
