import uuid

from pydantic import BaseModel


class TerritoryMapItem(BaseModel):
    cell_id: str  # Opaque compatibility identifier, not an H3 grid for new captures.
    owner_id: uuid.UUID | None
    owner_username: str | None
    is_current_user: bool
    power: float
    geometry: dict
    state: str  # MINE, TAKEN (another player), OPEN
    reward_points: float
    can_capture: bool
