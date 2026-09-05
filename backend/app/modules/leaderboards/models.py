import uuid
from datetime import date, datetime
from decimal import Decimal

from sqlalchemy import BigInteger, Date, ForeignKey, Index, Numeric, String, UniqueConstraint, func
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class LeaderboardScore(Base):
    __tablename__ = "leaderboard_scores"
    __table_args__ = (
        UniqueConstraint(
            "user_id", "scope", "scope_key", "category", "period_start", name="leaderboard_entry"
        ),
        Index(
            "ix_leaderboard_rank_lookup",
            "scope",
            "scope_key",
            "category",
            "period_start",
            "score",
        ),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), index=True
    )
    scope: Mapped[str] = mapped_column(String(20))
    scope_key: Mapped[str] = mapped_column(String(100), default="global", server_default="global")
    category: Mapped[str] = mapped_column(String(30))
    period_start: Mapped[date] = mapped_column(Date)
    score: Mapped[Decimal] = mapped_column(Numeric(16, 2), default=0, server_default="0")
    updated_at: Mapped[datetime] = mapped_column(server_default=func.now(), onupdate=func.now())

