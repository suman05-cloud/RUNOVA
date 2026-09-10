import hashlib
import json
import secrets
import uuid
from datetime import UTC, datetime
from decimal import Decimal

from geoalchemy2.elements import WKTElement
from sqlalchemy import func, select
from sqlalchemy.ext.asyncio import AsyncSession

from app.modules.profiles.models import Device
from app.modules.progression.models import PlayerProgress
from app.modules.progression.service import award_run_progress, calculate_run_xp
from app.modules.runs.activity import ActivityResult, classify_activity
from app.modules.runs.models import (
    Run,
    RunGpsPoint,
    RunSensorSegment,
    RunUploadBatch,
    RunValidation,
)
from app.modules.runs.road_match import match_route_to_roads
from app.modules.runs.route_math import RoutePoint, route_distance_meters, segment_speed_mps
from app.modules.runs.schemas import (
    BatchAcceptedResponse,
    CreateRunRequest,
    CreateRunResponse,
    FinishRunRequest,
    FinishRunResponse,
    RoutePointResponse,
    RunBatchRequest,
    RunDetailResponse,
    TerritoryChangeResponse,
)
from app.modules.runs.trust import evaluate_gps_trust
from app.modules.territories.h3_grid import cell_for_coordinate
from app.modules.territories.models import TerritoryEvent
from app.modules.territories.service import apply_run_to_territories


class RunNotFoundError(Exception):
    pass


class InvalidRunSessionError(Exception):
    pass


class RunStateError(Exception):
    pass


class BatchConflictError(Exception):
    pass


_MAX_ROUTE_POINTS = 5000


async def create_run(
    session: AsyncSession, user_id: uuid.UUID, request: CreateRunRequest
) -> CreateRunResponse:
    device = await session.get(Device, request.device.id)
    if device is not None and device.user_id != user_id:
        raise InvalidRunSessionError
    if device is None:
        device = Device(
            id=request.device.id,
            user_id=user_id,
            app_version=request.device.app_version,
            os_version=request.device.os_version,
            model=request.device.model,
        )
        session.add(device)
    else:
        device.app_version = request.device.app_version
        device.os_version = request.device.os_version
        device.model = request.device.model
        device.last_seen_at = datetime.now(UTC)

    nonce = secrets.token_urlsafe(32)
    run = Run(
        user_id=user_id,
        device_id=device.id,
        client_started_at=request.client_started_at,
        session_nonce_hash=_hash_nonce(nonce),
    )
    session.add(run)
    await session.commit()
    await session.refresh(run)
    return CreateRunResponse(
        run_id=run.id,
        session_nonce=nonce,
        server_started_at=run.server_started_at,
        rules_version=run.rules_version,
    )


