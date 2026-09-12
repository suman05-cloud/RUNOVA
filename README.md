# Runova

**Run. Claim. Conquer.**

Runova is an Android-first, gamified running application. A completed and
validated walking or running loop can claim its enclosed area on a real-world
map.

## MVP scope

The first release is free and Android-only. It includes run recording, offline
sync, MapLibre maps, free-form area capture and inactivity release, trust scoring, Fitness
XP, run history, profiles, and leaderboards. Payments, subscriptions, clubs,
cash prizes, and machine-learning anti-cheat are intentionally excluded.

## Implemented vertical slice

See [next milestone implementation and verification gates](docs/next-milestones.md)
for session restore, usable history/profiles, background recording, durable sync,
backend hardening, and the remaining device/database checks.

- Development account creation with email, unique username, profile, JWT, and logout.
- Android GPS recording and accelerometer feature collection with an offline SQLite queue.
- Idempotent GPS/sensor upload and server-authoritative distance/trust calculation.
- Walking, running, cycling, car, stationary, and unknown activity evaluation.
- Optional OSRM-compatible road plausibility matching; trails are not rejected for being off-road.
- Random near-closed loop capture, 48-hour inactivity release, and partial yellow-area
  recapture for 2× base area points. No preset grids, locked land, or daily tasks.
- Viewer-relative colors: green for yours, red for others, yellow for released land.
- Fitness XP and levels retained separately from current ownership points;
  Global/Country/State/City territory leaderboards, run history API, and profiles.

Current territory rules and testing instructions: [Free-loop area game](docs/free-loop-game.md).

Direct login is intentionally development-only. Email OTP is the next authentication upgrade.

## Repository

- `mobile/` — Flutter Android application.
- `backend/` — FastAPI modular monolith.
- `infra/` — infrastructure notes and future deployment definitions.
- `docs/` — architecture and versioned gameplay rules.

## Local prerequisites

- Flutter stable and Android SDK API 36.
- Python 3.12.
- Docker Desktop with Compose.
- A physical Android device is strongly recommended for GPS testing.

The repository can use the workspace-local Flutter SDK at
`.tooling/flutter/bin/flutter` while bootstrapping.

## Start the backend

```powershell
Copy-Item .env.example .env
docker compose up -d postgres redis
python -m venv .venv
.\.venv\Scripts\python.exe -m pip install -e ".\backend[dev]"
.\.venv\Scripts\alembic.exe -c backend\alembic.ini upgrade head
.\.venv\Scripts\uvicorn.exe app.main:app --app-dir backend --reload
```

The liveness endpoint is `http://localhost:8000/health/live`, and generated API
documentation is available at `http://localhost:8000/docs` in development.

Useful MVP endpoints are under `/v1`: `/auth/direct`, `/me`, `/runs`,
`/territories`, and `/leaderboards`.

## Start the Android application

For a USB-connected Android phone, enable USB debugging, approve the computer,
and leave the backend and Docker running. From the repository root:

```powershell
.\scripts\run-android.ps1
```

The script finds the SDK from environment variables or Android's generated
`local.properties`, forwards port 8000 over USB, and uses workspace-local package
and Java socket temporary directories. If needed, specify
`-AndroidSdkPath D:\AndroidSDK -DeviceId YOUR_DEVICE_ID`. These settings apply
only during the script; no global environment settings are changed. Keep USB
connected for server access; reconnecting the cable requires rerunning the script.

Install NDK **28.2.13676358** in Android Studio's SDK Manager (SDK Tools → Show
Package Details → NDK Side by side). MapLibre is temporarily pinned to **0.26.0**
with `android.builtInKotlin=false` because 0.27.0 conflicts with legacy-Kotlin
plugins on AGP 9 ([upstream issue](https://github.com/maplibre/flutter-maplibre-gl/issues/1008)).
Do not enable built-in Kotlin until the complete plugin set supports it.

Maps use OpenFreeMap's Liberty style with OpenStreetMap data, without an API
key. Keep the built-in attribution visible. The public service requires internet
and has no uptime guarantee. Override `RUNOVA_MAP_STYLE_URL` at build time to use
another MapLibre-compatible style. The Map tab's location button requests phone
location permission and centers the map; territory loading requires the Runova API.

Android smoke check (2026-09-10): the ARM64 debug APK built, installed, and
opened the profile creation screen on a Samsung SM-A146B running Android 15.
Backend readiness, Flutter analysis, 8 mobile tests, and 16 backend tests passed.
Outdoor GPS, screen-off recording, map interaction, and the complete phone run
flow still need field testing. This verifies development launch, not release readiness.
The subsequent OpenFreeMap update was also installed and visually checked on the
same phone: streets, buildings, water, place labels, and the map controls rendered.

## Automated checks

The Home bell and Profile's Events entry open an in-app notification inbox with
completed runs, XP, territory update counts, unread filtering, and sync retries.
Profile → Settings contains account links, notification preferences, appearance,
device permissions, help, and a copyable support report. Notification preferences
and read status are stored per account on the device; theme follows the existing
device-wide appearance preference. Events are derived from synced run history.
Push delivery, paid subscriptions, additional languages, and a configured support
contact are not available in this version.

```powershell
cd backend
..\.venv\Scripts\ruff.exe check --no-cache app tests
..\.venv\Scripts\python.exe -m pytest -q

cd ..\mobile
..\.tooling\flutter\bin\flutter.bat analyze
..\.tooling\flutter\bin\flutter.bat test
```

The backend suite includes a full account → GPS/sensor upload → verified run →
territory → XP → leaderboard database test. A physical-phone test still requires
an installed Android SDK and USB debugging.

## Engineering rules

1. The server is authoritative for run validation, XP, leaderboards, and territory ownership.
2. Every upload operation must be idempotent.
3. Raw routes are private by default.
4. Fitness XP, Territory Power, and Competitive Score remain separate.
5. Suspicious activity loses competitive eligibility; one anomaly never automatically bans a user.
