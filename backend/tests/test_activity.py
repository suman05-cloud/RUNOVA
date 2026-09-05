from app.modules.progression.service import calculate_run_xp, level_for_xp
from app.modules.runs.activity import classify_activity


def test_running_activity_uses_gps_and_accelerometer_signals() -> None:
    result = classify_activity(
        [2.8, 3.1, 3.0],
        [{"acceleration_variance": 1.1, "cadence_hz": 2.4, "mean_jerk": 1.0}],
    )
    assert result.activity_type == "RUNNING"
    assert result.confidence >= 80


def test_vehicle_activity_does_not_look_like_running() -> None:
    result = classify_activity(
        [11.0, 12.0, 10.5],
        [{"acceleration_variance": 0.2, "cadence_hz": 0.1, "mean_jerk": 0.2}],
    )
    assert result.activity_type == "CAR"


def test_xp_and_level_curve() -> None:
    assert calculate_run_xp(1000, 2) == 20
    assert level_for_xp(0) == 1
    assert level_for_xp(500) == 2
    assert level_for_xp(2000) == 3
