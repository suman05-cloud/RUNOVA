import uuid
from datetime import UTC, datetime, timedelta

import pytest
from httpx import ASGITransport, AsyncClient

from app.main import app


@pytest.mark.asyncio
async def test_account_run_validation_territory_and_leaderboard_pipeline(database) -> None:
    unique = uuid.uuid4().hex[:12]
    now = datetime.now(UTC)
    async with AsyncClient(
        transport=ASGITransport(app=app),
        base_url="http://test",
    ) as client:
        login = await client.post(
            "/v1/auth/direct",
            json={
                "email": f"runner-{unique}@example.com",
                "username": f"runner_{unique}",
                "display_name": "Pipeline Runner",
            },
        )
        assert login.status_code == 200, login.text
        headers = {"Authorization": f"Bearer {login.json()['access_token']}"}

        started = await client.post(
            "/v1/runs",
            headers=headers,
            json={
                "device": {"id": str(uuid.uuid4()), "model": "pytest"},
                "client_started_at": now.isoformat(),
            },
        )
        assert started.status_code == 201, started.text
        run = started.json()

        points = []
        for sequence in range(8):
            points.append(
                {
                    "sequence": sequence,
                    "latitude": 22.5726 + sequence * 0.000135,
                    "longitude": 88.3639,
                    "client_recorded_at": (now + timedelta(seconds=sequence * 5)).isoformat(),
                    "monotonic_ms": sequence * 5000,
                    "accuracy_meters": 5,
                    "speed_mps": 3,
                }
            )
        batch_id = str(uuid.uuid4())
        batch_payload = {
            "batch_id": batch_id,
            "session_nonce": run["session_nonce"],
            "first_sequence": 0,
            "last_sequence": 7,
            "points": points,
            "sensor_segments": [
                {
                    "sequence": 0,
                    "start_monotonic_ms": 0,
                    "end_monotonic_ms": 35000,
                    "features": {
                        "acceleration_variance": 1.2,
                        "cadence_hz": 2.5,
                        "mean_jerk": 1.1,
                    },
                }
            ],
        }
        batch = await client.put(
            f"/v1/runs/{run['run_id']}/batches", headers=headers, json=batch_payload
        )
        assert batch.status_code == 200, batch.text
        duplicate = await client.put(
            f"/v1/runs/{run['run_id']}/batches", headers=headers, json=batch_payload
        )
        assert duplicate.status_code == 200
        assert duplicate.json()["duplicate"] is True

        finished = await client.post(
            f"/v1/runs/{run['run_id']}/finish",
            headers=headers,
            json={
                "session_nonce": run["session_nonce"],
                "client_finished_at": (now + timedelta(seconds=40)).isoformat(),
                "elapsed_seconds": 40,
                "moving_seconds": 35,
            },
        )
        assert finished.status_code == 200, finished.text
        result = finished.json()
        assert result["activity_type"] == "RUNNING"
        assert result["validation_status"] == "VERIFIED"
        assert result["competitive_eligible"] is True
        assert result["xp_earned"] > 0
        assert result["territory_changes"]

        progression = await client.get("/v1/me/progression", headers=headers)
        assert progression.status_code == 200
        assert progression.json()["fitness_xp"] == result["xp_earned"]

        leaderboard = await client.get("/v1/leaderboards", headers=headers)
        assert leaderboard.status_code == 200
        assert any(entry["is_current_user"] for entry in leaderboard.json()["entries"])
