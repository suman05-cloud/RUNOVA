import uuid

from pydantic import BaseModel


class TerritoryMapItem(BaseModel):
    cell_id: str
    owner_id: uuid.UUID | None
    owner_username: str | None
    is_current_user: bool
    power: float
    coordinates: list[list[float]]
