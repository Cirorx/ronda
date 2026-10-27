"""Times the solver on invented demo neighbours and checks every hard rule on its groups.

From the repo root, with the solver's venv:
    uv run --project solver python solver/bench.py --people 30 200
or, after `source solver/.venv/bin/activate`:
    python solver/bench.py --people 30 200

Exits 1 when any size breaks a hard rule or forms no ronda.
"""

import argparse
import sys
import time

from ronda_solver import check, solve
from ronda_solver.demo import invented_problem

COLUMNS = ("people", "rondas", "seated", "unseated", "status", "build", "solve", "alt", "total")


def measure(people: int, seed: int = 23) -> dict:
    """Solves `people` invented neighbours; `valid` means the checker found no broken hard rule
    and at least one ronda formed."""
    data = invented_problem(people, seed)
    started = time.perf_counter()
    result = solve(data)
    total = time.perf_counter() - started
    violations = check(data, result)
    alternative = result["rejectedAlternative"] or {}
    return {
        "people": people,
        "rondas": len(result["proposals"]),
        "seated": people - len(result["unseated"]),
        "unseated": len(result["unseated"]),
        "status": result["status"],
        "build": result["stats"]["buildSeconds"],
        "solve": result["stats"]["solveSeconds"],
        "alt": alternative.get("solveSeconds", 0.0),
        "total": round(total, 2),
        "brokenRule": alternative.get("brokenRule"),
        "violations": violations,
        "valid": not violations and bool(result["proposals"]),
    }


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("--people", type=int, nargs="+", default=[30, 200])
    parser.add_argument("--seed", type=int, default=23)
    args = parser.parse_args(argv)

    print(" ".join(f"{c:>8}" for c in COLUMNS), "   check  rejected alternative")
    ok = True
    for people in args.people:
        row = measure(people, args.seed)
        ok = ok and row["valid"]
        verdict = "PASS" if row["valid"] else "FAIL"
        print(" ".join(f"{row[c]:>8}" for c in COLUMNS), f"{verdict:>7}  {row['brokenRule']}")
        for violation in row["violations"]:
            print("   ", violation)
    print("seconds: build = model, solve = CP-SAT, alt = rejected alternative, total = wall clock")
    return 0 if ok else 1


if __name__ == "__main__":
    sys.exit(main())
