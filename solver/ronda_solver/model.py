"""Builds the CP-SAT model for a problem and reads the proposals back."""

import time
from collections import defaultdict
from dataclasses import dataclass, field

from ortools.sat.python import cp_model

from ronda_solver.problem import Candidate, Problem
from ronda_solver.rules import (
    SEAT_REWARD,
    TRUCO_OLD,
    TRUCO_PRETEXT,
    TRUCO_YOUNG,
    SoftRule,
    age_group,
    broken_seat_rules,
    size_rule,
)
from ronda_solver.score import ronda_checks, score

FEWER_SEATED = "fewerSeated"
"""The rejected alternative's broken rule when it seats fewer neighbours."""

SOLVED = (cp_model.OPTIMAL, cp_model.FEASIBLE)


@dataclass(frozen=True)
class Solution:
    status: str
    seconds: float
    objective: int | None = None
    placed: dict[str, Candidate] = field(default_factory=dict)
    """Each seated uid's ronda."""


class RondaModel:
    """One CP-SAT model per problem. Each rule is added by exactly one method, named after it.
    Every penalty variable equals its rule's units exactly (not just bounds them), so the
    rejected alternative cannot claim to break a rule it keeps."""

    def __init__(self, problem: Problem):
        self.problem = problem
        self.cp = cp_model.CpModel()
        # seats[c][uid] is 1 when uid takes a seat in candidate ronda c.
        self.seats: dict[Candidate, dict[str, cp_model.IntVar]] = {}
        self.penalties: dict[SoftRule, list] = defaultdict(list)

        self._seat_variables()
        self._one_ronda_each()
        self._avoid_pairs_apart()
        self._plus_one_together()
        for c in self.seats:
            self._size(c)
            self._two_per_age_band(c)
            self._one_plus_one_pair(c)
            self._truco_cross_age(c)
            self._nearby_first(c)

        self.seated = sum(v for seats in self.seats.values() for v in seats.values())
        self.cp.maximize(
            SEAT_REWARD * self.seated
            - sum(problem.weights[rule] * sum(terms) for rule, terms in self.penalties.items())
        )

    def _seat_variables(self):
        """Every hard seat rule (eligible seat, slot, pretext, ≤ 10 blocks), applied in one place:
        a seat variable exists only where all of them pass. A candidate that fewer people may join
        than its floor can never open, so it gets no variables at all."""
        for c in self.problem.candidates:
            allowed = [
                p.uid for p in self.problem.people if not broken_seat_rules(self.problem, p, c)
            ]
            if len(allowed) >= size_rule(c.pretext).floor:
                self.seats[c] = {
                    uid: self.cp.new_bool_var(f"seat[{uid},{c.id}]") for uid in allowed
                }

    def _one_ronda_each(self):
        """HardRule.ONE_RONDA_EACH"""
        by_person = defaultdict(list)
        for seats in self.seats.values():
            for uid, var in seats.items():
                by_person[uid].append(var)
        for options in by_person.values():
            self.cp.add_at_most_one(options)

    def _avoid_pairs_apart(self):
        """HardRule.AVOID_PAIR_APART"""
        for a, b in self.problem.avoid_pairs:
            for seats in self.seats.values():
                if a in seats and b in seats:
                    self.cp.add_at_most_one(seats[a], seats[b])

    def _size(self, c: Candidate):
        """HardRule.SIZE_BOUNDS, and SoftRule.SIZE_FOR_PRETEXT below the target."""
        rule = size_rule(c.pretext)
        taken = sum(self.seats[c].values())
        is_open = self.cp.new_bool_var(f"open[{c.id}]")
        self.cp.add(taken >= rule.floor * is_open)
        self.cp.add(taken <= rule.cap * is_open)
        missing = self.cp.new_int_var(0, rule.target, f"short[{c.id}]")
        self.cp.add_max_equality(missing, [0, rule.target * is_open - taken])
        self.penalties[SoftRule.SIZE_FOR_PRETEXT].append(missing)

    def _two_per_age_band(self, c: Candidate):
        """SoftRule.TWO_PER_AGE_BAND: costs once per member who is the only one of their group."""
        by_group = defaultdict(list)
        for uid, var in self.seats[c].items():
            by_group[age_group(self.problem.person(uid).age_band)].append(var)
        for group, seats in sorted(by_group.items()):
            alone = self.cp.new_bool_var(f"alone[{c.id},{group}]")
            self.cp.add(sum(seats) == 1).only_enforce_if(alone)
            self.cp.add(sum(seats) != 1).only_enforce_if(~alone)
            self.penalties[SoftRule.TWO_PER_AGE_BAND].append(alone)

    def _plus_one_together(self):
        """SoftRule.PLUS_ONE_TOGETHER: costs once per ronda holding one of the pair alone."""
        for a, b in self.problem.plus_one_pairs:
            for c, seats in self.seats.items():
                if a not in seats and b not in seats:
                    continue
                seat_a, seat_b = seats.get(a, 0), seats.get(b, 0)
                split = self.cp.new_bool_var(f"split[{a},{b},{c.id}]")
                self.cp.add_abs_equality(split, seat_a - seat_b)
                self.penalties[SoftRule.PLUS_ONE_TOGETHER].append(split)

    def _one_plus_one_pair(self, c: Candidate):
        """SoftRule.ONE_PLUS_ONE_PAIR: costs once per pair beyond the first in the ronda."""
        seats = self.seats[c]
        pairs = [(a, b) for a, b in self.problem.plus_one_pairs if a in seats and b in seats]
        if len(pairs) < 2:
            return
        together = []
        for a, b in pairs:
            both = self.cp.new_bool_var(f"pair[{a},{b},{c.id}]")
            self.cp.add_min_equality(both, [seats[a], seats[b]])
            together.append(both)
        extra = self.cp.new_int_var(0, len(pairs) - 1, f"extraPairs[{c.id}]")
        self.cp.add_max_equality(extra, [0, sum(together) - 1])
        self.penalties[SoftRule.ONE_PLUS_ONE_PAIR].append(extra)

    def _truco_cross_age(self, c: Candidate):
        """SoftRule.TRUCO_CROSS_AGE: costs once per under-30 left without an over-60 partner."""
        if c.pretext != TRUCO_PRETEXT:
            return
        groups = {uid: age_group(self.problem.person(uid).age_band) for uid in self.seats[c]}
        young = [var for uid, var in self.seats[c].items() if groups[uid] == TRUCO_YOUNG]
        old = [var for uid, var in self.seats[c].items() if groups[uid] == TRUCO_OLD]
        if not young:
            return
        partnerless = self.cp.new_int_var(0, len(young), f"partnerless[{c.id}]")
        self.cp.add_max_equality(partnerless, [0, sum(young) - sum(old)])
        self.penalties[SoftRule.TRUCO_CROSS_AGE].append(partnerless)

    def _nearby_first(self, c: Candidate):
        """SoftRule.NEARBY_FIRST: costs per block walked, so a nearby ronda opens before a far
        seat fills."""
        for uid, var in self.seats[c].items():
            self.penalties[SoftRule.NEARBY_FIRST].append(
                self.problem.walk(self.problem.person(uid), c) * var
            )

    def solve(self, max_time_in_seconds: float) -> Solution:
        solver = cp_model.CpSolver()
        solver.parameters.max_time_in_seconds = max_time_in_seconds
        status = solver.solve(self.cp)
        name = solver.status_name(status).lower()
        if status not in SOLVED:  # pragma: no cover - only when time runs out before any solution
            return Solution(name, solver.wall_time)
        placed = {
            uid: c for c, seats in self.seats.items() for uid, v in seats.items() if solver.value(v)
        }
        return Solution(name, solver.wall_time, round(solver.objective_value), placed)

    def require_a_broken_rule(self, proposal: Solution, units: dict[str, int]):
        """From now on, a solution must seat fewer people or break some weighted soft rule more
        than the proposal did. The search starts from the proposal (a hint), so a close
        alternative turns up within a short time limit."""
        for c, seats in self.seats.items():
            for uid, var in seats.items():
                self.cp.add_hint(var, proposal.placed.get(uid) == c)
        seated = len(proposal.placed)
        worse = []
        for rule, terms in self.penalties.items():
            if self.problem.weights[rule] > 0:
                breaks_more = self.cp.new_bool_var(f"breaksMore[{rule}]")
                self.cp.add(sum(terms) >= units[rule] + 1).only_enforce_if(breaks_more)
                worse.append(breaks_more)
        seats_fewer = self.cp.new_bool_var("seatsFewer")
        self.cp.add(self.seated <= seated - 1).only_enforce_if(seats_fewer)
        self.cp.add_bool_or([*worse, seats_fewer])


