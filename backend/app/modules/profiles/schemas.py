import uuid
from datetime import datetime

from pydantic import BaseModel, ConfigDict, EmailStr, Field


class DevLoginRequest(BaseModel):
    email: EmailStr
    username: str = Field(min_length=3, max_length=30, pattern=r"^[a-zA-Z0-9_]+$")
    display_name: str | None = Field(default=None, max_length=80)


class ProfileResponse(BaseModel):
    model_config = ConfigDict(from_attributes=True)

    id: uuid.UUID
    email: EmailStr
    username: str
    display_name: str | None
    country_code: str
    city: str | None
    profile_is_public: bool


class LoginResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"
    expires_at: datetime
    profile: ProfileResponse
