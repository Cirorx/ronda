"""The organiser's loop: ask the model, run the tools it calls, hand the results back, until it
answers in words or the step cap stops it.

Baseten doesn't enforce the tools' JSON schemas for Spark Open, so every call is validated with
pydantic (`Toolbox.parse`) before it runs. A call that doesn't fit gets the validation error as
its tool result and the model one more turn; if a call fails again in that turn, the run stops
and the trace says why. The model's words are Markdown-stripped before they are kept (Spark Open
answered in Markdown bold in the smoke test).
"""

import json
import time
from collections.abc import Callable
from dataclasses import dataclass

from organiser import text
from organiser.model import ModelClient, ModelUnavailable
from organiser.tools import Toolbox, ToolError
from organiser.trace import Trace

MAX_STEPS = 12
"""Model turns per run. The rain check takes five to seven (forecast, sunset, last bus, count,
propose, the acta line, the last words); the rest is room for a retry, not a budget."""

DONE = "done"
CAPPED = "capped"
STOPPED = "stopped"
FAILED = "failed"


@dataclass(frozen=True)
class Outcome:
    """How a run ended, and the model's last words (plain text)."""

    status: str
    note: str = ""


def run_agent(
    *,
    model: ModelClient,
    toolbox: Toolbox,
    system: str,
    task: str,
    trace: Trace,
    max_steps: int = MAX_STEPS,
    clock: Callable[[], float] = time.perf_counter,
) -> Outcome:
    """Runs the loop for one task; every turn and tool call lands in `trace` as it happens."""
    messages: list[dict] = [
        {"role": "system", "content": system},
        {"role": "user", "content": task},
    ]
    specs = toolbox.specs()
    retried = False
    for _ in range(max_steps):
        started = clock()
        try:
            turn = model.complete(messages, specs)
        except ModelUnavailable as error:
            trace.step("stop", why=f"el modelo no respondió ({error})", model=model.name)
            return Outcome(FAILED)
        words = text.strip_markdown(turn.content)
        trace.step(
            "model",
            model=turn.model,
            latencyMs=round((clock() - started) * 1000),
            toolCalls=[call.name for call in turn.tool_calls],
            content=words,
        )
        if not turn.tool_calls:
            return Outcome(DONE, words)
        messages.append(turn.message())
        invalid = False
        for call in turn.tool_calls:
            try:
                args = toolbox.parse(call)
            except ToolError as error:
                invalid = True
                trace.step(
                    "tool",
                    tool=call.name,
                    argsSummary=call.arguments[:300],
                    reason="",
                    resultSummary=str(error),
                    status="invalid",
                    latencyMs=0,
                    model=turn.model,
                )
                messages.append(_tool_message(call.id, {"status": "invalid", "error": str(error)}))
                continue
            messages.append(_tool_message(call.id, toolbox.run(call.name, args)))
        if invalid and retried:
            trace.step(
                "stop",
                why="la llamada volvió a venir mal después de un reintento",
                model=turn.model,
            )
            return Outcome(STOPPED)
        retried = invalid
    trace.step("stop", why=f"llegó al tope de {max_steps} pasos", model=model.name)
    return Outcome(CAPPED)


def _tool_message(call_id: str, result: dict) -> dict:
    return {
        "role": "tool",
        "tool_call_id": call_id,
        "content": json.dumps(result, ensure_ascii=False),
    }
