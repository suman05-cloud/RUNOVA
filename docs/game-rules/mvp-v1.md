# Runova MVP rules — version 1

These values are initial field-test defaults, not permanent balance promises.
Each processed run stores the rules version used to calculate its result.

## Territory

- H3 resolution: 10, configurable on the server.
- New territory power: 100.
- Territory power range: 0–100.
- Decay is evaluated lazily from `power_updated_at`; no hourly full-table job.
- A validated traversal of a neutral cell captures it.
- An owner's validated traversal restores power.
- An opponent's validated traversal reduces power.
- Transfer occurs only after a server transaction reduces effective power to zero.

## Scoring separation

- Fitness XP is permanent progression from legitimate physical activity.
- Territory Power belongs to a cell and can decay.
- Competitive Score is awarded only to verified runs.

## Trust status

- `VERIFIED`: eligible for territory, XP, and competitive score.
- `CASUAL_VALID`: eligible for fitness history and reduced/noncompetitive rewards.
- `SUSPICIOUS`: recorded for the user but grants no competitive reward.

The final trust score is composed from GPS continuity, accuracy, speed and jump
checks, route plausibility, activity recognition, motion summaries, and device
signals. A single anomaly does not ban an account.

## Offline conflicts

Run start is anchored by a server-issued session identifier and timestamp. GPS
samples use monotonic offsets, upload batches have stable identifiers, and
territory changes are applied exactly once. Client wall-clock time alone never
decides ownership.

