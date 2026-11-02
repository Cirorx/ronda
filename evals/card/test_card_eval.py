"""The card eval: the organiser agent composes the weekly card (functions/weekly_card.py) for
three invented demo rondas in the same week, and the run reports, per ronda:

- schema validity: whether every `compose_card` call fitted the catalog (pydantic), or how many
  came back `invalid`;
- the gates: how many blocks each gate held (emoji, voseo, money, address), how many were
  dropped because their fact didn't hold this week, and how many were repeats or empty;
- blocks kept and dropped, and whether the card fell back to the template (and why);
- latency per card (the trace's clock), and the model that answered;
- that two rondas in the same week get different cards.

Offline (the default) the model's turns come from `recorded/<ronda>.json`; `--live` runs Muse
Spark Open on Baseten with Spark 1.3 as fallback, exactly as the job does, and the table says
which. RESULTS.md is rewritten at the end of every run; it holds invented data only.
"""

import json
import pathlib
import re
from datetime import datetime

import pytest

import rsvp
import weekly_card
from organiser import gates, text
from rondas import RONDAS, WEEK_ID, database, now
from tests.organiser_fakes import FakeWeather, ScriptedModel, call, turn
from tests.test_rsvp import Sender

HERE = pathlib.Path(__file__).resolve().parent
RECORDED = HERE / "recorded"
RESULTS = HERE / "RESULTS.md"

DROPPED = re.compile(r"^Bloque (\w+) descartado: (.+)\.$")
GATES = {
    "emoji": "tiene un emoji",
    "voseo": "no está en voseo",
    "money": "menciona plata",
    "address": "parece una casa o una dirección",
}


def _scripted(name: str) -> ScriptedModel:
    recording = json.loads((RECORDED / f"{name}.json").read_text())
    return ScriptedModel(
        [
            turn(
                *[call(c["name"], **c["arguments"]) for c in t.get("tool_calls", [])],
                content=t.get("content", ""),
            )
            for t in recording["turns"]
        ],
        name="recorded",
    )


class ByPretext:
    """One scripted model per ronda, chosen by the task's first line ("Ronda: mate."), so the
    job runs all three rondas in one call as it does in production."""

    def __init__(self) -> None:
        self._models = {name: _scripted(name) for name in RONDAS}
        self.requests: list[tuple[str, list[dict]]] = []

    @property
    def name(self) -> str:
        return "recorded"

    def complete(self, messages: list[dict], tools: list[dict]):
        task = messages[1]["content"]
        label = task.split("\n", 1)[0].removeprefix("Ronda: ").rstrip(".")
        by_label = {value: key for key, value in rsvp.PRETEXT_LABELS.items()}
        name = by_label.get(label, label)
        self.requests.append((name, messages))
        return self._models[name].complete(messages, tools)


@pytest.fixture(scope="session")
def run(live, model_keys):
    """Runs the job once for the three rondas and keeps the database."""
    db = database()
    if live:
        model = weekly_card.from_environment(timeout=60)
    else:
        model = ByPretext()
    started = datetime.now()
    # `force`, as the admin's "run it now": the Saturday ronda is more than three days away
    # on Monday, so the hourly job would wait for it; the gates still hold.
    counts = weekly_card.run_weekly_card(
        db, now(), send=Sender(), model=model, weather=FakeWeather(), force=True
    )
    return {"db": db, "counts": counts, "live": live, "wall": datetime.now() - started}


def _steps(db, ronda: str) -> list[dict]:
    """The steps of the ronda's run (a forced run's id carries the time it ran at)."""
    runs = [
        p
        for p in db.documents
        if p.startswith(f"agent_runs/{ronda}_") and p.endswith("_card") or "_card_" in p
        if p.startswith(f"agent_runs/{ronda}_") and "/steps/" not in p
    ]
    steps: list[dict] = []
    for run_id in sorted(runs):
        prefix = f"{run_id}/steps/"
        steps += [db.documents[p] for p in sorted(db.documents) if p.startswith(prefix)]
    return steps


def _report(db, ronda: str) -> dict:
    card = db.documents.get(f"rondas/{ronda}/views/card", {})
    steps = _steps(db, ronda)
    compose = [s for s in steps if s.get("tool") == "compose_card"]
    held = {gate: 0 for gate in GATES} | {"fact": 0, "other": 0}
    for step in steps:
        if step["kind"] != "note":
            continue
        match = DROPPED.match(step["note"])
        if not match:
            continue
        reason = match.group(2)
        for gate, words in GATES.items():
            if reason.startswith(words):
                held[gate] += 1
                break
        else:
            held["fact" if reason.startswith("no ") else "other"] += 1
    texts = []
    for message in card.get("messages", []):
        for component in message.get("updateComponents", {}).get("components", []):
            if "text" in component:
                texts.append((component["id"], f"{component['title']}\n{component['text']}"))
    return {
        "ronda": ronda,
        "model": card.get("model", ""),
        "status": card.get("status", "missing"),
        "reason": card.get("reason", ""),
        "blocks": card.get("blocks", []),
        "dropped": card.get("dropped", 0),
        "compose_calls": len(compose),
        "invalid_calls": sum(1 for s in compose if s["status"] == "invalid"),
        "held": held,
        "latency_ms": card.get("latencyMs", 0),
        "model_turns": sum(1 for s in steps if s["kind"] == "model"),
        "texts": texts,
        "messages": card.get("messages"),
    }


