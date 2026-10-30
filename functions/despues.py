"""The después: the optional 20-minute after-spot the host sets each week (docs/PRODUCT.md
§ The weekly loop, "Después"; #47).

"¿Hay después esta semana?" [Esta semana no] [a public place nearby] [En lo de alguien del
grupo]. A home is allowed only here, never for the ronda itself. The host types what there is,
and for a home whose it is and the address; when it isn't the host's own home, that person is
asked first and members see nothing until they say yes. "La ven solo los de este grupo, y la
borramos cuando termina el día."

- `set_despues(db, uid, data, now, send=...)`: the `set_despues` callable's body. The ronda's
  anfitrión or cola, or whoever opens that week (`rondas/{id}.opener`, handoff.py), for the
  upcoming meeting only.
- `answer(db, uid, data, now)`: the `answer_despues` callable's body: the person whose home it
  is says yes or no. A no deletes the address at once.
- `run_despues_sweep(db, now)`: the `despues_sweep` job: once a meeting's day is over (the day a
  rain move postponed it to, when it did), its después loses the address.
- `push_words(db, ronda_id, week)`: what the RSVP push says about it: "Después, si querés,
  bizcochos en lo de Mirta." It names the home, never the address, since a push shows on the
  lock screen.

`rondas/{id}/despues/{isoWeek}` (docs/ARCHITECTURE.md § Data model): week, date, kind (none |
place | home), what, where (a public place, kind place), homeOf and homeName (kind home), address
(kind home, until the day ends), setBy, setByName, status (set | asking | declined), updatedAt,
answeredAt?, addressDeletedAt?. The rules let the ronda's members `get` it once it is `set`, and
whoever set it and whose home it is at any time; no client writes it.

The words pass the organiser's word gates (no emoji, voseo, no money); a public place's also
the address check, and only the home's address skips it. The question to the person whose home
it is goes through the outbox (gates and trace) and never names the home or the address.
"""

from collections.abc import Callable
from datetime import date, datetime

import rsvp
from organiser import gates, outbox
from organiser.trace import Trace

JOB = "despues"

NONE, PLACE, HOME = "none", "place", "home"
KINDS = (NONE, PLACE, HOME)

SET, ASKING, DECLINED = "set", "asking", "declined"

WHAT_LIMIT = 60
WHERE_LIMIT = 60
ADDRESS_LIMIT = 80

MINUTES = 20
"""How long a después lasts, as the card says it ("(20 min)")."""

ASK_TYPE = "despues"
"""`data.type` of the question to the person whose home it is; a tap opens Mi ronda."""


