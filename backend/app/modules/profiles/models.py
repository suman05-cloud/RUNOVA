import uuid
from datetime import datetime

from sqlalchemy import Boolean, ForeignKey, String, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base, TimestampMixin


class Account(TimestampMixin, Base):
    __tablename__ = "accounts"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    email: Mapped[str] = mapped_column(String(320), unique=True, index=True)
    auth_provider: Mapped[str] = mapped_column(
        String(30), default="DEV_DIRECT", server_default="DEV_DIRECT"
    )
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    last_login_at: Mapped[datetime] = mapped_column(server_default=func.now())


class Profile(TimestampMixin, Base):
    __tablename__ = "profiles"

    id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("accounts.id", ondelete="CASCADE"), primary_key=True
    )
    username: Mapped[str] = mapped_column(String(30), unique=True, index=True)
    display_name: Mapped[str | None] = mapped_column(String(80))
    avatar_url: Mapped[str | None] = mapped_column(String(500))
    country_code: Mapped[str] = mapped_column(String(2), default="IN", server_default="IN")
    city: Mapped[str | None] = mapped_column(String(100), index=True)
    account_status: Mapped[str] = mapped_column(
        String(20), default="ACTIVE", server_default="ACTIVE", index=True
    )
    profile_is_public: Mapped[bool] = mapped_column(Boolean, default=False, server_default="false")
    last_active_at: Mapped[datetime | None] = mapped_column()


class Device(TimestampMixin, Base):
    __tablename__ = "devices"

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), index=True
    )
    platform: Mapped[str] = mapped_column(String(20), default="ANDROID", server_default="ANDROID")
    app_version: Mapped[str | None] = mapped_column(String(40))
    os_version: Mapped[str | None] = mapped_column(String(40))
    model: Mapped[str | None] = mapped_column(String(100))
    fingerprint_hash: Mapped[str | None] = mapped_column(String(128), index=True)
    push_token: Mapped[str | None] = mapped_column(String(512))
    is_active: Mapped[bool] = mapped_column(Boolean, default=True, server_default="true")
    last_seen_at: Mapped[datetime] = mapped_column(server_default=func.now())
