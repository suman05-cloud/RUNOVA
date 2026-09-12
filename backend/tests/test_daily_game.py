"""Free-loop regression suite (replaces the retired daily-task game tests)."""

import uuid
from dataclasses import replace
from datetime import UTC, datetime, timedelta

import pytest
from httpx import ASGITransport, AsyncClient
from sqlalchemy import func, select, update
from sqlalchemy.ext.asyncio import AsyncSession
from test_milestones import login, start

from app.main import app
from app.modules.progression.models import PlayerProgress
from app.modules.runs.models import Run
from app.modules.runs.route_math import RoutePoint
from app.modules.territories.game import area_m2, capture_loops, expire_territories
from app.modules.territories.loops import loop_wkt
from app.modules.territories.models import Territory


def loop(west=80.12, east=80.122, south=12.95, north=12.952, reverse=False):
    corners = [(south, west), (south, east), (north, east), (north, west)]
    if reverse:
        corners.reverse()
    points = []
    for a, b in zip(corners, corners[1:] + corners[:1], strict=True):
        for n in range(20):
            points.append(
                RoutePoint(
                    a[0] + (b[0] - a[0]) * n / 20,
                    a[1] + (b[1] - a[1]) * n / 20,
                    len(points) * 8000,
                    5,
                )
            )
    points.append(replace(points[0], monotonic_ms=len(points) * 8000))
    return points


@pytest.mark.parametrize("reverse", [False, True])
def test_near_closed_loop_accepts_90_percent_in_either_direction(reverse):
    points = loop(reverse=reverse)
    assert loop_wkt(points)
    assert loop_wkt(points[:-7])  # 92.5% traversed; a short closing gap.
    assert loop_wkt(points[:-10]) is None
    assert loop_wkt(points[:40]) is None


def test_loop_rejects_bad_fixes_teleports_gaps_and_out_and_back():
    points = loop()
    assert loop_wkt([replace(p, accuracy_meters=80) for p in points]) is None
    assert loop_wkt([replace(p, monotonic_ms=i) for i, p in enumerate(points)]) is None
    assert loop_wkt([replace(p, monotonic_ms=i * 60000) for i, p in enumerate(points)]) is None


async def identity(client):
    headers = await login(client)
    user = uuid.UUID((await client.get("/v1/me", headers=headers)).json()["id"])
    run = await start(client, headers)
    return headers, user, uuid.UUID(run["run_id"])


def db_session(database):
    return AsyncSession(
        bind=database, expire_on_commit=False, join_transaction_mode="create_savepoint"
    )


@pytest.mark.asyncio
async def test_free_loop_full_gps_upload_and_retry(database):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        headers = await login(client)
        # No task endpoints or pre-generated locked tiles.
        assert (
            await client.post(
                "/v1/territories/daily-task",
                headers=headers,
                json={"latitude": 12.95, "longitude": 80.12},
            )
        ).status_code == 404
        bounds = {"min_lat": 12.949, "max_lat": 12.953, "min_lng": 80.119, "max_lng": 80.123}
        assert (await client.get("/v1/territories", headers=headers, params=bounds)).json() == []
        run = await start(client, headers)
        points = loop()[:-7]
        now = datetime.now(UTC)
        started = now - timedelta(milliseconds=points[-1].monotonic_ms + 2000)
        await database.execute(
            update(Run).where(Run.id == uuid.UUID(run["run_id"])).values(server_started_at=started)
        )
        path = f"/v1/runs/{run['run_id']}"
        payload = {
            "batch_id": str(uuid.uuid4()),
            "session_nonce": run["session_nonce"],
            "first_sequence": 0,
            "last_sequence": len(points) - 1,
            "points": [
                {
                    "sequence": n,
                    "latitude": p.latitude,
                    "longitude": p.longitude,
                    "monotonic_ms": p.monotonic_ms,
                    "accuracy_meters": 5,
                    "client_recorded_at": (
                        started + timedelta(milliseconds=p.monotonic_ms)
                    ).isoformat(),
                }
                for n, p in enumerate(points)
            ],
            "sensor_segments": [
                {
                    "sequence": 0,
                    "start_monotonic_ms": 0,
                    "end_monotonic_ms": points[-1].monotonic_ms,
                    "features": {"cadence_hz": 1.2, "acceleration_variance": 0.4},
                }
            ],
        }
        uploaded = await client.put(path + "/batches", headers=headers, json=payload)
        assert uploaded.status_code == 200, uploaded.text
        finish = {
            "session_nonce": run["session_nonce"],
            "client_finished_at": now.isoformat(),
            "elapsed_seconds": 640,
            "moving_seconds": 640,
        }
        done = await client.post(path + "/finish", headers=headers, json=finish)
        assert done.status_code == 200, done.text
        assert done.json()["activity_type"] == "WALKING"
        assert len(done.json()["territory_changes"]) == 1
        again = await client.post(path + "/finish", headers=headers, json=finish)
        assert again.json() == done.json()
        progress = (await client.get("/v1/me/progression", headers=headers)).json()
        assert progress["territory_points"] > 0 and progress["current_streak_days"] == 1
        areas = (await client.get("/v1/territories", headers=headers, params=bounds)).json()
        assert len(areas) == 1 and areas[0]["state"] == "MINE"
        assert areas[0]["geometry"]["type"] == "MultiPolygon"
        other = await login(client)
        assert (await client.get("/v1/territories", headers=other, params=bounds)).json()[0][
            "state"
        ] == "TAKEN"


