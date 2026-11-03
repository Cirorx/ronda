"""The free places near a barrio, from the OpenStreetMap cache (docs/PRODUCT.md § Algo chico
esta semana).

`osm_places/{id}` is written by `scripts/osm_places.py` (Overpass, ODbL, credited in the
README) and read by the server only: `{name, kind, lat, lng, openingHours?}` with `kind` one of
`KINDS`. The name carries its article ("la Plaza de los Aromos"), as the sentences need it.
Distance is measured from the member's barrio centroid, in blocks, as the solver measures a
walk: the phone sends nothing about what makes walking hard, so everyone gets the places within
`MAX_BLOCKS`, ten blocks. Invented `demo-` places count only where invented sign-ups do
(`demo_users`). A name that reads as a home, an address, an emoji or money is dropped
(`organiser.gates.check_words`).
"""

from dataclasses import dataclass, field

import demo_users
from organiser import gates
from proposals import BARRIOS
from ronda_solver.geo import blocks_between

COLLECTION = "osm_places"
PARK = "park"
PROMENADE = "promenade"
LIBRARY = "library"
MARKETPLACE = "marketplace"
KINDS = (PARK, PROMENADE, LIBRARY, MARKETPLACE)
MAX_BLOCKS = 10


@dataclass(frozen=True)
class Place:
    """A free public place and how far it is from the member's barrio."""

    id: str
    name: str
    kind: str
    blocks: int
    hours: str | None
    lat: float = field(default=0.0, compare=False)
    lng: float = field(default=0.0, compare=False)


def nearby(db, barrio: object) -> list[Place]:
    """The cached places within `MAX_BLOCKS` of `barrio`, nearest first; none for a barrio the
    app doesn't know."""
    centroid = BARRIOS.get(barrio) if isinstance(barrio, str) else None
    if centroid is None:
        return []
    return near(db, (centroid["lat"], centroid["lng"]))


def near(db, here: tuple[float, float]) -> list[Place]:
    """The cached places within `MAX_BLOCKS` of the point `here`, nearest first."""
    found = []
    for snapshot in db.collection(COLLECTION).stream():
        place = _place(snapshot.id, snapshot.to_dict() or {}, here)
        if place is not None and place.blocks <= MAX_BLOCKS:
            found.append(place)
    return sorted(found, key=lambda place: (place.blocks, place.id))


def _place(place_id: str, fields: dict, here: tuple[float, float]) -> Place | None:
    name, kind = fields.get("name"), fields.get("kind")
    lat, lng = fields.get("lat"), fields.get("lng")
    if not isinstance(name, str) or kind not in KINDS:
        return None
    if not isinstance(lat, int | float) or not isinstance(lng, int | float):
        return None
    if demo_users.is_demo_uid(place_id) and not demo_users.demo_counts_here():
        return None
    if not gates.check_words(name).allowed:
        return None
    hours = fields.get("openingHours")
    return Place(
        id=place_id,
        name=name,
        kind=kind,
        blocks=round(blocks_between(here, (lat, lng))),
        hours=hours if isinstance(hours, str) else None,
        lat=float(lat),
        lng=float(lng),
    )
