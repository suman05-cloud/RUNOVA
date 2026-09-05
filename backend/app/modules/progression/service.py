import uuid
from datetime import date
from decimal import Decimal
from math import floor, sqrt

from sqlalchemy import select
from sqlalchemy.dialects.postgresql import insert
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.leaderboards.models import LeaderboardScore
from app.modules.profiles.models import Profile
from app.modules.progression.models import PlayerProgress, XpLedgerEntry


def level_for_xp(total_xp: int) -> int:
    return 1 + floor(sqrt(max(0, total_xp) / 500))


def calculate_run_xp(distance_meters: float, territory_count: int, multiplier: float = 1) -> int:
    base = floor(distance_meters / 100) + territory_count * 5
    return max(0, floor(base * multiplier))


async def award_run_progress(
    session: AsyncSession,
    user_id: uuid.UUID,
    run_id: uuid.UUID,
    xp: int,
    competitive_score: int,
    rules_version: str,
) -> tuple[int, int]:
    progress = await session.scalar(
        select(PlayerProgress).where(PlayerProgress.user_id == user_id).with_for_update()
    )
    if progress is None:
        progress = PlayerProgress(user_id=user_id)
        session.add(progress)
        await session.flush()

    if xp > 0:
        session.add(
            XpLedgerEntry(
                user_id=user_id,
                amount=xp,
                source_type="RUN",
                source_id=str(run_id),
                rules_version=rules_version,
            )
        )
        progress.fitness_xp += xp
        progress.level = level_for_xp(progress.fitness_xp)

    await _upsert_leaderboard(
        session,
        user_id=user_id,
        category="FITNESS_XP",
        score=Decimal(progress.fitness_xp),
    )
    if competitive_score > 0:
        await _increment_leaderboard(
            session,
            user_id=user_id,
            category="COMPETITIVE_SCORE",
            amount=Decimal(competitive_score),
        )
    return progress.fitness_xp, progress.level


async def _upsert_leaderboard(
    session: AsyncSession, user_id: uuid.UUID, category: str, score: Decimal
) -> None:
    profile = await session.get(Profile, user_id)
    values = _leaderboard_values(user_id, category, score)
    statement = insert(LeaderboardScore).values(**values)
    statement = statement.on_conflict_do_update(
        constraint="leaderboard_entry",
        set_={"score": score},
    )
    await session.execute(statement)
    if profile and profile.city:
        local_values = _leaderboard_values(user_id, category, score, "CITY", profile.city)
        local_statement = insert(LeaderboardScore).values(**local_values)
        await session.execute(
            local_statement.on_conflict_do_update(
                constraint="leaderboard_entry",
                set_={"score": score},
            )
        )


async def _increment_leaderboard(
    session: AsyncSession, user_id: uuid.UUID, category: str, amount: Decimal
) -> None:
    values = _leaderboard_values(user_id, category, amount)
    statement = insert(LeaderboardScore).values(**values)
    await session.execute(
        statement.on_conflict_do_update(
            constraint="leaderboard_entry",
            set_={"score": LeaderboardScore.score + amount},
        )
    )


def _leaderboard_values(
    user_id: uuid.UUID,
    category: str,
    score: Decimal,
    scope: str = "GLOBAL",
    scope_key: str = "global",
) -> dict[str, object]:
    return {
        "user_id": user_id,
        "scope": scope,
        "scope_key": scope_key,
        "category": category,
        "period_start": date(1970, 1, 1),
        "score": score,
    }

