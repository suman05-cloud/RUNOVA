from dataclasses import dataclass
from math import asin, cos, radians, sin, sqrt

EARTH_RADIUS_METERS = 6_371_008.8


@dataclass(frozen=True, slots=True)
class RoutePoint:
    latitude: float
    longitude: float
    monotonic_ms: int
    accuracy_meters: float


def haversine_meters(first: RoutePoint, second: RoutePoint) -> float:
    """Return great-circle distance between two WGS84-like GPS samples."""
    lat1 = radians(first.latitude)
    lat2 = radians(second.latitude)
    delta_lat = lat2 - lat1
    delta_lng = radians(second.longitude - first.longitude)
    haversine = sin(delta_lat / 2) ** 2 + cos(lat1) * cos(lat2) * sin(delta_lng / 2) ** 2
    return 2 * EARTH_RADIUS_METERS * asin(sqrt(haversine))


def route_distance_meters(points: list[RoutePoint], max_accuracy_meters: float = 50) -> float:
    """Calculate distance from ordered samples with unusable fixes excluded."""
    accepted = [point for point in points if point.accuracy_meters <= max_accuracy_meters]
    return sum(
        haversine_meters(previous, current)
        for previous, current in zip(accepted, accepted[1:], strict=False)
        if current.monotonic_ms > previous.monotonic_ms
    )


def segment_speed_mps(first: RoutePoint, second: RoutePoint) -> float | None:
    elapsed_seconds = (second.monotonic_ms - first.monotonic_ms) / 1000
    if elapsed_seconds <= 0:
        return None
    return haversine_meters(first, second) / elapsed_seconds

