"""Validate a near-closed GPS loop; spatial topology is checked by PostGIS."""

from app.modules.runs.route_math import RoutePoint, haversine_meters, route_distance_meters


def loop_wkt(points: list[RoutePoint]) -> str | None:
    if not 8 <= len(points) <= 5000 or any(p.accuracy_meters > 35 for p in points):
        return None
    distance = route_distance_meters(points)
    gap = haversine_meters(points[0], points[-1])
    # At least 90% physically completed, with a 100m maximum closing shortcut.
    if distance < 100 or gap > min(100, distance / 9):
        return None
    if any(abs(p.latitude) > 85 for p in points):
        return None
    if max(p.longitude for p in points) - min(p.longitude for p in points) > 180:
        return None  # Do not create a world-spanning polygon across the date line.
    for a, b in zip(points, points[1:], strict=False):
        seconds = (b.monotonic_ms - a.monotonic_ms) / 1000
        if not 0 < seconds <= 30 or haversine_meters(a, b) / seconds > 7:
            return None
    ring = [(p.longitude, p.latitude) for p in points]
    if ring[-1] != ring[0]:
        ring.append(ring[0])
    return "POLYGON((" + ",".join(f"{lng} {lat}" for lng, lat in ring) + "))"
