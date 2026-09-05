from dataclasses import dataclass
from statistics import fmean

from app.modules.runs.route_math import RoutePoint, segment_speed_mps


@dataclass(frozen=True, slots=True)
class GpsTrustResult:
    score: int
    reason_codes: tuple[str, ...]
    metrics: dict[str, float | int]


def evaluate_gps_trust(points: list[RoutePoint]) -> GpsTrustResult:
    """Produce an explainable GPS component score; it is not the final run verdict."""
    if len(points) < 2:
        return GpsTrustResult(
            score=0,
            reason_codes=("INSUFFICIENT_GPS_POINTS",),
            metrics={"point_count": len(points)},
        )

    score = 100
    reasons: list[str] = []
    accuracies = [point.accuracy_meters for point in points]
    poor_accuracy_ratio = sum(accuracy > 35 for accuracy in accuracies) / len(accuracies)

    speeds: list[float] = []
    non_monotonic_segments = 0
    vehicle_speed_segments = 0
    teleport_segments = 0

    for previous, current in zip(points, points[1:], strict=False):
        speed = segment_speed_mps(previous, current)
        if speed is None:
            non_monotonic_segments += 1
            continue
        speeds.append(speed)

        combined_accuracy = max(previous.accuracy_meters, current.accuracy_meters)
        if speed > 12 and combined_accuracy <= 25:
            vehicle_speed_segments += 1
        if speed > 25 and combined_accuracy <= 50:
            teleport_segments += 1

    if poor_accuracy_ratio > 0.5:
        score -= 20
        reasons.append("PERSISTENT_POOR_ACCURACY")
    elif poor_accuracy_ratio > 0.2:
        score -= 8
        reasons.append("INTERMITTENT_POOR_ACCURACY")

    if non_monotonic_segments:
        score -= min(30, non_monotonic_segments * 10)
        reasons.append("NON_MONOTONIC_TIMESTAMPS")
    if vehicle_speed_segments:
        score -= min(35, vehicle_speed_segments * 7)
        reasons.append("VEHICLE_LIKE_SPEED")
    if teleport_segments:
        score -= min(60, teleport_segments * 20)
        reasons.append("GPS_TELEPORT")

    return GpsTrustResult(
        score=max(0, min(100, score)),
        reason_codes=tuple(reasons),
        metrics={
            "point_count": len(points),
            "mean_accuracy_meters": round(fmean(accuracies), 2),
            "max_segment_speed_mps": round(max(speeds, default=0), 2),
            "non_monotonic_segments": non_monotonic_segments,
            "vehicle_speed_segments": vehicle_speed_segments,
            "teleport_segments": teleport_segments,
        },
    )

