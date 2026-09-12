# Free-loop area capture (free-loop-v3)

There are no daily tasks, predefined grid overlays, locked land, or task-size tiers.
Walk or run a route of your choice, finishing near where you started. The server
uses the actual enclosed polygon, not H3 tiles, to calculate ownership.

## Capture and colors

- An eligible loop must be at least 90% traversed: the start/end gap is at most
  one ninth of recorded distance (10% of recorded distance plus the closing gap),
  capped at 100 metres. Exact GPS closure is not required; either direction works.
- Validation requires at least 8 GPS samples, accuracy within 35 m, gaps no longer
  than 30 seconds, no segment above 7 m/s, and a verified walk/run covering at
  least 100 m and 60 seconds. Rejected geometry does not capture land.
- Self-intersecting/zero-area routes, date-line crossings, and shapes outside
  100 m²–25 km² are not accepted. No convex hull is substituted for the real route.
- Green is land you own. Red is another player's active territory. Neither can
  award additional territory points just by running through or enclosing it.
  Normal fitness XP can still be earned from qualifying exercise there.
- Land without an overlay is unclaimed. Its enclosed portion earns normal points:
  **1 point per 100 m²**, stored to two decimal places.
- After **48 hours** without a qualifying verified walk/run, all your territories
  become yellow and their points stop counting for you. Any qualifying activity,
  anywhere, protects all currently owned land; no territory-specific maintenance.
- Anyone can loop around **any portion** of yellow land. The actual intersection
  becomes theirs and earns **2 points per 100 m²**. The remainder stays yellow.
  The multiplier is always 2× normal area value, never 2× a previous bonus.
- A mixed loop clips out occupied land, rewards fresh land at 1× and yellow land
  at 2×. Polygon holes and disconnected remainders are preserved on the map.
- Rankings reflect current ownership points (including its capture multiplier),
  not lifetime capture totals. Fitness XP/levels remain separate and are retained.

## Data and offline behavior

Migration `c8301f04b002` preserves existing captured/open H3 areas as polygons and
keeps old task/event rows for history. Unclaimed old task grids are hidden and no
longer reserve anything. The task API is removed. New territory identifiers are
opaque values; the legacy API field name `cell_id` is retained for compatibility.

Expiry runs before map/progression/ranking/capture responses; the map refreshes
every minute while mounted. No separate expiry worker is required for the local
MVP. Offline activity predating a yellow area's release cannot recapture it, and
activity over 48 hours old cannot gain territory. Retry protection prevents
duplicate capture rewards. Game writes serialize within PostgreSQL transactions.

## Testing on the phone

Keep the API running and USB connected (or configure another reachable API URL).
Open Map: only owned/released areas should be tinted. Start Walk / run, follow a
safe loop on public paths, finish near the start, and upload. Refresh Map and check
Profile / Rankings. Another player sees your green area in red. After expiry,
loop around part of its yellow shape to recapture just that part at 2×.

GPS/motion checks are still MVP heuristics, not production-grade anti-spoofing.
There is no road-accessibility or restricted-land screening: never enter private,
airport, water, or restricted areas to capture land. Outdoor GPS/sensor testing is
still needed. Global/Country/State/City rankings use self-declared profile regions.