class DespuesError(Exception):
    """A request the callables refuse; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def _path_part(data: dict, field: str) -> str:
    value = data.get(field)
    if not isinstance(value, str) or not value or "/" in value:
        raise DespuesError("invalid-argument", f"{field} is required")
    return value


def _words(value: object, field: str, limit: int, *, home: bool = False) -> str:
    if not isinstance(value, str) or not (value := " ".join(value.split())):
        raise DespuesError("invalid-argument", f"{field} is required")
    if len(value) > limit:
        raise DespuesError("invalid-argument", f"{field} is at most {limit} characters")
    if not (verdict := gates.check_words(value, home=home)).allowed:
        raise DespuesError("failed-precondition", f"{field}: {verdict.reason}")
    return value


def hosts_week(ronda: dict, uid: str, week: str) -> bool:
    """Whether `uid` hosts the meeting of `week`: the anfitrión, the cola, or who took over
    opening it (`opener`)."""
    hosts = ronda.get("hosts") or {}
    opener = ronda.get("opener") or {}
    return uid in (hosts.get("anfitrion"), hosts.get("cola")) or (
        opener.get("week") == week and opener.get("uid") == uid
    )


def _upcoming(db, ronda_id: str, data: dict, now: datetime) -> tuple[dict, date, str]:
    snapshot = db.document(f"rondas/{ronda_id}").get()
    if not snapshot.exists:
        raise DespuesError("not-found", "no such ronda")
    ronda = snapshot.to_dict()
    meeting = rsvp.next_meeting(ronda["slot"]["day"], rsvp.local(now).date())
    week = rsvp.iso_week(meeting)
    if data.get("week") is not None and data.get("week") != week:
        raise DespuesError("failed-precondition", "that meeting has passed")
    return ronda, meeting, week


def set_despues(
    db,
    uid: str,
    data: object,
    now: datetime,
    *,
    send: Callable[[list[dict]], list[str]],
    app_url: str = "",
) -> dict:
    """Sets the upcoming meeting's después from `{rondaId, week?, kind, what?, where?, homeOf?,
    address?}`; returns `{week, status}`.

    `none` says there is none this week. `place` needs what there is and the public place
    (`where`), whose words must not look like a home. `home` needs what there is, `homeOf` (a
    member; the caller when missing) and the address; when it is someone else's home it waits
    for their yes (`asking`) and they get the question. Each call replaces the week's después.
    """
    data = data if isinstance(data, dict) else {}
    ronda_id = _path_part(data, "rondaId")
    ronda, meeting, week = _upcoming(db, ronda_id, data, now)
    members = rsvp.counted(rsvp._members(db, ronda_id))
    if uid not in members or not hosts_week(ronda, uid, week):
        raise DespuesError("permission-denied", "only this week's hosts set the después")
    kind = data.get("kind")
    if kind not in KINDS:
        raise DespuesError("invalid-argument", "kind is none, place or home")
    names = rsvp._first_names(db, [uid])
    despues = {
        "week": week,
        "date": meeting.isoformat(),
        "kind": kind,
        "setBy": uid,
        "setByName": names[uid],
        "status": SET,
        "updatedAt": now,
    }
    if kind == PLACE:
        despues["what"] = _words(data.get("what"), "what", WHAT_LIMIT)
        despues["where"] = _words(data.get("where"), "where", WHERE_LIMIT)
    elif kind == HOME:
        despues["what"] = _words(data.get("what"), "what", WHAT_LIMIT)
        home_of = data.get("homeOf") or uid
        if home_of not in members:
            raise DespuesError("invalid-argument", "homeOf is a member of the ronda")
        despues["homeOf"] = home_of
        despues["homeName"] = rsvp._first_names(db, [home_of])[home_of]
        despues["address"] = _words(data.get("address"), "address", ADDRESS_LIMIT, home=True)
        if home_of != uid:
            despues["status"] = ASKING
    db.document(f"rondas/{ronda_id}/despues/{week}").set(despues)
    if despues["status"] == ASKING:
        _ask(db, ronda_id, ronda, week, despues, now, send, app_url)
    return {"week": week, "status": despues["status"]}


def ask_text(set_by_name: str) -> str:
    """The question to the person whose home it would be: no home, no address."""
    who = set_by_name or "Quien abre"
    return (
        f"{who} pregunta si el después de esta semana puede ser donde vivís. "
        "Lo ves en Ronda y decís si querés."
    )


def _ask(db, ronda_id, ronda, week, despues, now, send, app_url) -> str:
    trace = Trace(db, f"{ronda_id}_{week}_{JOB}", ronda_id=ronda_id, week=week, now=now)
    trace.start(job=JOB, model="", forced=False)
    draft = outbox.prepare(
        db,
        outbox.Recipient(despues["homeOf"], despues["homeName"]),
        title=rsvp.ronda_line(ronda),
        text=ask_text(despues["setByName"]),
        kind=gates.ASK,
        week=week,
        now=now,
    )
    outcome = outbox.deliver(
        db,
        trace,
        draft,
        send=send,
        data={"type": ASK_TYPE, "rondaId": ronda_id, "week": week},
        link=app_url,
        now=now,
    )
    trace.finish("done")
    return outcome


def answer(db, uid: str, data: object, now: datetime) -> dict:
    """The person whose home was asked for says yes (`{rondaId, week, answer: yes}`), and the
    members see it, or no, and the address is deleted at once. Returns `{status}`."""
    from google.cloud.firestore import DELETE_FIELD

    data = data if isinstance(data, dict) else {}
    ronda_id, week = _path_part(data, "rondaId"), _path_part(data, "week")
    value = data.get("answer")
    if value not in rsvp.ANSWERS:
        raise DespuesError("invalid-argument", "answer is yes or no")
    ref = db.document(f"rondas/{ronda_id}/despues/{week}")
    snapshot = ref.get()
    despues = (snapshot.to_dict() or {}) if snapshot.exists else {}
    if despues.get("homeOf") != uid:
        raise DespuesError("permission-denied", "only the person whose home it is answers")
    if despues.get("status") != ASKING:
        raise DespuesError("failed-precondition", "there is nothing to answer")
    if value == rsvp.YES:
        ref.update({"status": SET, "answeredAt": now, "updatedAt": now})
        return {"status": SET}
    ref.update({"status": DECLINED, "address": DELETE_FIELD, "answeredAt": now, "updatedAt": now})
    return {"status": DECLINED}


def push_words(db, ronda_id: str, week: str) -> str:
    """ "Después, si querés, bizcochos en lo de Mirta.": the week's después for the RSVP push,
    once it is set; never the address."""
    snapshot = db.document(f"rondas/{ronda_id}/despues/{week}").get()
    despues = (snapshot.to_dict() or {}) if snapshot.exists else {}
    if despues.get("status") != SET:
        return ""
    if despues.get("kind") == PLACE:
        return f"Después, si querés, {despues['what']} en {despues['where']}."
    if despues.get("kind") == HOME:
        return f"Después, si querés, {despues['what']} en lo de {despues['homeName']}."
    return ""


def run_despues_sweep(db, now: datetime) -> dict:
    """The hourly sweep: deletes the address of every después whose meeting day is over (the
    day a rain move postponed it to, when it did). Sends nothing, so it runs at any hour."""
    from google.cloud.firestore import DELETE_FIELD

    counts = {"deleted": 0}
    today = rsvp.local(now).date()
    for ronda in db.collection("rondas").list_documents():
        for snapshot in db.collection(f"rondas/{ronda.id}/despues").stream():
            despues = snapshot.to_dict() or {}
            if "address" not in despues:
                continue
            week = db.document(f"rondas/{ronda.id}/weeks/{snapshot.id}").get()
            days = [despues.get("date"), (week.to_dict() or {}).get("dateOverride")]
            last = max(date.fromisoformat(day) for day in days if isinstance(day, str))
            if today <= last:
                continue
            db.document(f"rondas/{ronda.id}/despues/{snapshot.id}").update(
                {"address": DELETE_FIELD, "addressDeletedAt": now}
            )
            counts["deleted"] += 1
    return counts
