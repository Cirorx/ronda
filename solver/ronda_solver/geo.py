"""Walking distance between barrio centroids, in blocks (cuadras)."""

from math import asin, cos, radians, sin, sqrt

EARTH_RADIUS_METRES = 6_371_000
BLOCK_METRES = 100
"""A cuadra in Ciudad de la Costa is about 100 m."""


def metres_between(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Great-circle (haversine) distance between two (lat, lng) points."""
    lat1, lng1, lat2, lng2 = map(radians, (*a, *b))
    h = sin((lat2 - lat1) / 2) ** 2 + cos(lat1) * cos(lat2) * sin((lng2 - lng1) / 2) ** 2
    return 2 * EARTH_RADIUS_METRES * asin(sqrt(h))


def blocks_between(a: tuple[float, float], b: tuple[float, float]) -> float:
    return metres_between(a, b) / BLOCK_METRES
