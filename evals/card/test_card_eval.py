"""The card eval: the organiser agent composes the weekly card (functions/weekly_card.py) for
three invented demo rondas in the same week, and the run reports, per ronda and overall:

- schema validity: how many `compose_card` calls fitted the catalog (pydantic) and how many came
  back `invalid`;
- the gates: how many proposed blocks each gate held (emoji, voseo, money, address), how many
  were dropped because their fact didn't hold this week, and how many were repeats or empty;
- blocks kept and dropped, and whether the card fell back to the template (and why);
- latency per card (the model turns, measured live and kept in the recording), tokens and cost;
- that two rondas in the same week get different cards.

Offline (the default) the model's turns replay `fixtures/recorded/<ronda>.json`, the real
models' answers kept by `--live --record`; `--live` runs Muse Spark Open on Baseten with Spark
1.3 as fallback, exactly as the job does. RESULTS.md is rewritten by `--record` only. A second,
offline-only run plays `fixtures/stand_ins/`, hand-written answers that slip on purpose, to show
the gates and the facts drop what they should.
"""

import json
import pathlib
import re
import time
from datetime import datetime

import pytest
import rsvp
import weekly_card
from organiser import gates, text
from organiser.model import SPARK, SPARK_OPEN, ToolCall, Turn
from tests.organiser_fakes import FakeWeather, ScriptedModel
from tests.test_rsvp import Sender

from rondas import RONDAS, WEEK_ID, database, now

HERE = pathlib.Path(__file__).resolve().parent
RECORDED = HERE / "fixtures" / "recorded"
STAND_INS = HERE / "fixtures" / "stand_ins"
RESULTS = HERE / "RESULTS.md"

PRICES = {SPARK_OPEN: (1.25, 4.25), SPARK: (1.25, 4.25)}
"""USD per million tokens in and out: Spark 1.3 from docs/MODELS.md; Spark Open on Baseten's
Model APIs as listed on 2026-10-23 (the same rates)."""

DROPPED = re.compile(r"^Bloque (\w+) descartado: (.+)\.$")
GATES = {
    "emoji": "tiene un emoji",
    "voseo": "no está en voseo",
    "money": "menciona plata",
    "address": "parece una casa o una dirección",
}
BY_LABEL = {label: key for key, label in rsvp.PRETEXT_LABELS.items()}


def _ronda(messages: list[dict]) -> str:
    """Which demo ronda a request is for, from the task's first line ("Ronda: truco.")."""
    label = messages[1]["content"].split("\n", 1)[0].removeprefix("Ronda: ").rstrip(".")
    return BY_LABEL.get(label, label)


def _turn(t: dict) -> Turn:
    calls = tuple(
        ToolCall(
            c.get("id") or f"call_{i}",
            c["name"],
            c["arguments"]
            if isinstance(c["arguments"], str)
            else json.dumps(c["arguments"], ensure_ascii=False),
        )
        for i, c in enumerate(t.get("tool_calls", []))
    )
    return Turn(
        content=t.get("content", ""),
        tool_calls=calls,
        model=t.get("model", "recorded"),
        tokens_in=t.get("tokens_in", 0),
        tokens_out=t.get("tokens_out", 0),
    )


class Replay:
    """One scripted model per ronda, chosen by the task, so the job runs all three rondas in one
    call as it does in production."""

    def __init__(self, folder: pathlib.Path) -> None:
        self.recordings = {
            name: json.loads((folder / f"{name}.json").read_text()) for name in RONDAS
        }
        self._models = {
            name: ScriptedModel([_turn(t) for t in r["turns"]], name="recorded")
            for name, r in self.recordings.items()
        }

    @property
    def name(self) -> str:
        return "recorded"

    def complete(self, messages: list[dict], tools: list[dict]) -> Turn:
        return self._models[_ronda(messages)].complete(messages, tools)


class Recorder:
    """The real model, keeping each ronda's turns (and how long each took) for `--record`."""

    def __init__(self, model) -> None:
        self._model = model
        self.recordings: dict[str, dict] = {name: {"turns": []} for name in RONDAS}

    @property
    def name(self) -> str:
        return self._model.name

    def complete(self, messages: list[dict], tools: list[dict]) -> Turn:
        started = time.perf_counter()
        turn = self._model.complete(messages, tools)
        self.recordings[_ronda(messages)]["turns"].append(
            {
                "model": turn.model,
                "latency_ms": round((time.perf_counter() - started) * 1000),
                "tokens_in": turn.tokens_in,
                "tokens_out": turn.tokens_out,
                "content": turn.content,
                "tool_calls": [
                    {"id": c.id, "name": c.name, "arguments": _arguments(c.arguments)}
                    for c in turn.tool_calls
                ],
            }
        )
        return turn