async def upload_run_batch(
    session: AsyncSession,
    user_id: uuid.UUID,
    run_id: uuid.UUID,
    request: RunBatchRequest,
) -> BatchAcceptedResponse:
    run = await _get_authorized_run(session, user_id, run_id, request.session_nonce, lock=True)

    checksum = _batch_checksum(request)
    existing = await session.scalar(
        select(RunUploadBatch).where(
            RunUploadBatch.run_id == run_id,
            RunUploadBatch.batch_id == request.batch_id,
        )
    )
    if existing is not None:
        if existing.checksum_sha256 != checksum:
            raise BatchConflictError
        return BatchAcceptedResponse(
            batch_id=request.batch_id,
            point_count=len(request.points),
            sensor_segment_count=len(request.sensor_segments),
            duplicate=True,
        )

    if run.state != "STARTED":
        raise RunStateError
    # Reject overlaps explicitly rather than leaking a database constraint error.
    for model, sequences in (
        (RunGpsPoint, [point.sequence for point in request.points]),
        (RunSensorSegment, [segment.sequence for segment in request.sensor_segments]),
    ):
        if sequences and await session.scalar(
            select(model.id).where(model.run_id == run_id, model.sequence.in_(sequences)).limit(1)
        ):
            raise BatchConflictError

    for point in request.points:
        session.add(
            RunGpsPoint(
                run_id=run_id,
                sequence=point.sequence,
                position=WKTElement(f"POINT({point.longitude} {point.latitude})", srid=4326),
                latitude=point.latitude,
                longitude=point.longitude,
                client_recorded_at=point.client_recorded_at,
                monotonic_ms=point.monotonic_ms,
                accuracy_meters=point.accuracy_meters,
                altitude_meters=point.altitude_meters,
                speed_mps=point.speed_mps,
                heading_degrees=point.heading_degrees,
                h3_cell_id=cell_for_coordinate(point.latitude, point.longitude),
            )
        )
    for segment in request.sensor_segments:
        session.add(
            RunSensorSegment(
                run_id=run_id,
                sequence=segment.sequence,
                start_monotonic_ms=segment.start_monotonic_ms,
                end_monotonic_ms=segment.end_monotonic_ms,
                activity_type=segment.activity_type,
                activity_confidence=segment.activity_confidence,
                features=segment.features,
            )
        )
    session.add(
        RunUploadBatch(
            run_id=run_id,
            batch_id=request.batch_id,
            first_sequence=request.first_sequence,
            last_sequence=request.last_sequence,
            checksum_sha256=checksum,
        )
    )
    await session.commit()
    return BatchAcceptedResponse(
        batch_id=request.batch_id,
        point_count=len(request.points),
        sensor_segment_count=len(request.sensor_segments),
    )


async def finish_run(
    session: AsyncSession,
    user_id: uuid.UUID,
    run_id: uuid.UUID,
    request: FinishRunRequest,
) -> FinishRunResponse:
    run = await _get_authorized_run(session, user_id, run_id, request.session_nonce, lock=True)
    if run.state == "FINISHED":
        return await _finished_response(session, run)
    if run.state != "STARTED":
        raise RunStateError

    gps_rows = list(
        (
            await session.scalars(
                select(RunGpsPoint)
                .where(RunGpsPoint.run_id == run_id)
                .order_by(RunGpsPoint.sequence)
            )
        ).all()
    )
    sensor_rows = list(
        (
            await session.scalars(
                select(RunSensorSegment)
                .where(RunSensorSegment.run_id == run_id)
                .order_by(RunSensorSegment.sequence)
            )
        ).all()
    )
    route_points = [
        RoutePoint(row.latitude, row.longitude, row.monotonic_ms, row.accuracy_meters)
        for row in gps_rows
    ]
    distance = route_distance_meters(route_points)
    speeds = [
        speed
        for previous, current in zip(route_points, route_points[1:], strict=False)
        if (speed := segment_speed_mps(previous, current)) is not None
    ]
    activity = classify_activity(speeds, [row.features for row in sensor_rows])
    gps_trust = evaluate_gps_trust(route_points)
    road_match = await match_route_to_roads(route_points)
    trust_score, status, competitive = _run_verdict(gps_trust.score, activity)

    territory_changes = []
    if competitive:
        territory_changes = await apply_run_to_territories(session, user_id, run_id, route_points)

    multiplier = 1.0 if competitive else 0.5 if status == "CASUAL_VALID" else 0.0
    xp = calculate_run_xp(distance, len(territory_changes), multiplier)
    competitive_score = round(distance / 1000 * 100) if competitive else 0
    _, level = await award_run_progress(
        session, user_id, run_id, xp, competitive_score, run.rules_version, qualifying=competitive
    )

    run.state = "FINISHED"
    run.finished_at = request.client_finished_at
    run.distance_meters = Decimal(str(round(distance, 2)))
    run.elapsed_seconds = request.elapsed_seconds
    run.moving_seconds = request.moving_seconds
    run.average_speed_mps = (
        Decimal(str(round(distance / request.moving_seconds, 3)))
        if request.moving_seconds
        else None
    )
    run.route = _route_geometry(route_points)
    run.trust_score = trust_score
    run.validation_status = status
    run.competitive_eligible = competitive
    run.activity_type = activity.activity_type
    run.activity_confidence = activity.confidence
    run.road_match_status = road_match.status
    run.road_match_confidence = (
        Decimal(str(road_match.confidence)) if road_match.confidence is not None else None
    )
    run.territories_changed = len(territory_changes)
    run.xp_earned = xp
    run.competitive_score = competitive_score
    device_count = (
        await session.scalar(
            select(func.count()).select_from(Device).where(Device.user_id == user_id)
        )
        or 0
    )
    device_score = max(30, 80 - max(0, device_count - 3) * 10)
    session.add(
        RunValidation(
            run_id=run.id,
            gps_score=gps_trust.score,
            motion_score=activity.confidence,
            activity_score=activity.confidence,
            route_score=round(road_match.confidence or 50),
            device_score=device_score,
            final_trust_score=trust_score,
            status=status,
            reason_codes=list(gps_trust.reason_codes) + _activity_reasons(activity),
            metrics={
                **gps_trust.metrics,
                **activity.signals,
                "account_device_count": device_count,
                "device_signal": "registration_count_only_not_attestation",
            },
        )
    )
    await session.commit()
    return FinishRunResponse(
        run_id=run.id,
        distance_meters=float(run.distance_meters),
        trust_score=trust_score,
        validation_status=status,
        competitive_eligible=competitive,
        activity_type=activity.activity_type,
        activity_confidence=activity.confidence,
        road_match_status=road_match.status,
        road_match_confidence=road_match.confidence,
        xp_earned=xp,
        level=level,
        competitive_score=competitive_score,
        territory_changes=[
            TerritoryChangeResponse(
                cell_id=change.cell_id,
                action=change.action,
                power_before=change.power_before,
                power_after=change.power_after,
            )
            for change in territory_changes
        ],
    )


