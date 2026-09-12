# Map demo accounts

These are synthetic local-development fixtures, not real outdoor activities.
`test1` is not changed. Seeded land is near the map's default SRM/Potheri view,
center **12.8231, 80.0442**. The rectangles are visual test shapes, not recommended
walking routes; use public paths only for real-world testing.

| Username | Direct-login email | Initial scenario | Territory points |
| --- | --- | --- | --- |
| test2 | test2@runova.example.com | Owns the northwest rectangle | 144.12 |
| test3 | test3@runova.example.com | Owns northeast and recaptured southwest at 2× | 490.01 |
| test4 | test4@runova.example.com | Inactive for 52 hours; lost the southern area | 0 |

The southeast rectangle remains yellow, ready for partial recapture. As test1,
you see three red areas plus one yellow area. As test2/test3, your own areas are
green. Test4's fitness XP remains after its territory points are lost.

No passwords or OTP are required by the current development login. Use the email
and matching username above. Keep test1 signed in to test recapturing the yellow
portion yourself. Do not log out during an active run.

Four completed **DEMO** walks contain 61 hardcoded GPS samples each and synthetic
motion summaries. They use `map-demo-v1` as their rules version and a device model
of `Synthetic map demo`; they are not labeled verified real activity. Fitness XP
is fixture data too: test2=120, test3=240, test4=150.

The active owners expire normally after 48 hours without activity. The seed does
not freeze ownership, keep fake users active, or restore land somebody recaptures.

## Seed script

From `E:\RUNOVA\backend`:

```powershell
..\.venv\Scripts\python.exe -m app.seed_map_demo          # dry run
..\.venv\Scripts\python.exe -m app.seed_map_demo --apply  # save once
```

Only local development databases are accepted. The script refuses conflicting
usernames, emails, or overlapping existing territory; it never overwrites them.
Stable fixture IDs make reruns no-ops once the demo exists. No data is deleted.
