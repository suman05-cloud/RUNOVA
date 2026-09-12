"""Free-form territory polygons; preserve legacy ownership and task history."""
from alembic import op
import sqlalchemy as sa
from geoalchemy2 import Geometry
import h3

revision = "c8301f04b002"
down_revision = "b7210d92a001"
branch_labels = None
depends_on = None


def upgrade():
    op.add_column("territories", sa.Column("geometry", Geometry(
        "MULTIPOLYGON", srid=4326, spatial_index=False), nullable=True))
    op.create_index("ix_territories_geometry_gist", "territories", ["geometry"],
                    postgresql_using="gist")
    op.alter_column("territories", "reward_points", type_=sa.Numeric(14, 2),
                    existing_type=sa.Integer(), existing_nullable=False)
    connection = op.get_bind()
    rows = connection.execute(sa.text("SELECT cell_id FROM territories "
        "WHERE owner_id IS NOT NULL OR released_at IS NOT NULL")).all()
    for (cell,) in rows:
        boundary = list(h3.cell_to_boundary(cell))
        boundary.append(boundary[0])
        ring = ",".join(f"{lng} {lat}" for lat, lng in boundary)
        connection.execute(sa.text("UPDATE territories SET geometry = "
            "ST_Multi(ST_GeomFromText(:wkt,4326)) WHERE cell_id=:cell"),
            {"wkt": f"POLYGON(({ring}))", "cell": cell})


def downgrade():
    # Free-form captures cannot be represented faithfully by the legacy H3 game.
    raise RuntimeError("Restore a pre-migration backup to return to the grid game.")
