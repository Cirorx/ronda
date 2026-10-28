"""Scores proposals against the soft rules, from the groups alone (no solver state).

One pure check per soft rule: (problem, candidate ronda, member uids) -> its violations, each
carrying the units its weight prices."""

from collections import Counter
from collections.abc import Callable

from ronda_solver.problem import Candidate, Problem
from ronda_solver.rules import (
    NEAR_BLOCKS,
    SEAT_REWARD,
    TRUCO_OLD,
    TRUCO_PRETEXT,
    TRUCO_YOUNG,
    SoftRule,
    Violation,
    age_group,
    size_rule,
)


def two_per_age_band(problem: Problem, candidate: Candidate, uids: list[str]) -> list[Violation]:
    """One per member who is the only one of their age group."""
    groups = {uid: age_group(problem.person(uid).age_band) for uid in uids}
    counts = Counter(groups.values())
    return [
        Violation(SoftRule.TWO_PER_AGE_BAND, candidate.id, (uid,), params={"ageGroup": group})
        for uid, group in groups.items()
        if counts[group] == 1
    ]


def size_for_pretext(problem: Problem, candidate: Candidate, uids: list[str]) -> list[Violation]:
    """One per ronda below its pretext's target, a unit per seat short."""
    size = size_rule(candidate.pretext)
    if len(uids) >= size.target:
        return []
    params = {"pretext": candidate.pretext, "members": len(uids), "target": size.target}
    return [
        Violation(
            SoftRule.SIZE_FOR_PRETEXT, candidate.id, units=size.target - len(uids), params=params
        )
    ]


def plus_one_together(problem: Problem, candidate: Candidate, uids: list[str]) -> list[Violation]:
    """One per +1 pair with one of the two in this ronda and the other elsewhere or unseated."""
    members = set(uids)
    return [
        Violation(SoftRule.PLUS_ONE_TOGETHER, candidate.id, (a, b))
        for a, b in problem.plus_one_pairs
        if len(members & {a, b}) == 1
    ]


def one_plus_one_pair(problem: Problem, candidate: Candidate, uids: list[str]) -> list[Violation]:
    """One per ronda holding more than one +1 pair, a unit per pair beyond the first."""
    members = set(uids)
    together = [(a, b) for a, b in problem.plus_one_pairs if {a, b} <= members]
    if len(together) < 2:
        return []
    return [
        Violation(
            SoftRule.ONE_PLUS_ONE_PAIR,
            candidate.id,
            tuple(uid for pair in together for uid in pair),
            units=len(together) - 1,
            params={"pairs": len(together)},
        )
    ]


def truco_cross_age(problem: Problem, candidate: Candidate, uids: list[str]) -> list[Violation]:
    """One per truco ronda with more under-30s than over-60s, a unit per partnerless under-30."""
    if candidate.pretext != TRUCO_PRETEXT:
        return []
    groups = {uid: age_group(problem.person(uid).age_band) for uid in uids}
    young = tuple(uid for uid, group in groups.items() if group == TRUCO_YOUNG)
    partnerless = len(young) - sum(group == TRUCO_OLD for group in groups.values())
    if partnerless <= 0:
        return []
    return [Violation(SoftRule.TRUCO_CROSS_AGE, candidate.id, young, units=partnerless)]


def nearby_first(problem: Problem, candidate: Candidate, uids: list[str]) -> list[Violation]:
    """One per member who walks to another barrio, a unit per block."""
    walks = {uid: problem.walk(problem.person(uid), candidate) for uid in uids}
    return [
        Violation(
            SoftRule.NEARBY_FIRST, candidate.id, (uid,), units=blocks, params={"blocks": blocks}
        )
        for uid, blocks in walks.items()
        if blocks > 0
    ]


SOFT_CHECKS: dict[SoftRule, Callable[[Problem, Candidate, list[str]], list[Violation]]] = {
    SoftRule.TWO_PER_AGE_BAND: two_per_age_band,
    SoftRule.SIZE_FOR_PRETEXT: size_for_pretext,
    SoftRule.PLUS_ONE_TOGETHER: plus_one_together,
    SoftRule.ONE_PLUS_ONE_PAIR: one_plus_one_pair,
    SoftRule.TRUCO_CROSS_AGE: truco_cross_age,
    SoftRule.NEARBY_FIRST: nearby_first,
}


def penalty(problem: Problem, violations: list[Violation]) -> int:
    """What the violations cost the objective: weight × units."""
    return sum(problem.weights[v.rule] * v.units for v in violations)


def _candidate(ronda: dict) -> Candidate:
    return Candidate(ronda["barrio"], ronda["pretext"], ronda["slot"])


def _uids(ronda: dict) -> list[str]:
    return [m["uid"] for m in ronda["members"]]


def soft_violations(problem: Problem, proposals: list[dict]) -> list[Violation]:
    """Every soft-rule violation in the proposals, rule by rule within each ronda."""
    return [
        violation
        for ronda in proposals
        for check in SOFT_CHECKS.values()
        for violation in check(problem, _candidate(ronda), _uids(ronda))
    ]


def ronda_units(problem: Problem, candidate: Candidate, uids: list[str]) -> dict[SoftRule, int]:
    """How much a ronda breaks each soft rule, in the units its weight is priced in."""
    return {
        rule: sum(v.units for v in check(problem, candidate, uids))
        for rule, check in SOFT_CHECKS.items()
    }


def ronda_checks(problem: Problem, candidate: Candidate, uids: list[str]) -> dict[str, bool]:
    """Which soft rules the ronda keeps, for the approval screen."""
    units = ronda_units(problem, candidate, uids)
    checks = {str(rule): n == 0 for rule, n in units.items()}
    checks[SoftRule.NEARBY_FIRST] = all(
        problem.walk(problem.person(uid), candidate) <= NEAR_BLOCKS for uid in uids
    )
    return checks


def score(problem: Problem, proposals: list[dict]) -> dict:
    """Seated count, soft-rule units and the objective the solver maximises, for any result."""
    violations = soft_violations(problem, proposals)
    units = Counter({rule: 0 for rule in SoftRule})
    for v in violations:
        units[v.rule] += v.units
    seated = sum(len(ronda["members"]) for ronda in proposals)
    return {
        "seated": seated,
        "units": {str(r): n for r, n in units.items()},
        "objective": SEAT_REWARD * seated - penalty(problem, violations),
    }
