from dataclasses import dataclass

import httpx

from app.core.config import get_settings
from app.modules.runs.route_math import RoutePoint


@dataclass(frozen=True, slots=True)
class RoadMatchResult:
    status: str
    confidence: float | None


async def match_route_to_roads(points: list[RoutePoint]) -> RoadMatchResult:
    settings = get_settings()
    if not settings.road_match_base_url:
        return RoadMatchResult("NOT_CONFIGURED", None)
    usable = points[:: max(1, len(points) // 100)][:100]
    if len(usable) < 2:
        return RoadMatchResult("INSUFFICIENT_POINTS", None)

    coordinates = ";".join(f"{point.longitude},{point.latitude}" for point in usable)
    url = (
        f"{settings.road_match_base_url.rstrip('/')}/match/v1/"
        f"{settings.road_match_profile}/{coordinates}"
    )
    try:
        async with httpx.AsyncClient(timeout=8) as client:
            response = await client.get(
                url,
                params={"overview": "false", "tidy": "true", "steps": "false"},
            )
            response.raise_for_status()
        payload = response.json()
        tracepoints = payload.get("tracepoints") or []
        matched = sum(point is not None for point in tracepoints)
        confidence = round(matched / len(tracepoints) * 100, 2) if tracepoints else 0
        return RoadMatchResult("MATCHED" if confidence >= 60 else "LOW_MATCH", confidence)
    except (httpx.HTTPError, ValueError, TypeError):
        return RoadMatchResult("UNAVAILABLE", None)

