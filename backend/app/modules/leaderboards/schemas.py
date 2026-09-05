import uuid

from pydantic import BaseModel


class LeaderboardEntryResponse(BaseModel):
    rank: int
    user_id: uuid.UUID
    username: str
    display_name: str | None
    score: float
    is_current_user: bool


class LeaderboardResponse(BaseModel):
    scope: str
    scope_key: str
    category: str
    entries: list[LeaderboardEntryResponse]
