from datetime import UTC, datetime
from typing import Annotated

import h3
from fastapi import APIRouter, Depends, Query
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import CurrentUserId
from app.db.session import get_db_session
from app.modules.profiles.models import Profile
from app.modules.territories.h3_grid import cell_boundary
from app.modules.territories.models import Territory
from app.modules.territories.rules import DEFAULT_TERRITORY_RULES, effective_power
from app.modules.territories.schemas import TerritoryMapItem

router = APIRouter(prefix="/territories", tags=["territories"])
SessionDependency = Annotated[AsyncSession, Depends(get_db_session)]


@router.get("", response_model=list[TerritoryMapItem])
async def territory_map(
    user_id: CurrentUserId,
    session: SessionDependency,
    min_lat: Annotated[float, Query(ge=-90, le=90)],
    max_lat: Annotated[float, Query(ge=-90, le=90)],
    min_lng: Annotated[float, Query(ge=-180, le=180)],
    max_lng: Annotated[float, Query(ge=-180, le=180)],
) -> list[TerritoryMapItem]:
    if min_lat > max_lat or min_lng > max_lng:
        return []
    rows = (
        await session.execute(
            select(Territory, Profile.username)
            .outerjoin(Profile, Profile.id == Territory.owner_id)
            .limit(5000)
        )
    ).all()
    now = datetime.now(UTC)
    items: list[TerritoryMapItem] = []
    for territory, username in rows:
        latitude, longitude = h3.cell_to_latlng(territory.cell_id)
        if not (min_lat <= latitude <= max_lat and min_lng <= longitude <= max_lng):
            continue
        boundary = cell_boundary(territory.cell_id)
        coordinates = [[longitude, latitude] for longitude, latitude in boundary]
        coordinates.append(coordinates[0])
        items.append(
            TerritoryMapItem(
                cell_id=territory.cell_id,
                owner_id=territory.owner_id,
                owner_username=username,
                is_current_user=territory.owner_id == user_id,
                power=effective_power(
                    float(territory.base_power),
                    territory.power_updated_at,
                    now,
                    DEFAULT_TERRITORY_RULES,
                ),
                coordinates=coordinates,
            )
        )
        if len(items) >= 1000:
            break
    return items
