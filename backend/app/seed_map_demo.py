"""Local-only, additive hardcoded map fixtures. Run with --apply to persist.

Never resets an existing account or captured fixture; test1 is never written.
All generated runs are explicitly marked DEMO, not verified outdoor activity.
"""

import argparse
import asyncio
import hashlib
import json
import uuid
from datetime import UTC, datetime, timedelta
from urllib.parse import urlparse

from geoalchemy2.elements import WKTElement
from sqlalchemy import func, or_, select

from app.core.config import get_settings
from app.db.session import async_session_factory, engine
from app.modules.profiles.models import Account, Device, Profile
from app.modules.progression.models import PlayerProgress, XpLedgerEntry
from app.modules.runs.models import Run, RunGpsPoint, RunSensorSegment
from app.modules.runs.route_math import RoutePoint, route_distance_meters
from app.modules.territories.game import area_m2, game_lock, points_for_area, polygon_part
from app.modules.territories.models import Territory, TerritoryEvent

TAG = "map-demo-v1"
NAMESPACE = uuid.UUID("614eef52-f013-42e2-82ee-228507fdd9a0")
# south, west, north, east — around the app's default SRM/Potheri map view.
BOXES = {
    "test2-land": (12.8240, 80.0422, 12.8250, 80.0434),
    "test3-land": (12.8240, 80.0440, 12.8250, 80.0452),
    "test4-original": (12.8218, 80.0428, 12.8230, 80.0452),
    "test3-recapture": (12.8218, 80.0428, 12.8230, 80.0440),
    "test4-yellow": (12.8218, 80.0440, 12.8230, 80.0452),
}


def identifier(name):
    return uuid.uuid5(NAMESPACE, name)


def route(box):
    south, west, north, east = box
    corners = [(south, west), (south, east), (north, east), (north, west)]
    result = []
    for a, b in zip(corners, corners[1:] + corners[:1], strict=True):
        for n in range(15):
            result.append(
                RoutePoint(
                    a[0] + (b[0] - a[0]) * n / 15,
                    a[1] + (b[1] - a[1]) * n / 15,
                    len(result) * 10000,
                    5,
                )
            )
    result.append(RoutePoint(*corners[0], 600000, 5))
    return result


async def shape(session, box):
    south, west, north, east = box
    return await polygon_part(session, func.ST_MakeEnvelope(west, south, east, north, 4326))


async def add_run(session, name, username, ended, xp, box):
    points = route(box)
    started = ended - timedelta(minutes=10)
    run_id = identifier(name)
    line = ",".join(f"{p.longitude} {p.latitude}" for p in points)
    session.add(
        Run(
            id=run_id,
            user_id=identifier(username),
            device_id=identifier(username + "-device"),
            state="FINISHED",
            server_started_at=started,
            client_started_at=started,
            finished_at=ended,
            distance_meters=round(route_distance_meters(points), 2),
            moving_seconds=600,
            elapsed_seconds=600,
            route=WKTElement(f"LINESTRING({line})", 4326),
            validation_status="DEMO",
            competitive_eligible=False,
            activity_type="WALKING",
            activity_confidence=0,
            trust_score=0,
            xp_earned=xp,
            territories_changed=1,
            rules_version=TAG,
            session_nonce_hash=hashlib.sha256(name.encode()).hexdigest(),
        )
    )
    await session.flush()
    session.add_all(
        [
            RunGpsPoint(
                run_id=run_id,
                sequence=i,
                latitude=p.latitude,
                longitude=p.longitude,
                position=WKTElement(f"POINT({p.longitude} {p.latitude})", 4326),
                client_recorded_at=started + timedelta(milliseconds=p.monotonic_ms),
                monotonic_ms=p.monotonic_ms,
                accuracy_meters=5,
            )
            for i, p in enumerate(points)
        ]
    )
    session.add(
        RunSensorSegment(
            run_id=run_id,
            sequence=0,
            start_monotonic_ms=0,
            end_monotonic_ms=600000,
            activity_type="WALKING",
            activity_confidence=0,
            features={"cadence_hz": 1.2, "acceleration_variance": 0.4, "demo_fixture": True},
        )
    )
    session.add(
        XpLedgerEntry(
            user_id=identifier(username),
            amount=xp,
            source_type="DEMO",
            source_id=str(run_id),
            rules_version=TAG,
        )
    )
    return run_id


