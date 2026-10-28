"""Ronda's group solver: JSON in, JSON out. No Firebase imports."""

from ronda_solver import explain as _explain
from ronda_solver import score as _score
from ronda_solver.check import check
from ronda_solver.model import solve_problem
from ronda_solver.problem import parse_problem


def solve(data: dict) -> dict:
    """Proposes rondas for the neighbours in `data`. The contract is in solver/README.md."""
    return solve_problem(parse_problem(data))


def score(data: dict, result: dict) -> dict:
    """Seated count, soft-rule units and objective of any result's proposals."""
    return _score.score(parse_problem(data), result["proposals"])


def explain(data: dict, result: dict, alternative: dict) -> dict:
    """Why `alternative` loses to `result`: {"reasons": [...], "reason": es-419 sentence or None}.
    Either grouping may come from anywhere: the solver, or the admin's own edit."""
    return _explain.explain(parse_problem(data), result, alternative)


__all__ = ["check", "explain", "score", "solve"]