def proposals_of(problem: Problem, placed: dict[str, Candidate]) -> list[dict]:
    """The proposed rondas, in candidate order, with each member's walk and the soft checks."""
    by_ronda = defaultdict(list)
    for p in problem.people:
        if p.uid in placed:
            by_ronda[placed[p.uid]].append(p.uid)
    return [
        {
            "id": c.id,
            "barrio": c.barrio,
            "pretext": c.pretext,
            "slot": c.slot,
            "members": [
                {
                    "uid": uid,
                    "ageBand": problem.person(uid).age_band,
                    "barrio": problem.person(uid).barrio,
                    "distanceBlocks": problem.walk(problem.person(uid), c),
                }
                for uid in uids
            ],
            "checks": ronda_checks(problem, c, uids),
        }
        for c in problem.candidates
        if (uids := by_ronda.get(c))
    ]


def _groups(problem: Problem, solution: Solution) -> dict:
    return {
        "proposals": proposals_of(problem, solution.placed),
        "unseated": [p.uid for p in problem.people if p.uid not in solution.placed],
    }


def _rejected_alternative(
    problem: Problem, model: RondaModel, solution: Solution, proposal: dict
) -> dict | None:
    """The best grouping that breaks a soft rule more (or seats fewer), and the rule it breaks."""
    kept = score(problem, proposal["proposals"])
    if kept["seated"] == 0:
        return None
    model.require_a_broken_rule(solution, kept["units"])
    rejected = model.solve(problem.options.alternative_time_in_seconds)
    if rejected.objective is None:  # pragma: no cover - only when its time runs out
        return None
    alternative = _groups(problem, rejected)
    broken = score(problem, alternative["proposals"])
    losses = {FEWER_SEATED: SEAT_REWARD * (kept["seated"] - broken["seated"])}
    for rule in SoftRule:
        losses[str(rule)] = problem.weights[rule] * (broken["units"][rule] - kept["units"][rule])
    return {
        **alternative,
        "brokenRule": max(losses, key=losses.get),
        "objectiveLoss": kept["objective"] - broken["objective"],
        "solveSeconds": round(rejected.seconds, 3),
    }


def solve_problem(problem: Problem) -> dict:
    started = time.perf_counter()
    model = RondaModel(problem)
    built = time.perf_counter() - started
    solution = model.solve(problem.options.max_time_in_seconds)
    proposal = _groups(problem, solution)
    return {
        "status": solution.status,
        **proposal,
        "rejectedAlternative": _rejected_alternative(problem, model, solution, proposal),
        "stats": {
            "objective": solution.objective,
            "buildSeconds": round(built, 3),
            "solveSeconds": round(solution.seconds, 3),
            "candidates": len(model.seats),
            "seatVariables": sum(len(s) for s in model.seats.values()),
        },
    }
