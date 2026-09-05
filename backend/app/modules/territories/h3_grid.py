import h3


def cell_for_coordinate(latitude: float, longitude: float, resolution: int = 10) -> str:
    if not -90 <= latitude <= 90:
        raise ValueError("latitude must be between -90 and 90")
    if not -180 <= longitude <= 180:
        raise ValueError("longitude must be between -180 and 180")
    if not 0 <= resolution <= 15:
        raise ValueError("H3 resolution must be between 0 and 15")
    return h3.latlng_to_cell(latitude, longitude, resolution)


def cell_boundary(cell_id: str) -> list[tuple[float, float]]:
    """Return GeoJSON coordinate order: longitude, latitude."""
    return [(longitude, latitude) for latitude, longitude in h3.cell_to_boundary(cell_id)]

