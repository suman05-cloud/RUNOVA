"""add run evaluation fields

Revision ID: e826ad1abc4b
Revises: 59d301910f5e
Create Date: 2026-09-05
"""

from collections.abc import Sequence

import sqlalchemy as sa
from alembic import op

revision: str = "e826ad1abc4b"
down_revision: str | None = "59d301910f5e"
branch_labels: str | Sequence[str] | None = None
depends_on: str | Sequence[str] | None = None


def upgrade() -> None:
    op.add_column("run_gps_points", sa.Column("latitude", sa.Float(), nullable=True))
    op.add_column("run_gps_points", sa.Column("longitude", sa.Float(), nullable=True))
    op.add_column("runs", sa.Column("activity_type", sa.String(length=20), nullable=True))
    op.add_column("runs", sa.Column("activity_confidence", sa.Integer(), nullable=True))
    op.add_column(
        "runs",
        sa.Column(
            "road_match_status",
            sa.String(length=20),
            server_default="NOT_CHECKED",
            nullable=False,
        ),
    )
    op.add_column("runs", sa.Column("road_match_confidence", sa.Numeric(5, 2), nullable=True))
    op.add_column(
        "runs", sa.Column("territories_changed", sa.Integer(), server_default="0", nullable=False)
    )
    op.add_column(
        "runs", sa.Column("xp_earned", sa.Integer(), server_default="0", nullable=False)
    )
    op.add_column(
        "runs", sa.Column("competitive_score", sa.Integer(), server_default="0", nullable=False)
    )
    op.execute(
        """
        UPDATE run_gps_points
        SET latitude = ST_Y(position), longitude = ST_X(position)
        WHERE latitude IS NULL OR longitude IS NULL
        """
    )
    op.alter_column("run_gps_points", "latitude", nullable=False)
    op.alter_column("run_gps_points", "longitude", nullable=False)


def downgrade() -> None:
    op.drop_column("runs", "competitive_score")
    op.drop_column("runs", "xp_earned")
    op.drop_column("runs", "territories_changed")
    op.drop_column("runs", "road_match_confidence")
    op.drop_column("runs", "road_match_status")
    op.drop_column("runs", "activity_confidence")
    op.drop_column("runs", "activity_type")
    op.drop_column("run_gps_points", "longitude")
    op.drop_column("run_gps_points", "latitude")
