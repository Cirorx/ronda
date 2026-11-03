"""Smoke test 12: the organiser agent sets up a ronda that formed itself (functions/auto_setup.py)
on Muse Spark Open on Baseten: a public place from the offered ones, the hour inside the band
and who opens, checked by code. Prints what was kept, who chose it and the latency; the trace
stays in memory. Every person and place is invented.

    functions/venv/bin/python scripts/smoke/s12_auto_setup.py [runs]

It needs functions/'s packages (pydantic, openai, OR-Tools), hence functions' venv.
"""

import sys
import time
from pathlib import Path

from _env import BASETEN_BASE, key

FUNCTIONS = Path(__file__).resolve().parents[2] / "functions"
sys.path.insert(0, str(FUNCTIONS))

import auto_setup  # noqa: E402
from openai import OpenAI  # noqa: E402
from organiser.model import SPARK_OPEN, ChatModel  # noqa: E402
from tests.auto_form_fakes import MON_10, PEOPLE, SEAT, sign_ups  # noqa: E402
from tests.fake_firestore import FakeFirestore  # noqa: E402


def main(runs: int) -> None:
    model = ChatModel(
        OpenAI(base_url=BASETEN_BASE, api_key=key("BASETEN_API_KEY"), timeout=60), SPARK_OPEN
    )
    group = {
        "id": SEAT,
        "barrio": "cordon",
        "pretext": "mate",
        "slot": "thu-afternoon",
        "members": [
            {"uid": uid, "firstName": name, "ageBand": band, "distanceBlocks": 0}
            for uid, (name, band) in PEOPLE.items()
        ],
    }
    for n in range(1, runs + 1):
        db = FakeFirestore(sign_ups())
        users = {
            p[6:]: d
            for p, d in db.documents.items()
            if p.count("/") == 1 and p.startswith("users/")
        }
        started = time.perf_counter()
        setup = auto_setup.set_up(
            db, f"smoke_{n}", auto_setup.group_of(db, group, users, MON_10), MON_10, lambda: model
        )
        seconds = round(time.perf_counter() - started, 1)
        steps = [d for p, d in sorted(db.documents.items()) if "/steps/" in p]
        turns = [s for s in steps if s["kind"] == "model"]
        tools = [f"{s['tool']}:{s['status']}" for s in steps if s["kind"] == "tool"]
        tokens = sum(s.get("tokensIn", 0) for s in turns), sum(s.get("tokensOut", 0) for s in turns)
        print(f"run {n}: {seconds} s, {len(turns)} turns, tools {tools}, tokens in/out {tokens}")
        if setup is None:
            print("  no setup")
            continue
        print(
            f"  by {setup['by']}: {setup['place']['name']} a las {setup['hour']}, "
            f"abre {setup['anfitrionName']}, cierra {setup['colaName']}"
        )
        print(f"  reason: {setup['reason']}")


if __name__ == "__main__":
    main(int(sys.argv[1]) if len(sys.argv) > 1 else 3)
