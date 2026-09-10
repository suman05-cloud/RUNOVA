import uuid
from typing import Annotated

from fastapi import APIRouter, Depends, HTTPException, Query, status
from sqlalchemy import select
from sqlalchemy.ext.asyncio import AsyncSession

from app.core.security import CurrentUserId
from app.db.session import get_db_session
from app.modules.runs.models import Run
from app.modules.runs.schemas import (
    BatchAcceptedResponse,
    CreateRunRequest,
    CreateRunResponse,
    FinishRunRequest,
    FinishRunResponse,
    RunBatchRequest,
    RunDetailResponse,
    RunSummaryResponse,
)
from app.modules.runs.service import (
    BatchConflictError,
    InvalidRunSessionError,
    RunNotFoundError,
    RunStateError,
    create_run,
    finish_run,
    get_run_detail,
    upload_run_batch,
)

router = APIRouter(prefix="/runs", tags=["runs"])
SessionDependency = Annotated[AsyncSession, Depends(get_db_session)]


@router.get("/{run_id}", response_model=RunDetailResponse)
async def run_detail(
    run_id: uuid.UUID,
    user_id: CurrentUserId,
    session: SessionDependency,
    include_route: bool = False,
) -> RunDetailResponse:
    try:
        return await get_run_detail(session, user_id, run_id, include_route=include_route)
    except RunNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Run not found") from exc


@router.post("", response_model=CreateRunResponse, status_code=status.HTTP_201_CREATED)
async def start_run(
    request: CreateRunRequest, user_id: CurrentUserId, session: SessionDependency
) -> CreateRunResponse:
    try:
        return await create_run(session, user_id, request)
    except InvalidRunSessionError as exc:
        raise HTTPException(status_code=403, detail="Device belongs to another account") from exc


@router.put("/{run_id}/batches", response_model=BatchAcceptedResponse)
async def accept_batch(
    run_id: uuid.UUID,
    request: RunBatchRequest,
    user_id: CurrentUserId,
    session: SessionDependency,
) -> BatchAcceptedResponse:
    try:
        return await upload_run_batch(session, user_id, run_id, request)
    except RunNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Run not found") from exc
    except InvalidRunSessionError as exc:
        raise HTTPException(status_code=403, detail="Invalid run session") from exc
    except RunStateError as exc:
        raise HTTPException(status_code=409, detail="Run is not accepting uploads") from exc
    except BatchConflictError as exc:
        raise HTTPException(status_code=409, detail="Batch ID was reused with new data") from exc


@router.post("/{run_id}/finish", response_model=FinishRunResponse)
async def complete_run(
    run_id: uuid.UUID,
    request: FinishRunRequest,
    user_id: CurrentUserId,
    session: SessionDependency,
) -> FinishRunResponse:
    try:
        return await finish_run(session, user_id, run_id, request)
    except RunNotFoundError as exc:
        raise HTTPException(status_code=404, detail="Run not found") from exc
    except InvalidRunSessionError as exc:
        raise HTTPException(status_code=403, detail="Invalid run session") from exc
    except RunStateError as exc:
        raise HTTPException(status_code=409, detail="Run cannot be finished") from exc


@router.get("", response_model=list[RunSummaryResponse])
async def list_runs(
    user_id: CurrentUserId,
    session: SessionDependency,
    limit: Annotated[int, Query(ge=1, le=100)] = 25,
    offset: Annotated[int, Query(ge=0)] = 0,
) -> list[RunSummaryResponse]:
    rows = list(
        (
            await session.scalars(
                select(Run)
                .where(Run.user_id == user_id)
                .order_by(Run.server_started_at.desc())
                .limit(limit)
                .offset(offset)
            )
        ).all()
    )
    return [
        RunSummaryResponse(
            id=run.id,
            started_at=run.server_started_at,
            finished_at=run.finished_at,
            distance_meters=float(run.distance_meters),
            elapsed_seconds=run.elapsed_seconds,
            validation_status=run.validation_status,
            activity_type=run.activity_type,
            xp_earned=run.xp_earned,
            territories_changed=run.territories_changed,
        )
        for run in rows
    ]
