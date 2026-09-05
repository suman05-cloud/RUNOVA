import uuid
from datetime import datetime
from decimal import Decimal

from geoalchemy2 import Geometry
from sqlalchemy import (
    JSON,
    BigInteger,
    Boolean,
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

from app.db.base import Base, TimestampMixin


class Run(TimestampMixin, Base):
    __tablename__ = "runs"
    __table_args__ = (
        CheckConstraint("distance_meters >= 0", name="distance_non_negative"),
        CheckConstraint("moving_seconds >= 0", name="moving_time_non_negative"),
        Index("ix_runs_route_gist", "route", postgresql_using="gist"),
    )

    id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True), primary_key=True, default=uuid.uuid4)
    user_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("profiles.id", ondelete="CASCADE"), index=True
    )
    device_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("devices.id", ondelete="RESTRICT"), index=True
    )
    state: Mapped[str] = mapped_column(String(20), default="STARTED", server_default="STARTED")
    server_started_at: Mapped[datetime] = mapped_column(server_default=func.now(), index=True)
    client_started_at: Mapped[datetime | None] = mapped_column()
    finished_at: Mapped[datetime | None] = mapped_column(index=True)
    distance_meters: Mapped[Decimal] = mapped_column(
        Numeric(12, 2), default=0, server_default="0"
    )
    moving_seconds: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    elapsed_seconds: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    average_speed_mps: Mapped[Decimal | None] = mapped_column(Numeric(8, 3))
    calories_kcal: Mapped[Decimal | None] = mapped_column(Numeric(10, 2))
    route: Mapped[object | None] = mapped_column(
        Geometry("LINESTRING", srid=4326, spatial_index=False)
    )
    trust_score: Mapped[int | None] = mapped_column(Integer)
    validation_status: Mapped[str] = mapped_column(
        String(20), default="PENDING", server_default="PENDING", index=True
    )
    competitive_eligible: Mapped[bool] = mapped_column(
        Boolean, default=False, server_default="false"
    )
    activity_type: Mapped[str | None] = mapped_column(String(20))
    activity_confidence: Mapped[int | None] = mapped_column(Integer)
    road_match_status: Mapped[str] = mapped_column(
        String(20), default="NOT_CHECKED", server_default="NOT_CHECKED"
    )
    road_match_confidence: Mapped[Decimal | None] = mapped_column(Numeric(5, 2))
    territories_changed: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    xp_earned: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    competitive_score: Mapped[int] = mapped_column(Integer, default=0, server_default="0")
    rules_version: Mapped[str] = mapped_column(
        String(30), default="mvp-v1", server_default="mvp-v1"
    )
    session_nonce_hash: Mapped[str] = mapped_column(String(128), unique=True)


class RunEvent(Base):
    __tablename__ = "run_events"
    __table_args__ = (
        UniqueConstraint("run_id", "sequence", name="run_event_sequence"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    run_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("runs.id", ondelete="CASCADE"), index=True
    )
    sequence: Mapped[int] = mapped_column(Integer)
    event_type: Mapped[str] = mapped_column(String(20))
    monotonic_ms: Mapped[int] = mapped_column(BigInteger)
    client_recorded_at: Mapped[datetime | None] = mapped_column()
    received_at: Mapped[datetime] = mapped_column(server_default=func.now())


class RunGpsPoint(Base):
    __tablename__ = "run_gps_points"
    __table_args__ = (
        UniqueConstraint("run_id", "sequence", name="run_gps_point_sequence"),
        Index("ix_run_gps_points_run_recorded", "run_id", "client_recorded_at"),
        Index("ix_run_gps_points_position_gist", "position", postgresql_using="gist"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    run_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("runs.id", ondelete="CASCADE"), index=True
    )
    sequence: Mapped[int] = mapped_column(Integer)
    position: Mapped[object] = mapped_column(Geometry("POINT", srid=4326, spatial_index=False))
    latitude: Mapped[float] = mapped_column(Float)
    longitude: Mapped[float] = mapped_column(Float)
    client_recorded_at: Mapped[datetime] = mapped_column()
    monotonic_ms: Mapped[int] = mapped_column(BigInteger)
    accuracy_meters: Mapped[float] = mapped_column(Float)
    altitude_meters: Mapped[float | None] = mapped_column(Float)
    speed_mps: Mapped[float | None] = mapped_column(Float)
    heading_degrees: Mapped[float | None] = mapped_column(Float)
    h3_cell_id: Mapped[str | None] = mapped_column(String(16), index=True)


class RunSensorSegment(Base):
    __tablename__ = "run_sensor_segments"
    __table_args__ = (
        UniqueConstraint("run_id", "sequence", name="run_sensor_segment_sequence"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    run_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("runs.id", ondelete="CASCADE"), index=True
    )
    sequence: Mapped[int] = mapped_column(Integer)
    start_monotonic_ms: Mapped[int] = mapped_column(BigInteger)
    end_monotonic_ms: Mapped[int] = mapped_column(BigInteger)
    activity_type: Mapped[str | None] = mapped_column(String(30))
    activity_confidence: Mapped[int | None] = mapped_column(Integer)
    features: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)


class RunUploadBatch(Base):
    __tablename__ = "run_upload_batches"
    __table_args__ = (
        UniqueConstraint("run_id", "batch_id", name="run_upload_batch_id"),
    )

    id: Mapped[int] = mapped_column(BigInteger, primary_key=True, autoincrement=True)
    run_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("runs.id", ondelete="CASCADE"), index=True
    )
    batch_id: Mapped[uuid.UUID] = mapped_column(UUID(as_uuid=True))
    first_sequence: Mapped[int] = mapped_column(Integer)
    last_sequence: Mapped[int] = mapped_column(Integer)
    checksum_sha256: Mapped[str] = mapped_column(String(64))
    received_at: Mapped[datetime] = mapped_column(server_default=func.now())


class RunValidation(Base):
    __tablename__ = "run_validations"

    run_id: Mapped[uuid.UUID] = mapped_column(
        UUID(as_uuid=True), ForeignKey("runs.id", ondelete="CASCADE"), primary_key=True
    )
    gps_score: Mapped[int] = mapped_column(Integer)
    motion_score: Mapped[int] = mapped_column(Integer)
    activity_score: Mapped[int] = mapped_column(Integer)
    route_score: Mapped[int] = mapped_column(Integer)
    device_score: Mapped[int] = mapped_column(Integer)
    final_trust_score: Mapped[int] = mapped_column(Integer, index=True)
    status: Mapped[str] = mapped_column(String(20), index=True)
    reason_codes: Mapped[list[str]] = mapped_column(JSON, default=list)
    metrics: Mapped[dict[str, object]] = mapped_column(JSON, default=dict)
    validated_at: Mapped[datetime] = mapped_column(server_default=func.now())
