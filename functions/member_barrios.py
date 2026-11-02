"""Where a sign-up can meet from: casa (`barrio`) and, optionally, trabajo (`workBarrio`), each
maybe with its neighbouring barrios (`ronda_solver.anchors`, docs/GLOSSARY.md Anchor).

Every server path that seats, offers or counts a sign-up by barrio reads it here: the solver's
input, the bench, the admin's add-to-ronda, the waiting lists and Cerca tuyo. Only known barrios
count. A profile saved before trabajo existed reads as casa alone, without its neighbours.
Trabajo is never written anywhere another member or the public reads.

Each function imports the solver package when called, and with it OR-Tools, as bench.py does:
only a path that measures a walk pays for it.
"""


def anchors(user: dict) -> tuple:
    """The user's anchors in known barrios, casa first, then trabajo; none when casa is unknown,
    as for a profile that was never saved."""
    from ronda_solver.anchors import anchors_of
    from ronda_solver.barrios import CENTROIDS

    return anchors_of(user, CENTROIDS) if user.get("barrio") in CENTROIDS else ()


def barrios(user: dict) -> list[str]:
    """The barrios of the user's anchors, casa first."""
    return [anchor.barrio for anchor in anchors(user)]


def _blocks(from_barrio: str, to_barrio: str) -> float:
    from ronda_solver.barrios import CENTROIDS
    from ronda_solver.geo import blocks_between

    return blocks_between(CENTROIDS[from_barrio], CENTROIDS[to_barrio])


def nearest_blocks(user: dict, seat_barrio: str) -> float | None:
    """The shortest walk from any of the user's anchors to `seat_barrio`; `None` when the seat's
    barrio or every anchor is unknown."""
    from ronda_solver.anchors import nearest_blocks as nearest
    from ronda_solver.barrios import CENTROIDS

    if seat_barrio not in CENTROIDS:
        return None
    return nearest(anchors(user), seat_barrio, _blocks)


def reaches(user: dict, seat_barrio: str) -> bool:
    """Whether a ronda in `seat_barrio` is within the walk of one of the user's anchors, as the
    solver's `withinTenBlocks` decides it."""
    from ronda_solver.anchors import within_reach
    from ronda_solver.barrios import CENTROIDS

    return seat_barrio in CENTROIDS and within_reach(anchors(user), seat_barrio, _blocks)
