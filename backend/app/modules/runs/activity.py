from dataclasses import dataclass
from statistics import fmean


@dataclass(frozen=True, slots=True)
class ActivityResult:
    activity_type: str
    confidence: int
    signals: dict[str, float]


def classify_activity(
    speeds_mps: list[float], sensor_features: list[dict[str, object]]
) -> ActivityResult:
    """Classify activity from independent GPS and motion features."""
    average_speed = fmean(speeds_mps) if speeds_mps else 0
    moving_speeds = [speed for speed in speeds_mps if speed > 0.5]
    moving_speed = fmean(moving_speeds) if moving_speeds else 0

    variances = _numeric_values(sensor_features, "acceleration_variance")
    cadences = _numeric_values(sensor_features, "cadence_hz")
    jerks = _numeric_values(sensor_features, "mean_jerk")
    acceleration_variance = fmean(variances) if variances else 0
    cadence_hz = fmean(cadences) if cadences else 0
    mean_jerk = fmean(jerks) if jerks else 0

    signals = {
        "average_speed_mps": round(average_speed, 2),
        "moving_speed_mps": round(moving_speed, 2),
        "acceleration_variance": round(acceleration_variance, 3),
        "cadence_hz": round(cadence_hz, 2),
        "mean_jerk": round(mean_jerk, 3),
    }

    if moving_speed < 0.5 and acceleration_variance < 0.12:
        return ActivityResult("STATIONARY", 90, signals)
    if moving_speed > 8 and cadence_hz < 0.8 and acceleration_variance < 1.2:
        return ActivityResult("CAR", 88, signals)
    if 3 <= moving_speed <= 15 and cadence_hz < 1.3 and acceleration_variance < 1.8:
        return ActivityResult("CYCLING", 76, signals)
    if 1.7 <= moving_speed <= 8 and (
        1.4 <= cadence_hz <= 4.5 or acceleration_variance >= 0.8 or mean_jerk >= 0.9
    ):
        return ActivityResult("RUNNING", 82 if cadences else 68, signals)
    if 0.5 <= moving_speed <= 3 and (
        0.6 <= cadence_hz <= 2.8 or acceleration_variance >= 0.15
    ):
        return ActivityResult("WALKING", 78 if cadences else 64, signals)
    return ActivityResult("UNKNOWN", 35, signals)


def _numeric_values(features: list[dict[str, object]], key: str) -> list[float]:
    values: list[float] = []
    for feature_set in features:
        value = feature_set.get(key)
        if isinstance(value, int | float):
            values.append(float(value))
    return values

