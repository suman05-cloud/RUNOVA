# ADR 0001: System foundation

Status: Accepted

## Decision

Runova begins as an Android-only Flutter client and a FastAPI modular monolith.
PostgreSQL/PostGIS is the source of truth. H3 cell IDs are gameplay identifiers,
and Redis is used only for ephemeral concerns such as rate limits, idempotency
windows, and leaderboard caching.

Supabase provides user authentication, but the client does not receive direct
write access to gameplay tables. The FastAPI service validates the user JWT and
performs every gameplay mutation.

## Consequences

- The MVP can be deployed and operated as one backend service plus one worker.
- Module boundaries are kept explicit without distributed-system complexity.
- Territory updates can use database transactions and row locks.
- The client may display provisional territory changes, but server results win.

## Initial modules

- Profiles and devices
- Runs and offline uploads
- Run validation
- Territories and territory events
- Progression and XP ledger
- Leaderboards