async def get_run_detail(
    session: AsyncSession,
    user_id: uuid.UUID,
    run_id: uuid.UUID,
    *,
    include_route: bool = False,
) -> RunDetailResponse:
    # Owner-only lookup: another user's run is indistinguishable from a missing one.
    run = await session.scalar(select(Run).where(Run.id == run_id, Run.user_id == user_id))
    if run is None:
        raise RunNotFoundError

    route_points: list[RoutePointResponse] = []
    route_truncated = False
    if include_route:
        rows = list(
            (
                await session.scalars(
                    select(RunGpsPoint)
                    .where(RunGpsPoint.run_id == run_id)
                    .order_by(RunGpsPoint.sequence)
                    .limit(_MAX_ROUTE_POINTS + 1)
                )
            ).all()
        )
        route_truncated = len(rows) > _MAX_ROUTE_POINTS
        route_points = [
            RoutePointResponse(
                sequence=row.sequence,
                latitude=row.latitude,
                longitude=row.longitude,
                recorded_at=row.client_recorded_at,
                accuracy_meters=row.accuracy_meters,
            )
            for row in rows[:_MAX_ROUTE_POINTS]
        ]
    events = (
        await session.scalars(
            select(TerritoryEvent)
            .where(TerritoryEvent.run_id == run_id)
            .order_by(TerritoryEvent.id)
        )
    ).all()
    progress = await session.get(PlayerProgress, user_id)
    return RunDetailResponse(
        id=run.id,
        started_at=run.server_started_at,
        finished_at=run.finished_at,
        distance_meters=float(run.distance_meters),
        elapsed_seconds=run.elapsed_seconds,
        moving_seconds=run.moving_seconds,
        validation_status=run.validation_status,
        activity_type=run.activity_type,
        trust_score=run.trust_score,
        competitive_eligible=run.competitive_eligible,
        xp_earned=run.xp_earned,
        territories_changed=run.territories_changed,
        route_points=route_points,
        route_truncated=route_truncated,
        level=progress.level if progress else 1,
        territory_changes=[
            TerritoryChangeResponse(
                cell_id=event.cell_id,
                action=event.action_type,
                power_before=float(event.power_before),
                power_after=float(event.power_after),
            )
            for event in events
        ],
    )