def _arguments(raw: str) -> object:
    """The call's arguments as JSON when they parse (readable), else the raw text."""
    try:
        return json.loads(raw)
    except ValueError:
        return raw


def _run(model) -> dict:
    db = database()
    started = time.perf_counter()
    # `force`, as the admin's "run it now": the Saturday ronda is more than three days away
    # on Monday, so the hourly job would wait for it; the gates still hold.
    counts = weekly_card.run_weekly_card(
        db, now(), send=Sender(), model=model, weather=FakeWeather(), force=True
    )
    return {"db": db, "counts": counts, "wall_s": time.perf_counter() - started}


@pytest.fixture(scope="session")
def run(live, record, model_keys):
    """The job once for the three rondas, on the real models or their recording."""
    if live:
        model = Recorder(weekly_card.from_environment(timeout=60))
    else:
        if not (RECORDED / f"{RONDAS[0]}.json").exists():
            pytest.skip("no recording yet: run with --live --record")
        model = Replay(RECORDED)
    result = _run(model) | {"live": live, "recordings": model.recordings}
    if record:
        RECORDED.mkdir(parents=True, exist_ok=True)
        for name, recording in model.recordings.items():
            body = {"note": f"Recorded with --live --record on {datetime.now():%Y-%m-%d}."}
            (RECORDED / f"{name}.json").write_text(
                json.dumps(body | recording, ensure_ascii=False, indent=2) + "\n"
            )
    return result


def _steps(db, ronda: str) -> list[dict]:
    """The steps of the ronda's runs (a forced run's id carries the time it ran at)."""
    runs = sorted(
        p
        for p in db.documents
        if p.startswith(f"agent_runs/{ronda}_") and "/steps/" not in p and "_card" in p
    )
    return [
        db.documents[p]
        for run_id in runs
        for p in sorted(db.documents)
        if p.startswith(f"{run_id}/steps/")
    ]


def _cost(tokens: list[dict]) -> float:
    total = 0.0
    for t in tokens:
        price_in, price_out = PRICES.get(t["model"], (0, 0))
        total += (t["in"] * price_in + t["out"] * price_out) / 1e6
    return total


def _report(run: dict, ronda: str) -> dict:
    db = run["db"]
    card = db.documents.get(f"rondas/{ronda}/views/card", {})
    steps = _steps(db, ronda)
    compose = [s for s in steps if s.get("tool") == "compose_card"]
    held = dict.fromkeys(GATES, 0) | {"fact": 0, "other": 0}
    for step in steps:
        match = DROPPED.match(step.get("note", "")) if step["kind"] == "note" else None
        if not match:
            continue
        reason = match.group(2)
        gate = next((g for g, words in GATES.items() if reason.startswith(words)), None)
        held[gate or ("fact" if reason.startswith("no ") else "other")] += 1
    texts = [
        (component["id"], f"{component['title']}\n{component['text']}")
        for message in card.get("messages", [])
        for component in message.get("updateComponents", {}).get("components", [])
        if "text" in component
    ]
    turns = run["recordings"][ronda]["turns"]
    tokens = card.get("tokens", [])
    return {
        "ronda": ronda,
        "models": sorted({t.get("model", "") for t in turns}),
        "status": card.get("status", "missing"),
        "reason": card.get("reason", ""),
        "blocks": card.get("blocks", []),
        "dropped": card.get("dropped", 0),
        "proposed": len(card.get("blocks", [])) + card.get("dropped", 0),
        "compose_calls": len(compose),
        "invalid_calls": sum(1 for s in compose if s["status"] == "invalid"),
        "held": held,
        "latency_ms": sum(t.get("latency_ms", 0) for t in turns),
        "model_turns": len(turns),
        "tokens_in": sum(t["in"] for t in tokens),
        "tokens_out": sum(t["out"] for t in tokens),
        "cost": _cost(tokens),
        "texts": texts,
        "messages": card.get("messages"),
    }


@pytest.fixture(scope="session")
def reports(run, record) -> list[dict]:
    rows = [_report(run, ronda) for ronda in RONDAS]
    if record:
        _write_results(rows, run)
    return rows


def _rate(part: int, whole: int) -> str:
    return f"{part}/{whole} ({part / whole:.0%})" if whole else "—"


