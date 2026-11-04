"""Who must not sit together, and who is out of Ronda (docs/PRODUCT.md § Safety; #71).

Two of the admin's answers to a report ("Contar algo que pasó", reports.py) live here, read by
every path that seats someone:

- `avoid/{uidA}_{uidB}` ([Separarlos]): two people never seated together again. The uids are in
  order, so a pair has one id whoever reported whom. Written by `separate`, deleted by
  `join_again` ([Juntarlos de nuevo]). The solver keeps them apart when it builds a proposal
  (`AVOID_PAIR_APART`); `ronda_members` leaves them out of "Sumar a esta ronda" and refuses to
  add one where the other sits; the bench never offers one a seat in the other's ronda.
  Separating doesn't move anyone: a pair already in one ronda stays (`together`), and the
  card says so.
- `removed/{uid}` ([Sacar de Ronda], removals.py): someone the admin took out. While the
  document exists they are in no proposal, waiting list, bench or "Sumar a esta ronda".

Both are read by the admin only (firestore.rules) and written only here, with the admin SDK.
"""

from datetime import datetime

import rsvp

SEATED = ("active", "paused")
"""Member states that take a seat; `left` doesn't."""


class SafetyError(Exception):
    """A step the callables refuse; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def pair_id(uid_a: str, uid_b: str) -> str:
    """`{uidA}_{uidB}`, the uids in order: one id per pair."""
    first, second = sorted((uid_a, uid_b))
    return f"{first}_{second}"


def avoid_pairs(db) -> list[dict]:
    """Every `avoid/{pairId}` document."""
    return [snapshot.to_dict() or {} for snapshot in db.collection("avoid").stream()]


def apart(db) -> dict[str, set[str]]:
    """Each separated uid with everyone they must not sit with."""
    found: dict[str, set[str]] = {}
    for pair in avoid_pairs(db):
        a, b = pair.get("uidA"), pair.get("uidB")
        if isinstance(a, str) and isinstance(b, str):
            found.setdefault(a, set()).add(b)
            found.setdefault(b, set()).add(a)
    return found


def apart_from(db, uids) -> set[str]:
    """Everyone who must not sit with any of `uids`."""
    pairs = apart(db)
    return set().union(*(pairs.get(uid, set()) for uid in uids))


def removed(db) -> set[str]:
    """Everyone the admin took out of Ronda ([Sacar de Ronda])."""
    return {snapshot.id for snapshot in db.collection("removed").stream()}


def seated_in(db, uid: str) -> dict[str, dict]:
    """The rondas that still meet where `uid` takes a seat, by id: those their
    `users/{uid}/rondas` links name."""
    found = {}
    for link in db.collection(f"users/{uid}/rondas").stream():
        ronda = db.document(f"rondas/{link.id}").get()
        member = db.document(f"rondas/{link.id}/members/{uid}").get()
        if (
            ronda.exists
            and (ronda.to_dict() or {}).get("status") in rsvp.OPEN_STATUSES
            and member.exists
            and (member.to_dict() or {}).get("state", "active") in SEATED
        ):
            found[link.id] = ronda.to_dict() or {}
    return found


def _report(db, data: object) -> tuple[str, dict]:
    report_id = (data if isinstance(data, dict) else {}).get("reportId")
    if not isinstance(report_id, str) or not report_id or "/" in report_id:
        raise SafetyError("invalid-argument", "reportId is required")
    snapshot = db.document(f"reports/{report_id}").get()
    if not snapshot.exists:
        raise SafetyError("not-found", "no such report")
    return report_id, snapshot.to_dict() or {}


def reported(db, data: object) -> tuple[str, dict]:
    """The report `data.reportId` names and its id, when it is about someone in Ronda (not
    "Alguien de afuera")."""
    report_id, report = _report(db, data)
    if not report.get("aboutUid"):
        raise SafetyError("failed-precondition", "the report names nobody in Ronda")
    return report_id, report


def together(db, uid_a: str, uid_b: str) -> dict | None:
    """`{rondaId, line}` of a ronda that still meets where both sit now, if any."""
    shared = set(seated_in(db, uid_a)) & set(seated_in(db, uid_b))
    if not shared:
        return None
    ronda_id = min(shared)
    ronda = db.document(f"rondas/{ronda_id}").get().to_dict() or {}
    return {"rondaId": ronda_id, "line": rsvp.ronda_line(ronda)}


def separate(db, data: object, now: datetime) -> dict:
    """[Separarlos] on report `reportId`: writes `avoid/{pairId}` for its reporter and the
    person it is about, with their first names, the report and, when they sit in one ronda now,
    `together` (they stay there: it counts from the next grouping). Returns `{pairId,
    together}`."""
    report_id, report = reported(db, data)
    a, b = report.get("reporterUid", ""), report["aboutUid"]
    if not a or a == b:
        raise SafetyError("failed-precondition", "the report has no pair to separate")
    names = rsvp._first_names(db, [a, b])
    first, second = sorted((a, b))
    shared = together(db, a, b)
    pair = pair_id(a, b)
    db.document(f"avoid/{pair}").set(
        {
            "uidA": first,
            "uidB": second,
            "nameA": names[first],
            "nameB": names[second],
            "reportId": report_id,
            "together": shared,
            "at": now,
        }
    )
    if shared:
        import first_visit

        # A pair that still sits together is never each other's waiter on a first visit.
        ronda = db.document(f"rondas/{shared['rondaId']}").get().to_dict() or {}
        first_visit.welcome_ronda(db, shared["rondaId"], ronda, now)
    return {"pairId": pair, "together": shared}


def join_again(db, data: object) -> dict:
    """[Juntarlos de nuevo]: deletes `avoid/{pairId}`. Returns `{pairId}`."""
    pair = (data if isinstance(data, dict) else {}).get("pairId")
    if not isinstance(pair, str) or not pair or "/" in pair:
        raise SafetyError("invalid-argument", "pairId is required")
    reference = db.document(f"avoid/{pair}")
    if not reference.get().exists:
        raise SafetyError("not-found", "those two are not separated")
    reference.delete()
    return {"pairId": pair}
