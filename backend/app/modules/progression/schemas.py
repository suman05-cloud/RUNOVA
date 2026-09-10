from pydantic import BaseModel


class ProgressResponse(BaseModel):
    fitness_xp: int
    level: int
    current_streak_days: int
    longest_streak_days: int
    territories_owned: int = 0