def _write_results(rows: list[dict], run: dict) -> None:
    lines = [
        "# Results: the weekly card the organiser composes",
        "",
        f"Measured {datetime.now():%Y-%m-%d} from Uruguay with `--live --record` on the real "
        f"models (Muse Spark Open on Baseten, Spark 1.3 as fallback, `reasoning_effort: low`). "
        f"Three invented demo rondas in ISO week {WEEK_ID}, the job run once "
        f"(`weekly_card.run_weekly_card`, forced, counts {run['counts']}, wall clock "
        f"{run['wall_s']:.1f} s). Numbers and the cards' kinds only; the texts are in "
        "`fixtures/recorded/`.",
        "",
        "| ronda | model | card | blocks kept | dropped | compose calls (invalid) | "
        "held: emoji / voseo / money / address | no fact / other | turns | latency | "
        "tokens in / out | cost |",
        "|---|---|---|---|---|---|---|---|---|---|---|---|",
    ]
    for r in rows:
        held = r["held"]
        card = r["status"] + (f" ({r['reason']})" if r["reason"] else "")
        lines.append(
            f"| {r['ronda']} | {', '.join(r['models'])} | {card} | "
            f"{', '.join(r['blocks']) or '—'} | {r['dropped']} | "
            f"{r['compose_calls']} ({r['invalid_calls']}) | "
            f"{held['emoji']} / {held['voseo']} / {held['money']} / {held['address']} | "
            f"{held['fact']} / {held['other']} | {r['model_turns']} | "
            f"{r['latency_ms'] / 1000:.1f} s | {r['tokens_in']} / {r['tokens_out']} | "
            f"${r['cost']:.4f} |"
        )
    agent = [r for r in rows if r["status"] == "agent"]
    calls = sum(r["compose_calls"] for r in rows)
    proposed = sum(r["proposed"] for r in rows)
    distinct = len({json.dumps(r["messages"], sort_keys=True) for r in agent})
    per_gate = ", ".join(
        f"{gate} {_rate(proposed - sum(r['held'][gate] for r in rows), proposed)}" for gate in GATES
    )
    lines += [
        "",
        f"- Schema validity: {_rate(calls - sum(r['invalid_calls'] for r in rows), calls)} "
        "`compose_card` calls fitted the catalog.",
        f"- Gate pass rate per gate, over the {proposed} blocks proposed: {per_gate}.",
        f"- Blocks dropped: {sum(r['dropped'] for r in rows)} "
        f"({sum(r['held']['fact'] for r in rows)} for a fact that didn't hold).",
        f"- Fallback to the template: {_rate(len(rows) - len(agent), len(rows))} of the cards.",
        f"- Cards from the model: {len(agent)} of {len(rows)}, {distinct} distinct.",
        f"- Per card: mean latency "
        f"{sum(r['latency_ms'] for r in rows) / len(rows) / 1000:.1f} s, mean cost "
        f"${sum(r['cost'] for r in rows) / len(rows):.4f}.",
        "",
        "Latency is the model turns' own time, tools excluded (the forecast is a stand-in "
        "here). Cost uses $1.25 in / $4.25 out per million tokens for both models (reasoning "
        "tokens are billed as output).",
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
    assert len(agent) >= 2, [(r["ronda"], r["status"], r["reason"]) for r in reports]
    cards = [json.dumps(r["messages"], sort_keys=True) for r in agent]
    assert len(set(cards)) == len(cards)


def test_every_card_logs_its_tokens(reports):
    for report in reports:
        assert report["tokens_in"] > 0, report["ronda"]


@pytest.fixture(scope="module")
def stand_ins() -> dict[str, dict]:
    replay = Replay(STAND_INS)
    run = _run(replay) | {"recordings": replay.recordings}
    return {ronda: _report(run, ronda) for ronda in RONDAS}


def test_the_stand_ins_show_the_gates_and_the_facts(stand_ins):
    assert stand_ins["mate"]["blocks"] == ["rain", "host", "newcomer", "despues"]
    assert stand_ins["mate"]["invalid_calls"] == 0
    assert stand_ins["truco"]["blocks"] == ["rain", "host", "bench"]
    # The fútbol stand-in slips into tú (held by the voseo gate) and names a host the ronda
    # doesn't have (dropped for its fact): nothing is left, so the template shows.
    futbol = stand_ins["futbol5"]
    assert futbol["blocks"] == []
    assert futbol["status"] == "template"
    assert futbol["held"]["voseo"] == 1
    assert futbol["held"]["fact"] == 1
    assert futbol["dropped"] == 2


def test_the_newcomer_the_host_and_the_despues_are_filled_by_code(stand_ins):
    joined = "\n".join(words for _, words in stand_ins["mate"]["texts"])
    assert "Mirta" in joined
    assert "Facu" in joined
    assert "bizcochos en lo de Mirta" in joined
    assert "{anfitrion}" not in joined and "{nuevo}" not in joined
