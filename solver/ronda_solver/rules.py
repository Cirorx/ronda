"""Every rule the solver applies, each defined once and named by a literal."""

from __future__ import annotations

from dataclasses import dataclass, field
from enum import StrEnum
from typing import TYPE_CHECKING

if TYPE_CHECKING:  # pragma: no cover
    from ronda_solver.problem import Candidate, Person, Problem


@dataclass(frozen=True)
class Violation:
    """One place a grouping breaks a rule: the ronda (None for the whole grouping), who, how many
    units it costs (blocks, seats short, people) and what the copy needs to say it."""

    rule: str
    ronda_id: str | None
    uids: tuple[str, ...] = ()
    units: int = 1
    params: dict = field(default_factory=dict)

    def as_json(self) -> dict:
        return {"rondaId": self.ronda_id, "uids": list(self.uids), "params": self.params}


class HardRule(StrEnum):
    """Never broken. The checker names a violation by one of these literals."""

    ELIGIBLE_SEAT = "eligibleSeat"
    SAME_SLOT = "sameSlot"
    SAME_PRETEXT = "samePretext"
    WITHIN_TEN_BLOCKS = "withinTenBlocks"
    AVOID_PAIR_APART = "avoidPairApart"
    ONE_RONDA_EACH = "oneRondaEach"
    SIZE_BOUNDS = "sizeBounds"


def eligible_seat(problem: Problem, person: Person, candidate: Candidate) -> bool:
    """The phone sent this seat id: it passed the person's needs, which never leave the phone."""
    return candidate.id in person.eligible_seat_ids


def same_slot(problem: Problem, person: Person, candidate: Candidate) -> bool:
    return candidate.slot in person.slots


def same_pretext(problem: Problem, person: Person, candidate: Candidate) -> bool:
    return candidate.pretext in person.pretexts


MAX_WALK_BLOCKS = 10
NEAR_BLOCKS = 5
"""WalkDistance: near ≤ 5 blocks, medium ≤ 10, far beyond."""


def within_ten_blocks(problem: Problem, person: Person, candidate: Candidate) -> bool:
    """Measured between barrio centroids."""
    return problem.blocks(person.barrio, candidate.barrio) <= MAX_WALK_BLOCKS


SEAT_RULES = {
    HardRule.ELIGIBLE_SEAT: eligible_seat,
    HardRule.SAME_SLOT: same_slot,
    HardRule.SAME_PRETEXT: same_pretext,
    HardRule.WITHIN_TEN_BLOCKS: within_ten_blocks,
}
"""The hard rules that decide whether a person may take a seat in a candidate ronda."""


def broken_seat_rules(problem: Problem, person: Person, candidate: Candidate) -> list[HardRule]:
    return [rule for rule, allows in SEAT_RULES.items() if not allows(problem, person, candidate)]


@dataclass(frozen=True)
class SizeRule:
    """A ronda opens with floor..cap members (hard); each seat short of target costs (soft)."""

    floor: int
    target: int
    cap: int


SIZES = {
    "futbol5": SizeRule(floor=8, target=10, cap=10),
    "truco": SizeRule(floor=4, target=6, cap=6),
}
DEFAULT_SIZE = SizeRule(floor=4, target=5, cap=6)
"""A ronda at 3 is merged and one at 4 is refilled (docs/ARCHITECTURE.md § Solver), so 4 is the
smallest ronda the solver opens."""


def size_rule(pretext: str) -> SizeRule:
    return SIZES.get(pretext, DEFAULT_SIZE)


class SoftRule(StrEnum):
    """Weighted: the solver keeps these unless keeping one would leave someone without a seat."""

    TWO_PER_AGE_BAND = "twoPerAgeBand"
    SIZE_FOR_PRETEXT = "sizeForPretext"
    PLUS_ONE_TOGETHER = "plusOneTogether"
    ONE_PLUS_ONE_PAIR = "onePlusOnePair"
    TRUCO_CROSS_AGE = "trucoCrossAge"
    NEARBY_FIRST = "nearbyFirst"


FEWER_SEATED = "fewerSeated"
"""Not a rule: the reason a grouping gives when it seats fewer neighbours than the winner."""

SEAT_REWARD = 1000
"""Per seated neighbour. One person's penalties add up to at most 730 (one +1 pair each), so the
solver never leaves someone unseated to keep a soft rule."""

WEIGHTS = {
    SoftRule.TWO_PER_AGE_BAND: 120,  # per neighbour who is the only one of their age group
    SoftRule.SIZE_FOR_PRETEXT: 100,  # per seat short of the pretext's target
    SoftRule.PLUS_ONE_TOGETHER: 300,  # per ronda that holds one of a +1 pair without the other
    SoftRule.ONE_PLUS_ONE_PAIR: 200,  # per +1 pair beyond the first in a ronda
    SoftRule.TRUCO_CROSS_AGE: 60,  # per under-30 in a truco ronda without an over-60 partner
    SoftRule.NEARBY_FIRST: 5,  # per block walked to the ronda's barrio
}


UNDER_30 = "under30"
FROM_30_TO_59 = "30to59"
SIXTY_PLUS = "60plus"
AGE_GROUPS = {
    "18-29": UNDER_30,
    "30-39": FROM_30_TO_59,
    "40-49": FROM_30_TO_59,
    "50-59": FROM_30_TO_59,
    "60-69": SIXTY_PLUS,
    "70-79": SIXTY_PLUS,
    "80+": SIXTY_PLUS,
}
"""The age groups the soft rules compare. People pick a decade ("sesenta y pico"), but a ronda of
5 rarely holds two of every decade, and docs/PRODUCT.md's check reads "Hay al menos dos de 60 o
más"."""


def age_group(age_band: str) -> str:
    """A band outside AGE_GROUPS is its own group."""
    return AGE_GROUPS.get(age_band, age_band)


# SoftRule.TRUCO_CROSS_AGE (docs/PRODUCT.md § Truco): under-30 partnered with over-60 where both
# exist. The owner may revise or drop it (issue #9): edit these names, or set its weight to 0.
TRUCO_PRETEXT = "truco"
TRUCO_YOUNG = UNDER_30
TRUCO_OLD = SIXTY_PLUS
