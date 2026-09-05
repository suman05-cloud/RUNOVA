"""Single import point used by Alembic to discover every model."""

from app.modules.leaderboards.models import LeaderboardScore
from app.modules.profiles.models import Account, Device, Profile
from app.modules.progression.models import PlayerProgress, XpLedgerEntry
from app.modules.runs.models import (
    Run,
    RunEvent,
    RunGpsPoint,
    RunSensorSegment,
    RunUploadBatch,
    RunValidation,
)
from app.modules.territories.models import Territory, TerritoryEvent

__all__ = [
    "Account",
    "Device",
    "LeaderboardScore",
    "PlayerProgress",
    "Profile",
    "Run",
    "RunEvent",
    "RunGpsPoint",
    "RunSensorSegment",
    "RunUploadBatch",
    "RunValidation",
    "Territory",
    "TerritoryEvent",
    "XpLedgerEntry",
]
