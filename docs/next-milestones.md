# Runova milestone implementation — 10 September 2026

The three milestones are implemented and local automated checks pass, including
PostGIS integration. Physical Android verification remains an acceptance gate;
no commit or push was made.

## Mobile usability

- Stored sessions restore through GET /v1/me; protected routes redirect to login
  after a 401. Offline restoration can use a previously validated cached profile.
- PATCH /v1/me edits display name, city, country code, and profile visibility.
  Changing or clearing a city also moves/removes the user's CITY leaderboard rows.
- Progression includes owned-territory count and a UTC streak. The current streak
  reads as zero after a missed day; the best streak remains.
- Dashboard shows level, XP remaining, total/last completed distance, streak, and
  owned territories. History loads pages of real runs with refresh and sync status.
- Run details are owner-only. Raw GPS points require include_route=true, requested
  only after tapping “Show my private route.” Map previews disclose truncation
  above 5,000 samples. Detail and completion screens show stats, trust, XP,
  current level, and individual territory events.
- Profiles link to Android app permission settings and include a privacy notice.
- Device registrations now report manufacturer/model and Android release.

## Tracking and sync

- Requests notification and activity-recognition permissions before tracking.
- Uses geolocator AndroidSettings with an ongoing foreground notification and
  enableWakeLock=true. This acquires the service's CPU wake lock.
- Deliberate correction to the proposed plan: wakelock_plus was not added because
  it keeps the display awake, rather than guaranteeing screen-off CPU/sensor work.
- Elapsed time uses a start timestamp and accumulated pauses, independent of timer
  ticks. Moving seconds count measured GPS intervals at >= 0.5 m/s; poor fixes,
  implausible speeds, and intervals over 30 seconds cannot invent moving time.
- Foreground return restarts stale GPS/sensor streams while preserving the run.
  Sensor and GPS writes are serialized, drained before finish, and surface errors.
- SQLite schema v2 adds sync status, account ownership, and a cached finish result.
  The finish envelope is saved as PENDING_SYNC before network access.
- Retries run at startup, login, connectivity regain, and periodically while the
  app process is alive. History also offers manual retry.
- Each account can only sync its own pending runs. A 401 pauses sync until login.
- GPS batches are capped at 500 points and sensor batches at 100 segments. Stable
  IDs permit replay after partial uploads or lost responses. Backend duplicate
  acknowledgement also works after finalization; repeated finish grants no new XP.
- Only after a confirmed finish does one local transaction cache the result, mark
  SYNCED, clear the nonce, and delete that run's uploaded GPS/sensor rows.

Existing v1 rows are migrated to LEGACY, retaining samples. They have no stored
account owner or stable historical batch IDs, so they are not automatically
replayed under whichever account next signs in.

A server connection is still needed to start a new run. Offline finish/retry is
supported after that start. This foreground-service approach does not guarantee
continuity after Android kills the app process or the user force-stops it.

## Backend hardening and CI

- CI supplies PostGIS 16/3.5, waits for health, and migrates before pytest.
  It uses RUNOVA_DEV_JWT_SECRET (the actual setting name). Rate limiting is off in
  tests. Mobile CI is pinned to the locally used Flutter 3.47.2.
- Redis fixed-window limits: 10 direct-login requests/IP/minute and 240
  API requests/authenticated user/minute; unauthenticated calls use their source IP.
  Atomic counters expire, and 429 responses carry Retry-After. Redis outages
  allow requests with a throttled warning.
- JSON request logs include request ID, method, route template, status, and duration.
  Error responses use a stable INTERNAL_ERROR envelope. Request bodies, tokens,
  emails, raw route samples, and query strings are not logged by this middleware.
- Device score reports a registration-count heuristic (80 baseline, penalties
  beyond three registrations), not hardware attestation. Cross-account reuse of
  an existing device ID remains rejected. This diagnostic does not alter the
  current GPS/activity verdict.
- Tests cover private detail authorization, conflicting batches, wrong nonces,
  profile edits/city changes, UTC streak boundaries, repeated finish, territory
  attack/transfer, middleware failures, session restoration/expiry, elapsed time,
  moving time, stable offline retries, and confirmed-only sample cleanup.
- Database test writes are enclosed in a rollback transaction, including API commits.

## Verification and remaining gates

Latest local results: eight mobile tests pass across session, timing, SQLite retry,
and widget suites. Flutter analysis and Ruff pass. All 16 backend tests pass,
including the three PostGIS integration tests. Alembic upgrade and schema-drift
checks pass; no new migration is needed for the backend changes.

Docker initially failed on inaccessible stale Windows runtime sockets. Individual
socket rename attempts failed. After confirming Docker was stopped and checking
that the affected directories contained only zero-byte runtime endpoints, their
directories were renamed to backups and recreated. Docker, PostGIS, and Redis now
start successfully. Containers, images, stored credentials, and database volumes
were preserved. Backups are retained at:

- C:\Users\Suman Patari\AppData\Local\Docker\run.runova-backup-20260910
- C:\Users\Suman Patari\AppData\Local\Docker\run.runova-backup-20260910-2
- C:\Users\Suman Patari\AppData\Local\docker-secrets-engine.runova-backup-20260910

The first repair exposed a second stale endpoint in the secrets-engine runtime
directory; that directory contained only engine.sock, not stored secrets.
The repair was based on the observed local logs, not a Docker factory reset.
Docker's [troubleshooting documentation](https://docs.docker.com/desktop/troubleshoot-and-support/troubleshoot/)
describes the diagnostic/log workflow.

Repeat the local checks with:

~~~powershell
Set-Location E:\RUNOVA
docker compose up -d postgres redis
Set-Location backend
..\.venv\Scripts\alembic.exe upgrade head
..\.venv\Scripts\alembic.exe check
..\.venv\Scripts\ruff.exe check --no-cache .
..\.venv\Scripts\python.exe -m pytest -q
Set-Location ..\mobile
..\.tooling\flutter\bin\flutter.bat analyze
..\.tooling\flutter\bin\flutter.bat test
~~~

CI configuration is updated; no remote CI execution is claimed.

## Physical Android acceptance checklist

1. Start with fine location allowed; verify notification and activity permission
   prompts. Deny location once and check the actionable error, then grant it.
2. Record outdoors for 10 minutes with the screen locked. Confirm the persistent
   notification, continuous GPS timestamps, plausible distance, elapsed/moving
   time, motion windows, and battery use after unlocking.
3. Pause for two minutes, walk while paused, then resume. Check that paused
   time does not increase active duration or measured moving seconds.
4. Start online, disable connectivity, finish, and reopen the app. Check pending
   status and retained samples. Restore connectivity: exactly one reward and one
   server run result should appear, followed by local sample cleanup.
5. Interrupt connectivity after a batch has been accepted and after finish was
   accepted but before its response arrives. Retry; verify no duplicates.
6. Expire the token while a run is queued. Confirm login redirect and no sample
   loss. Sign in to another account: the first account's queue must not upload.
7. Open another app during a run, return, and verify recovery without duplicate
   subscriptions or counting an unobserved GPS gap as moving time.
8. Verify walking, running, cycling, and car examples on a real phone. Current
   classification is a heuristic; do not interpret its confidence as measured accuracy.

Email OTP, production hosting/workers, road-match verdict weighting, payments,
clubs, and trained ML classification remain deferred.
