from datetime import UTC, datetime, timedelta

import h3

from app.modules.territories.h3_grid import cell_boundary, cell_for_coordinate
from app.modules.territories.rules import effective_power


def test_lazy_decay_removes_ten_power_per_day() -> None:
    captured_at = datetime(2026, 9, 1, tzinfo=UTC)

    assert effective_power(100, captured_at, captured_at + timedelta(days=1)) == 90
    assert effective_power(100, captured_at, captured_at + timedelta(days=20)) == 0


def test_coordinate_converts_to_resolution_ten_cell() -> None:
    cell = cell_for_coordinate(12.8231, 80.0442)

    assert h3.get_resolution(cell) == 10
    assert len(cell_boundary(cell)) in {5, 6}

