from dataclasses import dataclass
from datetime import datetime


@dataclass(frozen=True, slots=True)
class TerritoryRules:
    version: str = "mvp-v1"
    maximum_power: float = 100
    hourly_decay: float = 10 / 24
    h3_resolution: int = 10
    defense_power_per_visit: float = 10
    attack_power_per_visit: float = 20
    transfer_starting_power: float = 25


DEFAULT_TERRITORY_RULES = TerritoryRules()


def effective_power(
    base_power: float,
    power_updated_at: datetime,
    evaluated_at: datetime,
    rules: TerritoryRules = DEFAULT_TERRITORY_RULES,
) -> float:
    """Evaluate lazy linear decay without mutating the stored territory."""
    elapsed_seconds = max(0, (evaluated_at - power_updated_at).total_seconds())
    decayed = base_power - (elapsed_seconds / 3600 * rules.hourly_decay)
    return round(max(0, min(rules.maximum_power, decayed)), 2)

