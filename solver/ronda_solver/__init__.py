"""Ronda's group solver: JSON in, JSON out. No Firebase imports."""

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


__all__ = ["check", "score", "solve"]
