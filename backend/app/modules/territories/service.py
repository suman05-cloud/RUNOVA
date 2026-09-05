import uuid
from dataclasses import dataclass
from datetime import UTC, datetime

from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.runs.route_math import RoutePoint
from app.modules.territories.h3_grid import cell_for_coordinate
from app.modules.territories.models import Territory, TerritoryEvent
from app.modules.territories.rules import (
    DEFAULT_TERRITORY_RULES,
    TerritoryRules,
    effective_power,
)


@dataclass(frozen=True, slots=True)
class TerritoryChange:
    cell_id: str
    action: str
    power_before: float
    power_after: float


async def apply_run_to_territories(
    session: AsyncSession,
    user_id: uuid.UUID,
    run_id: uuid.UUID,
    points: list[RoutePoint],
    rules: TerritoryRules = DEFAULT_TERRITORY_RULES,
) -> list[TerritoryChange]:
    evaluated_at = datetime.now(UTC)
    cell_ids = list(
        dict.fromkeys(
            cell_for_coordinate(point.latitude, point.longitude, rules.h3_resolution)
            for point in points
            if point.accuracy_meters <= 50
        )
    )
    changes: list[TerritoryChange] = []

    for cell_id in cell_ids:
        territory = await session.scalar(
            select(Territory).where(Territory.cell_id == cell_id).with_for_update()
        )
        if territory is None:
            territory = Territory(
                cell_id=cell_id,
                h3_resolution=rules.h3_resolution,
                owner_id=user_id,
                base_power=rules.maximum_power,
                power_updated_at=evaluated_at,
                captured_at=evaluated_at,
                capture_count=1,
            )
            session.add(territory)
            await session.flush()
            action = "CAPTURED"
            before = 0.0
            after = rules.maximum_power
            previous_owner = None
        else:
            before = effective_power(
                float(territory.base_power),
                territory.power_updated_at,
                evaluated_at,
                rules,
            )
            previous_owner = territory.owner_id
            if territory.owner_id == user_id:
                action = "DEFENDED"
                after = min(rules.maximum_power, before + rules.defense_power_per_visit)
                territory.last_defended_at = evaluated_at
            else:
                attacked_power = before - rules.attack_power_per_visit
                if attacked_power <= 0:
                    action = "CAPTURED"
                    territory.previous_owner_id = territory.owner_id
                    territory.owner_id = user_id
                    territory.captured_at = evaluated_at
                    territory.capture_count += 1
                    after = rules.transfer_starting_power
                else:
                    action = "ATTACKED"
                    after = attacked_power
            territory.base_power = after
            territory.power_updated_at = evaluated_at
            territory.version += 1

        session.add(
            TerritoryEvent(
                cell_id=cell_id,
                run_id=run_id,
                actor_user_id=user_id,
                previous_owner_id=previous_owner,
                new_owner_id=territory.owner_id,
                action_type=action,
                power_before=before,
                power_after=after,
                rules_version=rules.version,
            )
        )
        changes.append(TerritoryChange(cell_id, action, before, after))

    return changes

