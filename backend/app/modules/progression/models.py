import uuid
from datetime import datetime

from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    ForeignKey,
    Integer,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class XpLedgerEntry(Base):
    __tablename__ = "xp_ledger"
    __table_args__ = (
        CheckConstraint("amount > 0", name="positive_amount"),
        UniqueConstraint("user_id", "source_type", "source_id", name="xp_source_once"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), index=True
    )
    amount: Mapped[int] = mapped_column(Integer)
    source_type: Mapped[str] = mapped_column(String(30))
    source_id: Mapped[str] = mapped_column(String(64))
    rules_version: Mapped[str] = mapped_column(String(30))
    created_at: Mapped[datetime] = mapped_column(server_default=func.now())


class PlayerProgress(Base):
    __tablename__ = "player_progress"

    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), primary_key=True
    )
    fitness_xp: Mapped[int] = mapped_column(BigInteger, default=0, server_default="0")
    level: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    current_streak_days: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    longest_streak_days: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    last_qualifying_run_at: Mapped[datetime | None] = mapped_column()
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), onupdate=func.now())
