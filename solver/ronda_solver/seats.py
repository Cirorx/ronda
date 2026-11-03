"""The seat catalogue: every place a ronda can form, published as `seat_facts/{barrio}_{pretext}`
for the phone's needs filter (docs/ARCHITECTURE.md § Data model).

One document per barrio and pretext holds what doesn't change with the day: the walk from each
barrio of its area (Ciudad de la Costa or Montevideo) to it, and whether the place asks for stairs
or a car. The phone expands each one into a seat per slot, `{barrio}_{pretext}_{slot}`, so every
day and time a member picks has seats; evening seats end after dark. A document with a `slot`
is one seat whose place a host set, and it replaces its expanded twin.

Nothing here is demo data: the walks come from the barrio points in `barrios.py`. The functions
publish it (functions/seat_catalog.py) and the demo seed writes the same documents.
"""

import hashlib
import json
from itertools import product

from ronda_solver.barrios import COSTA_BARRIOS
from ronda_solver.geo import blocks_between
from ronda_solver.montevideo import MONTEVIDEO_BARRIOS

PRETEXTS = ("mate", "truco", "futbol5", "caminata", "conga", "merienda", "pajaros")
"""Every pretext the app offers (its `Pretext` enum), in the app's order."""

AREAS = tuple(
    {barrio: (lat, lng) for barrio, (_, lat, lng) in table.items()}
    for table in (COSTA_BARRIOS, MONTEVIDEO_BARRIOS)
)
"""Ciudad de la Costa's and Montevideo's points: a seat's walk table lists its own area's barrios,
so a barrio of the other area reads as too far on the phone."""


def catalogue() -> dict[str, dict]:
    """`seat_facts/{barrio}_{pretext}` for every barrio × pretext, by document id. `blocksFrom` is
    the straight-line walk in blocks from each barrio point of the area, rounded to 0.1. No host has
    set a place yet, so no stairs and no car."""
    return {
        f"{barrio}_{pretext}": {
            "barrio": barrio,
            "pretext": pretext,
            "blocksFrom": {
                origin: round(blocks_between(point, area[barrio]), 1)
                for origin, point in area.items()
            },
            "hasStairs": False,
            "needsCar": False,
        }
        for area in AREAS
        for barrio, pretext in product(area, PRETEXTS)
    }


def version(documents: dict[str, dict]) -> str:
    """A short fingerprint of `documents`: it changes whenever any seat does, so a phone knows to
    work out its eligible seats again."""
    canonical = json.dumps(documents, sort_keys=True, separators=(",", ":"))
    return hashlib.sha256(canonical.encode()).hexdigest()[:16]
