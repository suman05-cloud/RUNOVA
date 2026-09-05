from functools import lru_cache

from pydantic import Field
from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    model_config = SettingsConfigDict(
        env_file=(".env", "../.env"),
        env_prefix="RUNOVA_",
        case_sensitive=False,
        extra="ignore",
    )

    app_name: str = "Runova API"
    version: str = "0.1.0"
    environment: str = "development"
    debug: bool = False
    api_prefix: str = "/v1"

    database_url: str = "postgresql+asyncpg://runova:runova@localhost:5432/runova"
    redis_url: str = "redis://localhost:6379/0"
    cors_origins: list[str] = Field(default_factory=list)

    dev_login_enabled: bool = True
    dev_jwt_secret: str = "runova-local-development-secret-change-before-sharing"
    dev_token_minutes: int = 10_080

    road_match_base_url: str = ""
    road_match_profile: str = "foot"

    supabase_url: str = ""
    supabase_jwt_issuer: str = ""
    supabase_jwt_audience: str = "authenticated"


@lru_cache
def get_settings() -> Settings:
    return Settings()
