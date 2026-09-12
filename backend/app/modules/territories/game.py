import uuid
from datetime import UTC, datetime, timedelta
from decimal import Decimal

from geoalchemy2 import Geography, Geometry
from sqlalchemy import cast, func, literal, select, text
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.progression.models import PlayerProgress
from app.modules.runs.route_math import RoutePoint
from app.modules.territories.loops import loop_wkt
from app.modules.territories.models import Territory, TerritoryEvent
from app.modules.territories.service import TerritoryChange

RULES_VERSION = "free-loop-v3"
INACTIVITY_HOURS = 48
MIN_AREA_M2 = 100
MAX_AREA_M2 = 25_000_000


async def game_lock(session: AsyncSession):
    # Capture clipping and inactivity release are atomic across competing players.
    await session.execute(text("SELECT pg_advisory_xact_lock(72700601)"))


async def expire_territories(session: AsyncSession, now: datetime | None = None):
    now = now or datetime.now(UTC)
    await game_lock(session)
    rows = (
        await session.execute(
            select(Territory, PlayerProgress.last_qualifying_run_at)
            .outerjoin(PlayerProgress, PlayerProgress.user_id == Territory.owner_id)
            .where(Territory.owner_id.is_not(None))
        )
    ).all()
    for territory, last_activity in rows:
        last = max(
            t
            for t in (last_activity, territory.captured_at, territory.power_updated_at)
            if t is not None
        )
        if now - last >= timedelta(hours=INACTIVITY_HOURS):
            territory.previous_owner_id = territory.owner_id
            territory.owner_id = None
            territory.released_at = last + timedelta(hours=INACTIVITY_HOURS)
            territory.base_power = 0
            territory.version += 1
    await session.flush()


async def polygon_part(session, expression):
    return await session.scalar(select(func.ST_Multi(func.ST_CollectionExtract(expression, 3))))


async def area_m2(session, geometry):
    value = literal(geometry, type_=Geometry(srid=4326))
    return float(await session.scalar(select(func.ST_Area(cast(value, Geography)))) or 0)


def points_for_area(area, multiplier=1):
    # Quantize once per shape; recaptures are 2x base, never 2x an earlier bonus.
    return (Decimal(str(area)) / 100 * multiplier).quantize(Decimal("0.01"))


async def capture_loops(
    session: AsyncSession,
    user_id: uuid.UUID,
    run_id: uuid.UUID,
    points: list[RoutePoint],
    started_at: datetime,
    finished_at: datetime,
) -> list[TerritoryChange]:
    now = datetime.now(UTC)
    await expire_territories(session, now)
    if now - finished_at >= timedelta(hours=INACTIVITY_HOURS):
        return []
    # Protect direct/replayed calls as well as the finish endpoint's run lock.
    if await session.scalar(
        select(TerritoryEvent.id).where(TerritoryEvent.run_id == run_id).limit(1)
    ):
        return []
    wkt = loop_wkt(points)
    if wkt is None:
        return []
    shape = func.ST_GeomFromText(wkt, 4326)
    if not await session.scalar(select(func.ST_IsValid(shape))):
        return []  # Reject crossing/bow-tie routes instead of inventing enclosed land.
    available = await polygon_part(session, shape)
    area = await area_m2(session, available)
    if not MIN_AREA_M2 <= area <= MAX_AREA_M2:
        return []

    rows = (
        await session.scalars(
            select(Territory)
            .where(
                Territory.geometry.is_not(None), func.ST_Intersects(Territory.geometry, available)
            )
            .order_by(Territory.cell_id)
        )
    ).all()
    # Taken land awards no additional territory points, even to its own owner.
    for territory in rows:
        if territory.owner_id is not None:
            available = await polygon_part(
                session, func.ST_Difference(available, territory.geometry)
            )
    changes = []

    async def claim(geometry, multiplier, previous_owner=None):
        amount = await area_m2(session, geometry)
        if amount < 1:
            return
        territory = Territory(
            cell_id=uuid.uuid4().hex[:16],
            h3_resolution=0,
            geometry=geometry,
            owner_id=user_id,
            previous_owner_id=previous_owner,
            captured_at=finished_at,
            power_updated_at=finished_at,
            base_power=100,
            capture_count=1,
            reward_points=points_for_area(amount, multiplier),
        )
        session.add(territory)
        await session.flush()
        action = "RECAPTURED" if multiplier == 2 else "CAPTURED"
        session.add(
            TerritoryEvent(
                cell_id=territory.cell_id,
                run_id=run_id,
                actor_user_id=user_id,
                previous_owner_id=previous_owner,
                new_owner_id=user_id,
                action_type=action,
                power_before=0,
                power_after=100,
                rules_version=RULES_VERSION,
            )
        )
        changes.append(TerritoryChange(territory.cell_id, action, 0, 100))

    for territory in rows:
        if territory.owner_id is not None or territory.released_at is None:
            continue
        portion = await polygon_part(session, func.ST_Intersection(available, territory.geometry))
        # Always exclude yellow from normal rewards, including stale offline runs.
        available = await polygon_part(session, func.ST_Difference(available, territory.geometry))
        if territory.released_at > started_at or await area_m2(session, portion) < 1:
            continue
        await claim(portion, 2, territory.previous_owner_id)
        remainder = await polygon_part(session, func.ST_Difference(territory.geometry, portion))
        territory.geometry = remainder
        territory.reward_points = points_for_area(await area_m2(session, remainder))
        territory.version += 1
        # Empty rows stay as historical references, but are never rendered.
    await claim(available, 1)
    await session.flush()
    return changes
