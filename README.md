# Runova

**Run. Claim. Conquer.**

Runova is an Android-first, gamified running application. A completed and
validated run changes ownership and strength of H3 territories on a real-world
map.

## MVP scope

The first release is free and Android-only. It includes run recording, offline
sync, MapLibre maps, H3 territory capture and defense, trust scoring, Fitness
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
- H3 territory capture, defense, attack, decay, power transfer, and map polygons.
- Fitness XP, levels, competitive score, global leaderboard, run history API, and profiles.

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

```powershell
.\.tooling\flutter\bin\flutter.bat pub get --directory mobile
.\.tooling\flutter\bin\flutter.bat run --project-dir mobile `
  --dart-define=RUNOVA_API_BASE_URL=http://10.0.2.2:8000 `
  --dart-define=RUNOVA_MAP_STYLE_URL=https://demotiles.maplibre.org/style.json
```

The demo MapLibre style is for development only. Production must use a
configured tile provider and preserve map attribution.

## Automated checks

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
