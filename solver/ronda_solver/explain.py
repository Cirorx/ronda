"""Why a grouping was rejected: the rules it breaks that the winner keeps, as structured reasons.

A grouping that breaks a hard rule is rejected for that rule alone; CP-SAT names it. Otherwise the
soft-rule checkers are diffed against the winner's."""

from collections import Counter, defaultdict

from ortools.sat.python import cp_model

from ronda_solver.check import hard_violations
from ronda_solver.problem import Candidate, Problem
from ronda_solver.rules import (
    FEWER_SEATED,
    SEAT_REWARD,
    HardRule,
    SoftRule,
    Violation,
    broken_seat_rules,
    size_rule,
)
from ronda_solver.score import soft_violations
from ronda_solver.spanish import in_spanish


def hard_core(problem: Problem, groups: dict) -> list[HardRule]:
    """Hard rules that suffice to rule the grouping out, read from CP-SAT: the grouping's seats
    are fixed, each hard rule's constraints are gated by one literal, and the solve assumes every
    literal. The answer is a sufficient set, not every rule broken; empty when none is."""
    cp = cp_model.CpModel()
    keeps = {rule: cp.new_bool_var(f"keeps[{rule}]") for rule in HardRule}
    places = defaultdict(list)
    for ronda in groups["proposals"]:
        candidate = Candidate(ronda["barrio"], ronda["pretext"], ronda["slot"])
        seats = {}
        for member in ronda["members"]:
            uid = member["uid"]
            seat = cp.new_bool_var(f"seat[{uid},{candidate.id}]")
            cp.add(seat == 1)
            seats[uid] = seat
            places[uid].append(seat)
            broken = (
                broken_seat_rules(problem, problem.person(uid), candidate)
                if problem.has_person(uid)
                else [HardRule.ELIGIBLE_SEAT]
            )
            for rule in broken:
                cp.add(seat == 0).only_enforce_if(keeps[rule])
        for a, b in problem.avoid_pairs:
            if a in seats and b in seats:
                cp.add(seats[a] + seats[b] <= 1).only_enforce_if(keeps[HardRule.AVOID_PAIR_APART])
        size = size_rule(candidate.pretext)
        taken = sum(seats.values())
        cp.add(taken >= size.floor).only_enforce_if(keeps[HardRule.SIZE_BOUNDS])
        cp.add(taken <= size.cap).only_enforce_if(keeps[HardRule.SIZE_BOUNDS])
    unseated = Counter(groups["unseated"])
    for person in problem.people:
        cp.add(sum(places[person.uid]) + unseated[person.uid] == 1).only_enforce_if(
            keeps[HardRule.ONE_RONDA_EACH]
        )
    cp.add_assumptions(list(keeps.values()))
    solver = cp_model.CpSolver()
    solver.parameters.num_workers = 1  # the core is only reported reliably by a single worker
    if solver.solve(cp) != cp_model.INFEASIBLE:
        return []
    core = set(solver.sufficient_assumptions_for_infeasibility())
    return [rule for rule, literal in keeps.items() if literal.index in core]


def hard_reasons(problem: Problem, groups: dict) -> list[dict]:
    """The hard rules CP-SAT says rule the grouping out, each with the checker's violations."""
    by_rule = defaultdict(list)
    for v in hard_violations(problem, groups):
        by_rule[v.rule].append(v)
    return [
        _reason(rule, True, len(by_rule[rule]), None, by_rule[rule])
        for rule in hard_core(problem, groups)
    ]


def _seated(groups: dict) -> list[str]:
    return [m["uid"] for ronda in groups["proposals"] for m in ronda["members"]]


def soft_reasons(problem: Problem, winner: dict, alternative: dict) -> list[dict]:
    """Each weighted soft rule the alternative breaks more than the winner, and seating fewer, by
    the objective points it loses (largest first). A reason lists the alternative's violations of
    its rule that the winner does not have."""
    kept = soft_violations(problem, winner["proposals"])
    broken = soft_violations(problem, alternative["proposals"])
    reasons = []
    seated = set(_seated(alternative))
    if (fewer := len(_seated(winner)) - len(seated)) > 0:
        left_out = tuple(uid for uid in _seated(winner) if uid not in seated)
        unseated = Violation(FEWER_SEATED, None, left_out, units=fewer)
        reasons.append(_reason(FEWER_SEATED, False, fewer, SEAT_REWARD * fewer, [unseated]))
    for rule in SoftRule:
        mine = [v for v in broken if v.rule == rule]
        more = sum(v.units for v in mine) - sum(v.units for v in kept if v.rule == rule)
        if more > 0 and problem.weights[rule] > 0:
            new = [v for v in mine if v not in kept]
            reasons.append(_reason(rule, False, more, problem.weights[rule] * more, new))
    return sorted(reasons, key=lambda r: -r["loss"])


def _reason(
    rule: str, hard: bool, units: int, loss: int | None, violations: list[Violation]
) -> dict:
    return {
        "rule": str(rule),
        "hard": hard,
        "units": units,
        "loss": loss,
        "violations": [v.as_json() for v in violations],
    }


def explain(problem: Problem, winner: dict, alternative: dict) -> dict:
    """The reasons `alternative` loses to `winner`, most decisive first, and the first in Spanish.
    No reasons (and reason None) when it breaks no hard rule and is no worse on any soft one."""
    reasons = hard_reasons(problem, alternative) or soft_reasons(problem, winner, alternative)
    return {"reasons": reasons, "reason": in_spanish(reasons[0]) if reasons else None}
