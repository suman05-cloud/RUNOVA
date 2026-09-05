# Infrastructure

Local development uses the root `compose.yaml` for PostGIS and Redis. Production
will use the same containerized backend with managed PostgreSQL/PostGIS, managed
Redis, TLS termination, encrypted backups, and region-appropriate data hosting.

No production provider is selected in the MVP foundation.

