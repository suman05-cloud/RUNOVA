import uuid
from datetime import datetime

from pydantic import BaseModel, Field, model_validator


class DeviceInput(BaseModel):
    id: uuid.UUID
    app_version: str | None = Field(default=None, max_length=40)
    os_version: str | None = Field(default=None, max_length=40)
    model: str | None = Field(default=None, max_length=100)


class CreateRunRequest(BaseModel):
    device: DeviceInput
    client_started_at: datetime


class CreateRunResponse(BaseModel):
    run_id: uuid.UUID
    session_nonce: str
    server_started_at: datetime
    rules_version: str


class GpsPointInput(BaseModel):
    sequence: int = Field(ge=0)
    latitude: float = Field(ge=-90, le=90)
    longitude: float = Field(ge=-180, le=180)
    client_recorded_at: datetime
    monotonic_ms: int = Field(ge=0)
    accuracy_meters: float = Field(ge=0, le=10_000)
    altitude_meters: float | None = None
    speed_mps: float | None = Field(default=None, ge=0, le=500)
    heading_degrees: float | None = Field(default=None, ge=0, le=360)


class SensorSegmentInput(BaseModel):
    sequence: int = Field(ge=0)
    start_monotonic_ms: int = Field(ge=0)
    end_monotonic_ms: int = Field(ge=0)
    activity_type: str | None = Field(default=None, max_length=30)
    activity_confidence: int | None = Field(default=None, ge=0, le=100)
    features: dict[str, float | int | str | bool] = Field(default_factory=dict)


class RunBatchRequest(BaseModel):
    batch_id: uuid.UUID
    session_nonce: str = Field(min_length=32, max_length=128)
    first_sequence: int = Field(ge=0)
    last_sequence: int = Field(ge=0)
    points: list[GpsPointInput] = Field(default_factory=list, max_length=500)
    sensor_segments: list[SensorSegmentInput] = Field(default_factory=list, max_length=100)

    @model_validator(mode="after")
    def sequences_match_envelope(self) -> "RunBatchRequest":
        if self.last_sequence < self.first_sequence:
            raise ValueError("last_sequence must not be before first_sequence")
        sensor_sequences = [segment.sequence for segment in self.sensor_segments]
        if len(sensor_sequences) != len(set(sensor_sequences)):
            raise ValueError("sensor sequences must be unique")
        if any(s.end_monotonic_ms < s.start_monotonic_ms for s in self.sensor_segments):
            raise ValueError("sensor segment ends before its start")
        if self.points:
            sequences = [point.sequence for point in self.points]
            if min(sequences) < self.first_sequence or max(sequences) > self.last_sequence:
                raise ValueError("point sequence is outside the batch envelope")
            if len(sequences) != len(set(sequences)):
                raise ValueError("point sequences must be unique inside a batch")
        return self


class BatchAcceptedResponse(BaseModel):
    batch_id: uuid.UUID
    point_count: int
    sensor_segment_count: int
    duplicate: bool = False


class FinishRunRequest(BaseModel):
    session_nonce: str = Field(min_length=32, max_length=128)
    client_finished_at: datetime
    elapsed_seconds: int = Field(ge=0, le=604_800)
    moving_seconds: int = Field(ge=0, le=604_800)

    @model_validator(mode="after")
    def valid_duration(self) -> "FinishRunRequest":
        if self.moving_seconds > self.elapsed_seconds:
            raise ValueError("moving_seconds exceeds elapsed_seconds")
        return self


class TerritoryChangeResponse(BaseModel):
    cell_id: str
    action: str
    power_before: float
    power_after: float


class FinishRunResponse(BaseModel):
    run_id: uuid.UUID
    distance_meters: float
    trust_score: int
    validation_status: str
    competitive_eligible: bool
    activity_type: str
    activity_confidence: int
    road_match_status: str
    road_match_confidence: float | None
    xp_earned: int
    level: int
    competitive_score: int
    territory_changes: list[TerritoryChangeResponse]


class RunSummaryResponse(BaseModel):
    id: uuid.UUID
    started_at: datetime
    finished_at: datetime | None
    distance_meters: float
    elapsed_seconds: int
    validation_status: str
    activity_type: str | None
    xp_earned: int
    territories_changed: int


class RoutePointResponse(BaseModel):
    sequence: int
    latitude: float
    longitude: float
    recorded_at: datetime
    accuracy_meters: float


class RunDetailResponse(BaseModel):
    id: uuid.UUID
    started_at: datetime
    finished_at: datetime | None
    distance_meters: float
    elapsed_seconds: int
    moving_seconds: int
    validation_status: str
    activity_type: str | None
    trust_score: int | None
    competitive_eligible: bool
    xp_earned: int
    territories_changed: int
    level: int = 1
    route_points: list[RoutePointResponse] = Field(default_factory=list)
    territory_changes: list[TerritoryChangeResponse] = Field(default_factory=list)
    route_truncated: bool = False
