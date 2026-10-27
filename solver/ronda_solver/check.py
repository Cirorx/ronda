"""Checks a result against every hard rule, independently of how the model enforced them."""

from collections import Counter

from ronda_solver.problem import Candidate, parse_problem
from ronda_solver.rules import HardRule, broken_seat_rules, size_rule


def _violation(rule: HardRule, ronda_id: str | None, uids: list[str]) -> dict:
    return {"rule": str(rule), "rondaId": ronda_id, "uids": uids}


def check(data: dict, result: dict) -> list[dict]:
    """Every hard rule `result` breaks for the input `data`; empty when the groups are valid.

    Each violation is {"rule": <HardRule literal>, "rondaId": <id or None>, "uids": [...]}.
    """
    problem = parse_problem(data)
    violations = []
    places = Counter(result["unseated"])
    for ronda in result["proposals"]:
        candidate = Candidate(ronda["barrio"], ronda["pretext"], ronda["slot"])
        uids = [m["uid"] for m in ronda["members"]]
        places.update(uids)
        for uid in uids:
            if not problem.has_person(uid):
                violations.append(_violation(HardRule.ELIGIBLE_SEAT, candidate.id, [uid]))
                continue
            for rule in broken_seat_rules(problem, problem.person(uid), candidate):
                violations.append(_violation(rule, candidate.id, [uid]))
        for a, b in problem.avoid_pairs:
            if a in uids and b in uids:
                violations.append(_violation(HardRule.AVOID_PAIR_APART, candidate.id, [a, b]))
        size = size_rule(candidate.pretext)
        if not size.floor <= len(uids) <= size.cap:
            violations.append(_violation(HardRule.SIZE_BOUNDS, candidate.id, []))
    # Each neighbour is in exactly one place: one ronda, or the unseated list.
    for person in problem.people:
        if places[person.uid] != 1:
            violations.append(_violation(HardRule.ONE_RONDA_EACH, None, [person.uid]))
    return violations
