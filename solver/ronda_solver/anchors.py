"""The barrios a neighbour meets from: casa and, optionally, trabajo (docs/GLOSSARY.md, Anchor).

A profile names casa in `barrio` and may name trabajo in `workBarrio`; each may reach its
neighbouring barrios too (`barrioNeighbours`, `workBarrioNeighbours`). A profile saved before
trabajo existed has only `barrio`, which reads as casa without its neighbours: the walk it
always had. The solver's input and `users/{uid}` use the same keys, so both read them here.

Ronda is "a few blocks from home": trabajo is a second anchor, not a city-wide radius, so there
are never more than two (`MAX_ANCHORS`), and nobody else ever learns which one is trabajo.
"""

from collections.abc import Callable, Iterable
from dataclasses import dataclass

from ronda_solver.rules import max_walk_blocks

NEIGHBOURS_REACH = 1.5
"""With "también barrios vecinos" an anchor reaches 1.5 times the walk (15 blocks in the Costa,
22.5 in Montevideo, between centroids): the owner's choice (2026-11-01), since every barrio
already reaches those within the walk."""

MAX_ANCHORS = 2
"""Casa and trabajo."""

HOME, HOME_NEIGHBOURS = "barrio", "barrioNeighbours"
WORK, WORK_NEIGHBOURS = "workBarrio", "workBarrioNeighbours"


@dataclass(frozen=True)
class Anchor:
    barrio: str
    neighbours: bool = False

    def reach(self, seat_barrio: str) -> float:
        """The farthest walk from this anchor to a ronda in `seat_barrio`."""
        return max_walk_blocks(seat_barrio) * (NEIGHBOURS_REACH if self.neighbours else 1)


def anchors_of(profile: dict, known: Iterable[str] | None = None) -> tuple[Anchor, ...]:
    """Casa, then trabajo when it is set and differs from casa. With `known`, an anchor in a
    barrio outside it is left out (a profile whose casa is unknown has no anchors)."""
    known = None if known is None else set(known)
    found = []
    for barrio_key, neighbours_key in ((HOME, HOME_NEIGHBOURS), (WORK, WORK_NEIGHBOURS)):
        barrio = profile.get(barrio_key)
        if not isinstance(barrio, str) or not barrio:
            continue
        if known is not None and barrio not in known:
            continue
        if any(anchor.barrio == barrio for anchor in found):
            continue
        found.append(Anchor(barrio, profile.get(neighbours_key) is True))
    return tuple(found[:MAX_ANCHORS])


def nearest_blocks(
    anchors: Iterable[Anchor], seat_barrio: str, blocks: Callable[[str, str], float]
) -> float | None:
    """The shortest walk from any anchor to `seat_barrio`; `None` without anchors."""
    return min((blocks(anchor.barrio, seat_barrio) for anchor in anchors), default=None)


def within_reach(
    anchors: Iterable[Anchor], seat_barrio: str, blocks: Callable[[str, str], float]
) -> bool:
    """Whether some anchor reaches a ronda in `seat_barrio`."""
    return any(
        blocks(anchor.barrio, seat_barrio) <= anchor.reach(seat_barrio) for anchor in anchors
    )