@pytest.mark.asyncio
async def test_partial_yellow_capture_double_points_remainder_and_no_compounding(database):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        owner, owner_id, run_id = await identity(client)
        other, other_id, other_run = await identity(client)
        now = datetime.now(UTC)
        async with db_session(database) as session:
            changes = await capture_loops(
                session, owner_id, run_id, loop(), now - timedelta(minutes=12), now
            )
            original = await session.get(Territory, changes[0].cell_id)
            whole_area = await area_m2(session, original.geometry)
            # Green/red cannot be stolen or double-awarded, even by a whole loop.
            assert not await capture_loops(
                session, other_id, other_run, loop(), now - timedelta(minutes=12), now
            )
            await expire_territories(session, now + timedelta(hours=48, seconds=-1))
            assert original.owner_id == owner_id
            await expire_territories(session, now + timedelta(hours=48))
            assert original.owner_id is None
            original.released_at = now - timedelta(minutes=20)
            half = loop(east=80.121)
            changes = await capture_loops(
                session, other_id, other_run, half, now - timedelta(minutes=12), now
            )
            assert len(changes) == 1 and changes[0].action == "RECAPTURED"
            captured = await session.get(Territory, changes[0].cell_id)
            claimed_area = await area_m2(session, captured.geometry)
            remainder = await area_m2(session, original.geometry)
            assert claimed_area == pytest.approx(whole_area / 2, rel=0.001)
            assert remainder == pytest.approx(whole_area / 2, rel=0.001)
            assert float(captured.reward_points) == pytest.approx(claimed_area / 100 * 2, abs=0.01)
            assert not await capture_loops(
                session, other_id, other_run, half, now - timedelta(minutes=12), now
            )
            await session.commit()
        assert (await client.get("/v1/me/progression", headers=owner)).json()[
            "territory_points"
        ] == 0
        for scope in ("GLOBAL", "COUNTRY"):
            ranks = (
                await client.get(
                    "/v1/leaderboards",
                    headers=other,
                    params={"category": "TERRITORY_POINTS", "scope": scope},
                )
            ).json()
            assert any(e["is_current_user"] for e in ranks["entries"])
        bounds = {"min_lat": 12.949, "max_lat": 12.953, "min_lng": 80.119, "max_lng": 80.123}
        states = {
            a["state"]
            for a in (await client.get("/v1/territories", headers=other, params=bounds)).json()
        }
        assert states == {"MINE", "OPEN"}
        third, third_id, third_run = await identity(client)
        async with db_session(database) as session:
            await expire_territories(session, now + timedelta(hours=48))
            captured = await session.get(Territory, captured.cell_id)
            captured.released_at = now - timedelta(minutes=20)
            await session.flush()
            changes = await capture_loops(
                session, third_id, third_run, half, now - timedelta(minutes=12), now
            )
            won = await session.get(Territory, changes[0].cell_id)
            assert float(won.reward_points) == pytest.approx(claimed_area / 100 * 2, abs=0.01)


@pytest.mark.asyncio
async def test_any_recent_activity_protects_all_owned_areas(database):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        _, user_id, run_id = await identity(client)
        now = datetime.now(UTC)
        async with db_session(database) as session:
            changes = await capture_loops(
                session, user_id, run_id, loop(), now - timedelta(minutes=12), now
            )
            area = await session.get(Territory, changes[0].cell_id)
            area.captured_at = area.power_updated_at = now - timedelta(days=5)
            progress = await session.get(PlayerProgress, user_id)
            progress.last_qualifying_run_at = now - timedelta(hours=24)
            await session.flush()
            await expire_territories(session, now)
            assert area.owner_id == user_id
            await expire_territories(session, now + timedelta(hours=24))
            assert area.owner_id is None


@pytest.mark.asyncio
async def test_taken_overlap_is_excluded_and_stale_yellow_cannot_be_replayed(database):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        _, owner, run = await identity(client)
        _, other, other_run = await identity(client)
        now = datetime.now(UTC)
        async with db_session(database) as session:
            changes = await capture_loops(
                session, owner, run, loop(east=80.121), now - timedelta(minutes=12), now
            )
            owned = await session.get(Territory, changes[0].cell_id)
            changes = await capture_loops(
                session, other, other_run, loop(), now - timedelta(minutes=12), now
            )
            fresh = await session.get(Territory, changes[0].cell_id)
            assert float(fresh.reward_points) == pytest.approx(float(owned.reward_points), abs=0.02)
            overlap = await session.scalar(
                select(func.ST_Area(func.ST_Intersection(owned.geometry, fresh.geometry)))
            )
            assert overlap == 0
            await expire_territories(session, now + timedelta(hours=48))
            owned.released_at = now  # Run took place before release.
            _, late_user, late_run = await identity(client)
            assert not await capture_loops(
                session, late_user, late_run, loop(east=80.121), now - timedelta(minutes=12), now
            )
