from app.modules.runs.route_math import RoutePoint, haversine_meters, route_distance_meters
from app.modules.runs.trust import evaluate_gps_trust


def point(lat: float, lng: float, time_ms: int, accuracy: float = 5) -> RoutePoint:
    return RoutePoint(lat, lng, time_ms, accuracy)


def test_haversine_distance_is_reasonable() -> None:
    distance = haversine_meters(
        point(12.8231, 80.0442, 0),
        point(12.8240, 80.0442, 60_000),
    )

    assert 99 < distance < 101


def test_route_distance_ignores_unusable_accuracy() -> None:
    route = [
        point(12.8231, 80.0442, 0),
        point(13.8231, 80.0442, 1_000, accuracy=100),
        point(12.8240, 80.0442, 60_000),
    ]

    assert 99 < route_distance_meters(route) < 101


def test_trust_flags_clear_teleport() -> None:
    result = evaluate_gps_trust(
        [
            point(12.8231, 80.0442, 0),
            point(12.9231, 80.0442, 1_000),
        ]
    )

    assert result.score < 80
    assert "GPS_TELEPORT" in result.reason_codes

