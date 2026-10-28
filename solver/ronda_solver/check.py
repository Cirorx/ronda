"""Checks a result against every hard rule, independently of how the model enforced them.

One pure check per hard rule (the four seat rules share one, over rules.SEAT_RULES); each returns
its violations with what the copy needs to say them."""

from collections import Counter

from ronda_solver.problem import Candidate, Problem, parse_problem
from ronda_solver.rules import HardRule, Violation, broken_seat_rules, size_rule


def seat_rules(problem: Problem, candidate: Candidate, uids: list[str]) -> list[Violation]:
    """eligibleSeat, sameSlot, samePretext, withinTenBlocks: one per member and broken rule. A
    member who is not in the input has no eligible seat."""
    violations = []
    for uid in uids:
        broken = (
            broken_seat_rules(problem, problem.person(uid), candidate)
            if problem.has_person(uid)
            else [HardRule.ELIGIBLE_SEAT]
        )
        violations += [Violation(rule, candidate.id, (uid,)) for rule in broken]
    return violations


def avoid_pair_apart(problem: Problem, candidate: Candidate, uids: list[str]) -> list[Violation]:
    """One per report-apart pair seated in this ronda."""
    return [
        Violation(HardRule.AVOID_PAIR_APART, candidate.id, (a, b))
        for a, b in problem.avoid_pairs
        if a in uids and b in uids
    ]


def size_bounds(problem: Problem, candidate: Candidate, uids: list[str]) -> list[Violation]:
    """One when the ronda has fewer members than its floor or more than its cap."""
    size = size_rule(candidate.pretext)
    if size.floor <= len(uids) <= size.cap:
        return []
    params = {
        "pretext": candidate.pretext,
        "members": len(uids),
        "floor": size.floor,
        "cap": size.cap,
    }
    return [Violation(HardRule.SIZE_BOUNDS, candidate.id, params=params)]


def one_ronda_each(problem: Problem, result: dict) -> list[Violation]:
    """One per neighbour who is not in exactly one place: one ronda, or the unseated list."""
    places = Counter(result["unseated"])
    places.update(m["uid"] for ronda in result["proposals"] for m in ronda["members"])
    return [
        Violation(HardRule.ONE_RONDA_EACH, None, (p.uid,), params={"places": places[p.uid]})
        for p in problem.people
        if places[p.uid] != 1
    ]


RONDA_CHECKS = (seat_rules, avoid_pair_apart, size_bounds)


def hard_violations(problem: Problem, result: dict) -> list[Violation]:
    """Every hard-rule violation in `result`, ronda by ronda, then the places check."""
    violations = []
    for ronda in result["proposals"]:
        candidate = Candidate(ronda["barrio"], ronda["pretext"], ronda["slot"])
        uids = [m["uid"] for m in ronda["members"]]
        for ronda_check in RONDA_CHECKS:
            violations += ronda_check(problem, candidate, uids)
    return violations + one_ronda_each(problem, result)


def check(data: dict, result: dict) -> list[dict]:
    """Every hard rule `result` breaks for the input `data`; empty when the groups are valid.

    Each violation is {"rule": <HardRule literal>, "rondaId": <id or None>, "uids": [...]}.
    """
    return [
        {"rule": str(v.rule), "rondaId": v.ronda_id, "uids": list(v.uids)}
        for v in hard_violations(parse_problem(data), result)
    ]
