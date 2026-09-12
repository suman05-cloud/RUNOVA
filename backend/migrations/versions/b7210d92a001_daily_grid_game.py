"""Daily loop capture, inactivity release, and region profiles."""

from alembic import op
import sqlalchemy as sa

revision = "b7210d92a001"
down_revision = "e826ad1abc4b"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("profiles", sa.Column("state_region", sa.String(100)))
    op.create_index("ix_profiles_state_region", "profiles", ["state_region"])
    op.add_column(
        "territories",
        sa.Column("reward_points", sa.Integer(), nullable=False, server_default="100"),
    )
    op.add_column("territories", sa.Column("released_at", sa.DateTime(timezone=True)))
    op.create_table(
        "daily_capture_tasks",
        sa.Column("id", sa.UUID(), primary_key=True),
        sa.Column("user_id", sa.UUID(), sa.ForeignKey("profiles.id"), nullable=False),
        sa.Column("task_date", sa.Date(), nullable=False),
        sa.Column("cell_id", sa.String(16), sa.ForeignKey("territories.cell_id"), nullable=False),
        sa.Column("origin_lat", sa.Float(), nullable=False),
        sa.Column("origin_lng", sa.Float(), nullable=False),
        sa.Column("distance_meters", sa.Float(), nullable=False),
        sa.Column("reward_points", sa.Integer(), nullable=False),
        sa.Column(
            "assigned_at", sa.DateTime(timezone=True), nullable=False, server_default=sa.func.now()
        ),
        sa.Column("expires_at", sa.DateTime(timezone=True), nullable=False),
        sa.Column("completed_at", sa.DateTime(timezone=True)),
        sa.Column("run_id", sa.UUID(), sa.ForeignKey("runs.id")),
        sa.UniqueConstraint("user_id", "task_date", name="daily_task_user_date"),
    )
    op.create_index("ix_daily_capture_tasks_user_id", "daily_capture_tasks", ["user_id"])
    op.create_index("ix_daily_capture_tasks_cell_id", "daily_capture_tasks", ["cell_id"])


def downgrade():
    op.drop_table("daily_capture_tasks")
    op.drop_column("territories", "released_at")
    op.drop_column("territories", "reward_points")
    op.drop_index("ix_profiles_state_region", table_name="profiles")
    op.drop_column("profiles", "state_region")