async def _get_authorized_run(
    session: AsyncSession,
    user_id: uuid.UUID,
    run_id: uuid.UUID,
    nonce: str,
    *,
    lock: bool = False,
) -> Run:
    statement = select(Run).where(Run.id == run_id, Run.user_id == user_id)
    if lock:
        statement = statement.with_for_update()
    run = await session.scalar(statement)
    if run is None:
        raise RunNotFoundError
    if not secrets.compare_digest(run.session_nonce_hash, _hash_nonce(nonce)):
        raise InvalidRunSessionError
    return run


async def _finished_response(session: AsyncSession, run: Run) -> FinishRunResponse:
    from app.modules.progression.models import PlayerProgress
    from app.modules.territories.models import TerritoryEvent

    progress = await session.get(PlayerProgress, run.user_id)
    events = list(
        (
            await session.scalars(
                select(TerritoryEvent)
                .where(TerritoryEvent.run_id == run.id)
                .order_by(TerritoryEvent.id)
            )
        ).all()
    )
    return FinishRunResponse(
        run_id=run.id,
        distance_meters=float(run.distance_meters),
        trust_score=run.trust_score or 0,
        validation_status=run.validation_status,
        competitive_eligible=run.competitive_eligible,
        activity_type=run.activity_type or "UNKNOWN",
        activity_confidence=run.activity_confidence or 0,
        road_match_status=run.road_match_status,
        road_match_confidence=(
            float(run.road_match_confidence) if run.road_match_confidence is not None else None
        ),
        xp_earned=run.xp_earned,
        level=progress.level if progress else 1,
        competitive_score=run.competitive_score,
        territory_changes=[
            TerritoryChangeResponse(
                cell_id=event.cell_id,
                action=event.action_type,
                power_before=float(event.power_before),
                power_after=float(event.power_after),
            )
            for event in events
        ],
    )


def _run_verdict(gps_score: int, activity: ActivityResult) -> tuple[int, str, bool]:
    activity_weight = activity.confidence if activity.activity_type == "RUNNING" else 20
    trust_score = round(gps_score * 0.7 + activity_weight * 0.3)
    if activity.activity_type in {"CAR", "CYCLING"}:
        return min(trust_score, 39), "SUSPICIOUS", False
    if activity.activity_type == "RUNNING" and gps_score >= 60 and activity.confidence >= 60:
        return trust_score, "VERIFIED", True
    if activity.activity_type == "WALKING" and gps_score >= 50:
        return trust_score, "CASUAL_VALID", False
    return trust_score, "UNVERIFIED", False


def _activity_reasons(activity: ActivityResult) -> list[str]:
    if activity.activity_type == "CAR":
        return ["VEHICLE_ACTIVITY"]
    if activity.activity_type == "CYCLING":
        return ["CYCLING_ACTIVITY"]
    if activity.activity_type != "RUNNING":
        return ["NOT_CONFIDENT_RUNNING"]
    return []


def _hash_nonce(nonce: str) -> str:
    return hashlib.sha256(nonce.encode()).hexdigest()


def _batch_checksum(request: RunBatchRequest) -> str:
    value = request.model_dump(mode="json", exclude={"session_nonce"})
    payload = json.dumps(value, sort_keys=True, separators=(",", ":")).encode()
    return hashlib.sha256(payload).hexdigest()


def _route_geometry(points: list[RoutePoint]) -> WKTElement | None:
    usable = [point for point in points if point.accuracy_meters <= 50]
    if len(usable) < 2:
        return None
    coordinates = ",".join(f"{point.longitude} {point.latitude}" for point in usable)
    return WKTElement(f"LINESTRING({coordinates})", srid=4326)