async def seed(session, now):
    await game_lock(session)
    usernames = ["test2", "test3", "test4"]
    found = (await session.scalars(select(Profile).where(Profile.username.in_(usernames)))).all()
    if found:
        if len(found) == 3 and all(p.id == identifier(p.username) for p in found):
            return "already_exists_no_changes"
        raise RuntimeError(
            "A requested username already exists; refusing to overwrite any account."
        )
    emails = [f"{name}@runova.example.com" for name in usernames]
    if await session.scalar(
        select(Account.id).where(
            or_(Account.email.in_(emails), Account.id.in_([identifier(n) for n in usernames]))
        )
    ):
        raise RuntimeError("Demo account identifier/email collision; no data changed.")
    envelope = await shape(session, (12.8218, 80.0422, 12.8250, 80.0452))
    if await session.scalar(
        select(Territory.cell_id)
        .where(
            Territory.geometry.is_not(None),
            ~func.ST_IsEmpty(Territory.geometry),
            func.ST_Intersects(Territory.geometry, envelope),
        )
        .limit(1)
    ):
        raise RuntimeError("Existing land overlaps the demo location; no data changed.")

    ended = {
        "test2": now - timedelta(hours=1),
        "test3": now - timedelta(minutes=30),
        "test4": now - timedelta(hours=52),
    }
    for name, xp in [("test2", 120), ("test3", 240), ("test4", 150)]:
        session.add(Account(id=identifier(name), email=f"{name}@runova.example.com"))
        await session.flush()
        session.add(
            Profile(
                id=identifier(name),
                username=name,
                display_name=f"Test {name[-1]} (demo)",
                country_code="IN",
                state_region="Tamil Nadu",
                city="Chennai",
            )
        )
        await session.flush()
        session.add(
            PlayerProgress(
                user_id=identifier(name),
                fitness_xp=xp,
                level=1,
                current_streak_days=0 if name == "test4" else 1,
                longest_streak_days=1,
                last_qualifying_run_at=ended[name],
            )
        )
        session.add(
            Device(
                id=identifier(name + "-device"),
                user_id=identifier(name),
                model="Synthetic map demo",
                app_version=TAG,
            )
        )
    await session.flush()
    old_run = await add_run(
        session, "test4-original", "test4", ended["test4"], 150, BOXES["test4-original"]
    )
    run2 = await add_run(session, "test2-land", "test2", ended["test2"], 120, BOXES["test2-land"])
    run3 = await add_run(
        session, "test3-land", "test3", now - timedelta(hours=2), 120, BOXES["test3-land"]
    )
    recapture = await add_run(
        session, "test3-recapture", "test3", ended["test3"], 120, BOXES["test3-recapture"]
    )
    for name, owner, previous, multiplier, run_id in [
        ("test2-land", "test2", None, 1, run2),
        ("test3-land", "test3", None, 1, run3),
        ("test3-recapture", "test3", "test4", 2, recapture),
        ("test4-yellow", None, "test4", 1, old_run),
    ]:
        geometry = await shape(session, BOXES[name])
        cell_id = identifier(name).hex[:16]
        captured = ended[owner] if owner else ended["test4"]
        session.add(
            Territory(
                cell_id=cell_id,
                h3_resolution=0,
                geometry=geometry,
                owner_id=identifier(owner) if owner else None,
                previous_owner_id=identifier(previous) if previous else None,
                captured_at=captured,
                power_updated_at=captured,
                released_at=None if owner else ended["test4"] + timedelta(hours=48),
                base_power=100 if owner else 0,
                capture_count=2 if multiplier == 2 else 1,
                reward_points=points_for_area(await area_m2(session, geometry), multiplier),
            )
        )
        await session.flush()
        session.add(
            TerritoryEvent(
                cell_id=cell_id,
                run_id=run_id,
                actor_user_id=identifier(owner or "test4"),
                previous_owner_id=identifier(previous) if owner and previous else None,
                new_owner_id=identifier(owner or "test4"),
                action_type="RECAPTURED" if multiplier == 2 else "CAPTURED",
                power_before=0,
                power_after=100,
                occurred_at=captured,
                rules_version=TAG,
            )
        )
    await session.flush()
    return "created"


async def main(apply):
    engine.echo = False
    settings = get_settings()
    if settings.environment != "development" or urlparse(settings.database_url).hostname not in {
        "localhost",
        "127.0.0.1",
        "::1",
    }:
        raise RuntimeError("Demo seeding is restricted to the local development database.")
    try:
        async with async_session_factory() as session:
            outcome = await seed(session, datetime.now(UTC))
            scores = (
                await session.execute(
                    select(Profile.username, func.coalesce(func.sum(Territory.reward_points), 0))
                    .outerjoin(Territory, Territory.owner_id == Profile.id)
                    .where(Profile.id.in_([identifier(n) for n in ("test2", "test3", "test4")]))
                    .group_by(Profile.username)
                    .order_by(Profile.username)
                )
            ).all()
            report = {
                "result": outcome,
                "persisted": apply,
                "territory_points": {name: float(points) for name, points in scores},
                "map_center": [12.8231, 80.0442],
            }
            if apply:
                await session.commit()
            else:
                await session.rollback()
            print(json.dumps(report))
    finally:
        await engine.dispose()


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Persist the demo (default: dry run)")
    asyncio.run(main(parser.parse_args().apply))
