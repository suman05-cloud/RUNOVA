import json
from typing import Annotated

from fastapi import APIRouter, Depends, Query
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import CurrentUserId
from app.db.session import get_db_session
from app.modules.profiles.models import Profile
from app.modules.territories.game import expire_territories
from app.modules.territories.models import Territory
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
    if min_lat >= max_lat or min_lng >= max_lng:
        return []
    await expire_territories(session)
    bounds = func.ST_MakeEnvelope(min_lng, min_lat, max_lng, max_lat, 4326)
    rows = (
        await session.execute(
            select(Territory, Profile.username, func.ST_AsGeoJSON(Territory.geometry))
            .outerjoin(Profile, Profile.id == Territory.owner_id)
            .where(
                Territory.geometry.is_not(None),
                (Territory.owner_id.is_not(None)) | Territory.released_at.is_not(None),
                ~func.ST_IsEmpty(Territory.geometry),
                func.ST_Intersects(Territory.geometry, bounds),
            )
        )
    ).all()
    items = []
    for territory, username, geometry in rows:
        mine = territory.owner_id == user_id
        state = "MINE" if mine else "TAKEN" if territory.owner_id else "OPEN"
        items.append(
            TerritoryMapItem(
                cell_id=territory.cell_id,
                owner_id=territory.owner_id,
                owner_username=username,
                is_current_user=mine,
                power=100 if territory.owner_id else 0,
                geometry=json.loads(geometry),
                state=state,
                reward_points=float(territory.reward_points),
                can_capture=state == "OPEN",
            )
        )
    await session.commit()
    return items
