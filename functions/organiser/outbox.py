"""One message from the organiser to one person: composed, gated, sent and recorded.

`prepare` adds the introduction to a person's first message and runs every gate; `deliver`
sends an allowed draft to each of the person's phones, or records it as held ("Frenado") with
the gate's reason. Either way the trace gets one `message` step. Nothing is sent before the
gates pass, so a caller can check the verdict before it writes anything else.

`users/{uid}/private/agent` remembers, for the gates, when the person was introduced and which
weeks' routine message they had: `{introducedAt, routine: {isoWeek: at}}`. No client reads it.

Payloads follow the RSVP push (docs/STACK.md § Push): Android gets data only, which the phone
draws; web a notification that opens `link`; iPhones are skipped until the Apple Developer
Program exists. No address goes into a push. Logs carry counts only.
"""

from dataclasses import dataclass
from datetime import datetime

import rsvp
from organiser import gates
from organiser.trace import Trace

HOST = "host"
MEMBER = "member"


@dataclass(frozen=True)
class Recipient:
    """Who a message is for: their uid, first name and role in the ronda."""

    uid: str
    first_name: str
    role: str = MEMBER


@dataclass(frozen=True)
class Draft:
    """A message ready to go, and what the gates said about it."""

    recipient: Recipient
    title: str
    text: str
    """What the person reads, with the introduction when it is their first message."""
    kind: str
    week: str
    verdict: gates.Verdict
    introduced: bool


def _history_ref(db, uid: str):
    return db.document(f"users/{uid}/private/agent")


def prepare(
    db,
    recipient: Recipient,
    *,
    title: str,
    text: str,
    kind: str,
    week: str,
    now: datetime,
    place: gates.Place | None = None,
    routine_sent: bool = False,
) -> Draft:
    """Composes `text` for `recipient` and runs the gates. `routine_sent` says the ronda's
    routine message for `week` (the RSVP push) already went out."""
    snapshot = _history_ref(db, recipient.uid).get()
    history = (snapshot.to_dict() or {}) if snapshot.exists else {}
    introduced = bool(history.get("introducedAt"))
    routine_used = routine_sent or week in history.get("routine", {})
    if not introduced:
        text = f"{gates.introduction(recipient.first_name)} {text}"
    verdict = gates.check(
        gates.Outgoing(
            title=title,
            text=text,
            kind=kind,
            introduced=introduced,
            routine_used=routine_used,
            place=place,
        ),
        now,
    )
    return Draft(recipient, title, text, kind, week, verdict, introduced)


def messages(tokens: list[tuple[str, str]], title: str, body: str, data: dict, link: str) -> list:
    """One FCM HTTP v1 message dict per `(token, platform)`; `data` values are strings."""
    out = []
    for token, platform in tokens:
        if platform == "android":
            out.append(
                {
                    "token": token,
                    "data": {**data, "title": title, "body": body},
                    "android": {"priority": "HIGH"},
                }
            )
        elif platform == "web":
            out.append(
                {
                    "token": token,
                    "notification": {"title": title, "body": body},
                    "webpush": {"fcm_options": {"link": link}},
                }
            )
    return out


def deliver(
    db,
    trace: Trace,
    draft: Draft,
    *,
    send,
    data: dict,
    link: str,
    now: datetime,
) -> str:
    """Sends `draft` if the gates allowed it, and records the outcome in the trace:
    `sent` (at least one phone took it), `held` (a gate stopped it), `unreachable` (no phone,
    or every one failed) or `skipped` (the functions emulator sends nothing)."""
    recipient, verdict = draft.recipient, draft.verdict
    fields = {
        "toRole": recipient.role,
        "toName": recipient.first_name,
        "title": draft.title,
        "text": draft.text,
        "gate": "allowed" if verdict.allowed else "blocked",
        "gateName": verdict.gate,
        "gateReason": verdict.reason,
        "releaseAt": verdict.release_at,
    }
    if not verdict.allowed:
        trace.step("message", **fields, outcome="held")
        return "held"
    tokens = rsvp._tokens(db, recipient.uid)
    batch = messages(tokens, draft.title, draft.text, data, link)
    outcomes = send(batch) if batch else []
    for message, outcome in zip(batch, outcomes, strict=True):
        if outcome == "unregistered":
            db.document(f"users/{recipient.uid}/tokens/{message['token']}").delete()
    if "ok" in outcomes:
        outcome = "sent"
        record: dict = {}
        if not draft.introduced:
            record["introducedAt"] = now
        if draft.kind == gates.ROUTINE:
            record["routine"] = {draft.week: now}
        if record:
            _history_ref(db, recipient.uid).set(record, merge=True)
    elif outcomes and all(outcome == "skipped" for outcome in outcomes):
        outcome = "skipped"
    else:
        outcome = "unreachable"
    trace.step("message", **fields, outcome=outcome)
    return outcome
