"""The organiser's two records of a run: the admin's trace and the members' acta.

- `agent_runs/{runId}`: job, rondaId, week, startedAt, endedAt, status (`running`, then `done`,
  `capped`, `stopped`, `failed` or `expired`), model, forced, note (the model's last words,
  Markdown stripped), stepCount and actaCount. Admin-only (firestore.rules).
- `agent_runs/{runId}/steps/{n}` (`001`, `002`…): n, ts, kind, by (who decided it: `code`,
  `model` or `person`, `AUTHORS`) and what that kind carries:
  - `model`: one answer of the model: model, latencyMs, toolCalls (names), content;
  - `tool`: one tool call: tool, argsSummary, reason, model, then resultSummary, latencyMs and
    status (`running` while it runs, then `ok`, `refused`, `held` or `invalid`), so the trace
    shows the call before what it sent;
  - `message`: one message to one person: toRole (`host` | `member`), toName, title, text,
    gate (`allowed` | `blocked`), gateName, gateReason, releaseAt, outcome (`sent`, `held`,
    `unreachable`, `skipped`), latencyMs;
  - `host`: the host's pick, or the deadline passing without one;
  - `answer`: a person's answer to an offer (bench.py): resultSummary;
  - `note`: what code decided or noticed: note;
  - `stop`: why the loop stopped early.
- `acta/{rondaId}/entries/{runId}-{k}`: week, ts, tool, summary (es-419, written in code, like
  the pushes), decidedBy (`agent` | `host`), runId. What the ronda's members read, as
  "Lo que hizo el programa"; the model's own words reach it only through `log_acta`, after
  the gates.

Times are the run's clock (`now`, which the admin may set) plus the seconds since it started,
so a run at a simulated 22:00 reads as 22:00 in both records.
"""

import time
from collections.abc import Callable
from datetime import datetime, timedelta

AGENT = "agent"
HOST = "host"

CODE = "code"
MODEL = "model"
PERSON = "person"
AUTHORS = {"model": MODEL, "tool": MODEL, "host": PERSON, "answer": PERSON}
"""Who decided each kind of step, so a reader of the trace tells the model's judgement from the
rules in code. A `tool` step is the model's: it chose to call it and wrote the arguments; what
the tool does with them is code, and its result line says so. A host's pick and a person's
answer are a person's. Every other kind (`message`, through the gates; `note`; `stop`) is
code's. A step may say otherwise with `by=`."""


class Trace:
    """Writes one run's steps and acta lines as they happen."""

    def __init__(
        self,
        db,
        run_id: str,
        *,
        ronda_id: str,
        week: str,
        now: datetime,
        clock: Callable[[], float] = time.perf_counter,
    ) -> None:
        self.run_id = run_id
        self.ronda_id = ronda_id
        self.week = week
        self._db = db
        self._now = now
        self._clock = clock
        self._started = clock()
        self._ref = db.document(f"agent_runs/{run_id}")
        snapshot = self._ref.get()
        run = (snapshot.to_dict() or {}) if snapshot.exists else {}
        self._steps = int(run.get("stepCount", 0))
        self._acta = int(run.get("actaCount", 0))

    @property
    def steps(self) -> int:
        """How many steps the run has so far."""
        return self._steps

    def at(self) -> datetime:
        """The run's clock now."""
        return self._now + timedelta(seconds=self._clock() - self._started)

    def start(self, *, job: str, model: str, forced: bool) -> None:
        """Marks the run as running (again, when a failed run is retried: its steps stay)."""
        self._ref.set(
            {
                "job": job,
                "rondaId": self.ronda_id,
                "week": self.week,
                "startedAt": self._now,
                "status": "running",
                "model": model,
                "forced": forced,
                "stepCount": self._steps,
                "actaCount": self._acta,
            },
            merge=True,
        )

    def step(self, kind: str, **fields) -> int:
        """Writes the next step, labelled with who decided it (`AUTHORS`, or `by=`), and returns
        its number."""
        self._steps += 1
        fields.setdefault("by", AUTHORS.get(kind, CODE))
        self._db.document(f"agent_runs/{self.run_id}/steps/{self._steps:03d}").set(
            {"n": self._steps, "ts": self.at(), "kind": kind, **fields}
        )
        self._ref.set({"stepCount": self._steps}, merge=True)
        return self._steps

    def update(self, n: int, **fields) -> None:
        """Adds what step `n` came to, once it is known."""
        self._db.document(f"agent_runs/{self.run_id}/steps/{n:03d}").update(fields)

    def acta(self, tool: str, summary: str, decided_by: str = AGENT) -> None:
        """Adds one line to the ronda's acta."""
        self._acta += 1
        self._db.document(f"acta/{self.ronda_id}/entries/{self.run_id}-{self._acta:03d}").set(
            {
                "week": self.week,
                "ts": self.at(),
                "tool": tool,
                "summary": summary,
                "decidedBy": decided_by,
                "runId": self.run_id,
            }
        )
        self._ref.set({"actaCount": self._acta}, merge=True)

    def finish(self, status: str, note: str = "") -> None:
        """Marks the run as over."""
        self._ref.set({"status": status, "endedAt": self.at(), "note": note}, merge=True)