@pytest.fixture(scope="session")
def reports(run) -> list[dict]:
    rows = [_report(run["db"], ronda) for ronda in RONDAS]
    yield rows
    _write_results(rows, run)


def _write_results(rows: list[dict], run: dict) -> None:
    source = (
        "the real models (`--live`)"
        if run["live"]
        else "hand-written stand-ins in `recorded/` (no key during the build; `--live` records "
        "the real thing)"
    )
    lines = [
        "# Card eval results",
        "",
        f"Last run: {datetime.now():%Y-%m-%d %H:%M} local, model turns from {source}. "
        f"Three invented demo rondas, ISO week {WEEK_ID}, the job run once at Monday 10:00 "
        f"(`weekly_card.run_weekly_card`, counts {run['counts']}, wall clock "
        f"{run['wall'].total_seconds():.1f} s).",
        "",
        "| ronda | model | card | blocks kept | dropped | compose calls (invalid) | "
        "held: emoji / voseo / money / address | no fact / other | model turns | latency ms |",
        "|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        held = r["held"]
        card = r["status"] + (f" ({r['reason']})" if r["reason"] else "")
        lines.append(
            f"| {r['ronda']} | {r['model']} | {card} | {', '.join(r['blocks']) or '—'} | "
            f"{r['dropped']} | {r['compose_calls']} ({r['invalid_calls']}) | "
            f"{held['emoji']} / {held['voseo']} / {held['money']} / {held['address']} | "
            f"{held['fact']} / {held['other']} | {r['model_turns']} | {r['latency_ms']} |"
        )
    agent = [r for r in rows if r["status"] == "agent"]
    distinct = len({json.dumps(r["messages"], sort_keys=True) for r in agent})
    lines += [
        "",
        f"- Cards from the model: {len(agent)} of {len(rows)}; distinct cards among them: "
        f"{distinct}.",
        f"- Schema validity: {sum(r['invalid_calls'] for r in rows)} invalid `compose_card` "
        f"call(s) over {sum(r['compose_calls'] for r in rows)}.",
        f"- Blocks held by a gate: {sum(sum(v for k, v in r['held'].items() if k in GATES) for r in rows)}; "
        f"dropped for a missing fact: {sum(r['held']['fact'] for r in rows)}.",
        "- Every text kept passed `gates.check_words` again here (emoji, voseo, money, "
        "address), and no address reached a card.",
        "",
        "Latency is the run's own clock from the start of the trace to the stored card, "
        "model turns included. Recorded runs measure only the code around the model.",
    ]
    RESULTS.write_text("\n".join(lines) + "\n")


@pytest.mark.parametrize("ronda", RONDAS)
def test_every_text_kept_passes_the_gates_and_carries_no_address(reports, ronda):
    report = next(r for r in reports if r["ronda"] == ronda)
    assert report["status"] in ("agent", "template"), report
    for kind, words in report["texts"]:
        # The después is the one block that may name a home ("en lo de Mirta"), never an
        # address: code fills it after the gates ran on the model's words.
        assert gates.check_words(words, home=kind == "despues").allowed, words
        for line in words.split("\n"):
            assert text.strip_markdown(line) == line, line
    assert "Av. Central" not in json.dumps(report["messages"], ensure_ascii=False)
    assert "1234" not in json.dumps(report["messages"], ensure_ascii=False)


def test_two_rondas_in_the_same_week_get_different_cards(reports):
    agent = [r for r in reports if r["status"] == "agent"]
    assert len(agent) >= 2, [r["status"] for r in reports]
    cards = [json.dumps(r["messages"], sort_keys=True) for r in agent]
    assert len(set(cards)) == len(cards)


def test_the_recorded_runs_show_the_gates_and_the_facts(reports, live):
    if live:
        pytest.skip("the recorded expectations; a live run only reports")
    by = {r["ronda"]: r for r in reports}
    assert by["mate"]["blocks"] == ["rain", "host", "newcomer", "despues"]
    assert by["mate"]["invalid_calls"] == 0
    assert by["truco"]["blocks"] == ["rain", "host", "bench"]
    # The fútbol stand-in slips into tú (held by the voseo gate) and names a host the ronda
    # doesn't have (dropped for its fact); the forecast block stays.
    assert by["futbol5"]["blocks"] == []
    assert by["futbol5"]["status"] == "template"
    assert by["futbol5"]["held"]["voseo"] == 1
    assert by["futbol5"]["held"]["fact"] == 1
    assert by["futbol5"]["dropped"] == 2
    assert all(r["model"] == "recorded" for r in reports)


def test_the_newcomer_the_host_and_the_despues_are_filled_by_code(reports, live):
    if live:
        pytest.skip("names depend on the model keeping the placeholders")
    mate = next(r for r in reports if r["ronda"] == "mate")
    joined = "\n".join(words for _, words in mate["texts"])
    assert "Mirta" in joined
    assert "Facu" in joined
    assert "bizcochos en lo de Mirta" in joined
    assert "{anfitrion}" not in joined and "{nuevo}" not in joined
