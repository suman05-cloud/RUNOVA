import uuid
from datetime import date, datetime
from decimal import Decimal

from geoalchemy2 import Geometry
from sqlalchemy import (
    BigInteger,
    CheckConstraint,
    Float,
    ForeignKey,
    Index,
    Integer,
    Numeric,
    String,
    UniqueConstraint,
    func,
)
from sqlalchemy.dialects.postgresql import UUID
from sqlalchemy.orm import Mapped, mapped_column

from app.db.base import Base


class Territory(Base):
    __tablename__ = "territories"
    __table_args__ = (
        CheckConstraint("base_power >= 0 AND base_power <= 100", name="power_range"),
        Index("ix_territories_owner_power", "owner_id", "base_power"),
        Index("ix_territories_geometry_gist", "geometry", postgresql_using="gist"),
    )

    cell_id: Mapped[str] = mapped_column(String(16), primary_key=True)
    h3_resolution: Mapped[int] = mapped_column(Integer, index=True)
    owner_id: Mapped[uuid.UUID | None] = mapped_column(
        UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="SET NULL"), index=True
    )
    previous_owner_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    base_power: Mapped[Decimal] = mapped_column(Numeric(6, 2), default=100, server_default="100")
    power_updated_at: Mapped[datetime] = mapped_column(server_default=func.now())
    captured_at: Mapped[datetime | None] = mapped_column()
    last_defended_at: Mapped[datetime | None] = mapped_column()
    capture_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    unique_visitor_count: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    territory_level: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    version: Mapped[int] = mapped_column(Integer, default=1, server_default="1")
    reward_points: Mapped[Decimal] = mapped_column(
        Numeric(14, 2), default=100, server_default="100"
    )
    released_at: Mapped[datetime | None] = mapped_column()
    geometry: Mapped[object | None] = mapped_column(
        Geometry("MULTIPOLYGON", srid=4326, spatial_index=False)
    )


class DailyCaptureTask(Base):
    __tablename__ = "daily_capture_tasks"
    __table_args__ = (UniqueConstraint("user_id", "task_date", name="daily_task_user_date"),)

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(ForeignKey("profiles.id"), index=True)
    task_date: Mapped[date] = mapped_column()
    cell_id: Mapped[str] = mapped_column(ForeignKey("territories.cell_id"), index=True)
    origin_lat: Mapped[float] = mapped_column(Float)
    origin_lng: Mapped[float] = mapped_column(Float)
    distance_meters: Mapped[float] = mapped_column(Float)
    reward_points: Mapped[int] = mapped_column(Integer)
    assigned_at: Mapped[datetime] = mapped_column(server_default=func.now())
    expires_at: Mapped[datetime] = mapped_column()
    completed_at: Mapped[datetime | None] = mapped_column()
    run_id: Mapped[uuid.UUID | None] = mapped_column(ForeignKey("runs.id"))


class TerritoryEvent(Base):
    __tablename__ = "territory_events"
    __table_args__ = (Index("ix_territory_events_cell_time", "cell_id", "occurred_at"),)

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    cell_id: Mapped[str] = mapped_column(
        String(16), ForeignKey("territories.cell_id", ondelete="CASCADE"), index=True
    )
    run_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("runs.id", ondelete="RESTRICT"), index=True
    )
    actor_user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="RESTRICT"), index=True
    )
    previous_owner_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    new_owner_id: Mapped[uuid.UUID | None] = mapped_column(UUID(as_uuid=True))
    action_type: Mapped[str] = mapped_column(String(20), index=True)
    power_before: Mapped[Decimal] = mapped_column(Numeric(6, 2))
    power_after: Mapped[Decimal] = mapped_column(Numeric(6, 2))
    occurred_at: Mapped[datetime] = mapped_column(server_default=func.now())
    rules_version: Mapped[str] = mapped_column(String(30))
