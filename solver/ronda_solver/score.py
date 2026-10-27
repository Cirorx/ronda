"""Scores proposals against the soft rules, from the groups alone (no solver state)."""

from collections import Counter

from ronda_solver.problem import Candidate, Problem
from ronda_solver.rules import (
    NEAR_BLOCKS,
    SEAT_REWARD,
    TRUCO_OLD,
    TRUCO_PRETEXT,
    TRUCO_YOUNG,
    SoftRule,
    age_group,
    size_rule,
)


def ronda_units(problem: Problem, candidate: Candidate, uids: list[str]) -> dict[SoftRule, int]:
    """How much a ronda breaks each soft rule, in the units its weight is priced in."""
    people = [problem.person(uid) for uid in uids]
    members = set(uids)
    groups = Counter(age_group(p.age_band) for p in people)
    pairs = problem.plus_one_pairs
    young, old = groups[TRUCO_YOUNG], groups[TRUCO_OLD]
    return {
        SoftRule.TWO_PER_AGE_BAND: sum(n == 1 for n in groups.values()),
        SoftRule.SIZE_FOR_PRETEXT: max(0, size_rule(candidate.pretext).target - len(uids)),
        SoftRule.PLUS_ONE_TOGETHER: sum(len(members & {a, b}) == 1 for a, b in pairs),
        SoftRule.ONE_PLUS_ONE_PAIR: max(0, sum({a, b} <= members for a, b in pairs) - 1),
        SoftRule.TRUCO_CROSS_AGE: max(0, young - old) if candidate.pretext == TRUCO_PRETEXT else 0,
        SoftRule.NEARBY_FIRST: sum(problem.walk(p, candidate) for p in people),
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
    seated = 0
    units = Counter({rule: 0 for rule in SoftRule})
    for ronda in proposals:
        candidate = Candidate(ronda["barrio"], ronda["pretext"], ronda["slot"])
        uids = [m["uid"] for m in ronda["members"]]
        seated += len(uids)
        units.update(ronda_units(problem, candidate, uids))
    objective = SEAT_REWARD * seated - sum(problem.weights[r] * n for r, n in units.items())
    return {
        "seated": seated,
        "units": {str(r): n for r, n in units.items()},
        "objective": objective,
    }
