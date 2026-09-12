import uuid
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app
from app.modules.progression.service import apply_streak, current_streak


def test_streak_same_day_next_day_gap_and_expiry():
    state = SimpleNamespace(
        current_streak_days=0, longest_streak_days=0, last_qualifying_run_at=None
    )
    day = datetime(2026, 9, 5, 23, 59, tzinfo=UTC)
    apply_streak(state, day)
    apply_streak(state, day + timedelta(seconds=10))
    assert state.current_streak_days == 1
    apply_streak(state, day + timedelta(minutes=2))
    assert state.current_streak_days == state.longest_streak_days == 2
    assert current_streak(state, day + timedelta(days=4)) == 0
    apply_streak(state, day + timedelta(days=4))
    assert state.current_streak_days == 1
    assert state.longest_streak_days == 2
    apply_streak(state, day)
    assert state.last_qualifying_run_at == day + timedelta(days=4)


async def login(client):
    suffix = uuid.uuid4().hex[:12]
    response = await client.post(
        "/v1/auth/direct",
        json={
            "email": f"{suffix}@example.com",
            "username": f"test_{suffix}",
        },
    )
    assert response.status_code == 200, response.text
    return {"Authorization": f"Bearer {response.json()['access_token']}"}


async def start(client, headers):
    response = await client.post(
        "/v1/runs",
        headers=headers,
        json={
            "device": {"id": str(uuid.uuid4()), "model": "integration-test"},
            "client_started_at": datetime.now(UTC).isoformat(),
        },
    )
    assert response.status_code == 201, response.text
    return response.json()


def batch(run):
    now = datetime.now(UTC)
    return {
        "batch_id": str(uuid.uuid4()),
        "session_nonce": run["session_nonce"],
        "first_sequence": 0,
        "last_sequence": 1,
        "points": [
            {
                "sequence": n,
                "latitude": 23.123 + n * 0.000027,
                "longitude": 88.123,
                "client_recorded_at": (now + timedelta(seconds=n)).isoformat(),
                "monotonic_ms": n * 1000,
                "accuracy_meters": 5,
            }
            for n in range(2)
        ],
        "sensor_segments": [
            {
                "sequence": 0,
                "start_monotonic_ms": 0,
                "end_monotonic_ms": 1000,
                "features": {"cadence_hz": 2.5, "acceleration_variance": 1.2},
            }
        ],
    }


@pytest.mark.asyncio
async def test_run_authz_conflicts_profile_city_and_finish_retry(database):
    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        owner = await login(client)
        other = await login(client)
        run = await start(client, owner)
        path = f"/v1/runs/{run['run_id']}"
        payload = batch(run)
        wrong = {**payload, "session_nonce": "x" * 40}
        assert (await client.put(path + "/batches", headers=owner, json=wrong)).status_code == 403
        assert (await client.get(path, headers=other)).status_code == 404
        assert (await client.get(path)).status_code in {401, 403}
        first = await client.put(path + "/batches", headers=owner, json=payload)
        assert first.status_code == 200, first.text
        conflict = {**payload, "last_sequence": 2}
        conflict_response = await client.put(path + "/batches", headers=owner, json=conflict)
        assert conflict_response.status_code == 409
        overlap = {**payload, "batch_id": str(uuid.uuid4())}
        assert (await client.put(path + "/batches", headers=owner, json=overlap)).status_code == 409
        private = await client.get(path, headers=owner)
        assert private.json()["route_points"] == []
        route = await client.get(path + "?include_route=true", headers=owner)
        assert len(route.json()["route_points"]) == 2
        assert (await client.get(path + "?include_route=true", headers=other)).status_code == 404
        edit = await client.patch(
            "/v1/me",
            headers=owner,
            json={
                "display_name": "New Runner",
                "city": "Test City",
                "country_code": "in",
                "profile_is_public": True,
            },
        )
        assert edit.status_code == 200, edit.text
        assert edit.json()["country_code"] == "IN"
        assert (
            await client.patch("/v1/me", headers=owner, json={"country_code": None})
        ).status_code == 422
        finish = {
            "session_nonce": run["session_nonce"],
            "client_finished_at": datetime.now(UTC).isoformat(),
            "elapsed_seconds": 10,
            "moving_seconds": 1,
        }
        done = await client.post(path + "/finish", headers=owner, json=finish)
        assert done.status_code == 200, done.text
        replay = await client.put(path + "/batches", headers=owner, json=payload)
        assert replay.status_code == 200 and replay.json()["duplicate"]
        again = await client.post(path + "/finish", headers=owner, json=finish)
        assert again.json()["xp_earned"] == done.json()["xp_earned"]
        progress = (await client.get("/v1/me/progression", headers=owner)).json()
        assert progress["fitness_xp"] == done.json()["xp_earned"]
        assert progress["current_streak_days"] == 0  # One second is not qualifying activity.
        local = (
            await client.get("/v1/leaderboards?scope=CITY&scope_key=Test%20City", headers=owner)
        ).json()
        assert any(entry["is_current_user"] for entry in local["entries"])
        await client.patch("/v1/me", headers=owner, json={"city": "Next City"})
        old = (
            await client.get("/v1/leaderboards?scope=CITY&scope_key=Test%20City", headers=owner)
        ).json()
        assert not any(entry["is_current_user"] for entry in old["entries"])


@pytest.mark.asyncio
async def test_taken_grid_cannot_be_attacked_by_crossing(database):
    from sqlalchemy import insert, select

    from app.modules.territories.h3_grid import cell_for_coordinate
    from app.modules.territories.models import Territory

    async with AsyncClient(transport=ASGITransport(app=app), base_url="http://test") as client:
        owner = await login(client)
        attacker = await login(client)
        owner_id = uuid.UUID((await client.get("/v1/me", headers=owner)).json()["id"])
        cell = cell_for_coordinate(23.123, 88.123)
        await database.execute(
            insert(Territory).values(
                cell_id=cell,
                h3_resolution=10,
                owner_id=owner_id,
                base_power=100,
                power_updated_at=datetime.now(UTC),
            )
        )
        run = await start(client, attacker)
        path = f"/v1/runs/{run['run_id']}"
        await client.put(path + "/batches", headers=attacker, json=batch(run))
        response = await client.post(
            path + "/finish",
            headers=attacker,
            json={
                "session_nonce": run["session_nonce"],
                "client_finished_at": datetime.now(UTC).isoformat(),
                "elapsed_seconds": 10,
                "moving_seconds": 1,
            },
        )
        assert response.status_code == 200, response.text
        assert response.json()["territory_changes"] == []
        assert (
            await database.scalar(select(Territory.owner_id).where(Territory.cell_id == cell))
            == owner_id
        )
