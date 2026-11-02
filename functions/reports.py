"""Contar algo que pasó: a member tells Ronda about something that happened, and the admin reads
it (docs/PRODUCT.md § Safety; #71).

"Contá qué pasó. Lo lee una persona, no un programa. La otra persona no se entera de que
contaste." The report goes to the server and only the admin reads it; the reporter keeps a
receipt that says no more than that it arrived. The person it is about sees nothing: no
notice, no message and no document names the reporter to them.

- `people(db, uid)` (`report_people`): who "¿Con quién?" offers: the other members of the
  caller's rondas by first name. "Alguien de afuera" is the app's.
- `file(db, uid, data, now)` (`send_report`): `{text, tags, aboutUid}`; `aboutUid` is `""`
  for "Alguien de afuera".
- `add(db, uid, data, now)` (`add_to_report`): more words on the caller's own report.
- `withdraw(db, uid, data, now)` ([Retirar], `withdraw_report`): the report stays in the
  admin's queue, marked «retirado».
- `review(db, data, now)` (`review_report`, admin): `read`, [Archivar] or [Reabrir].

Where things live (docs/ARCHITECTURE.md § Data model):
- `reports/{id}`: reporterUid, reporterName, aboutUid (`""` for someone from outside),
  aboutName, rondaId and rondaLine (the ronda they share, else the reporter's; `""` for none),
  tags, text, additions [{text, at}], status (open | archived), withdrawnAt (null until
  [Retirar]), unread (the Admin tab's count: set by a new report, an addition and a withdrawal;
  cleared when the admin reads or archives it), createdAt, updatedAt. Read by the admin only.
- `users/{uid}/reports/{id}`: the reporter's receipt, read by that person only: status (open |
  withdrawn) and createdAt. It never says what the admin did: telling the reporter the outcome
  is out of #71, so archiving changes nothing here, and they may still add to it.

Nothing here logs the words. Nothing here sends anything: the admin's unread count is the
alert (no push to the admin on a new report).
"""

from datetime import datetime, timedelta

import rsvp

TAGS = ("askedForMoney", "bothered", "romantic", "minor", "privatePlace", "other")
"""The spec's tags, in its order: "Me pidió plata", "Me molestó", "Insistió con algo
romántico", "Había un menor", "Quiso ir a un lugar privado", "Otra cosa"."""

TEXT_LIMIT = 2000
"""How long the words of a report, or of one addition, may be."""
ADDITIONS_LIMIT = 20
"""How many times a report may be added to."""
DAILY_LIMIT = 5
"""How many reports one person may send in 24 hours."""

OPEN, ARCHIVED = "open", "archived"
"""`reports/{id}.status`."""
WITHDRAWN = "withdrawn"
"""The receipt's status after [Retirar]; the report itself keeps its status and gets
`withdrawnAt`."""

READ, ARCHIVE, REOPEN = "read", "archive", "reopen"
"""What `review` does."""


class ReportError(Exception):
    """A request the callables refuse; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def _data(data: object) -> dict:
    return data if isinstance(data, dict) else {}


def _words(value: object, *, required: bool) -> str:
    if value is None and not required:
        return ""
    if not isinstance(value, str):
        raise ReportError("invalid-argument", "text is a string")
    words = value.strip()
    if len(words) > TEXT_LIMIT:
        raise ReportError("invalid-argument", f"text is at most {TEXT_LIMIT} characters")
    if required and not words:
        raise ReportError("invalid-argument", "text is required")
    return words


def _tags(value: object) -> list[str]:
    if value is None:
        return []
    if not isinstance(value, list) or not all(tag in TAGS for tag in value):
        raise ReportError("invalid-argument", f"tags are some of {', '.join(TAGS)}")
    return [tag for tag in TAGS if tag in value]


def _report_id(data: dict) -> str:
    report_id = data.get("reportId")
    if not isinstance(report_id, str) or not report_id or "/" in report_id:
        raise ReportError("invalid-argument", "reportId is required")
    return report_id


def _rondas(db, uid: str) -> list[str]:
    """The rondas `uid` has a link to, in id order."""
    return sorted(link.id for link in db.collection(f"users/{uid}/rondas").stream())


def people(db, uid: str) -> dict:
    """`{people: [{uid, firstName, rondaId}]}`: the other members of the caller's rondas, once
    each, by first name; who left a ronda still counts, since what happened may be why."""
    found: dict[str, str] = {}
    for ronda_id in _rondas(db, uid):
        for other in rsvp._members(db, ronda_id):
            if other != uid:
                found.setdefault(other, ronda_id)
    names = rsvp._first_names(db, found)
    return {
        "people": [
            {"uid": other, "firstName": names[other], "rondaId": found[other]}
            for other in sorted(found, key=lambda u: (names[u], u))
            if names[other]
        ]
    }


def _ronda(db, uid: str, about: str) -> tuple[str, str]:
    """The id and line of the ronda the report is about: the one the two share, else the
    reporter's own; `("", "")` for none."""
    mine = _rondas(db, uid)
    shared = [ronda_id for ronda_id in mine if about and ronda_id in set(_rondas(db, about))]
    ronda_id = (shared or mine or [""])[0]
    if not ronda_id:
        return "", ""
    snapshot = db.document(f"rondas/{ronda_id}").get()
    return ronda_id, rsvp.ronda_line(snapshot.to_dict() or {}) if snapshot.exists else ""


def file(db, uid: str, data: object, now: datetime) -> dict:
    """Saves a report from `uid`: `{text, tags, aboutUid}`, some words or at least one tag,
    about another member of their rondas or (`aboutUid: ""`) someone from outside. Writes the
    report and the reporter's receipt; returns `{reportId}`."""
    data = _data(data)
    tags = _tags(data.get("tags"))
    text = _words(data.get("text"), required=not tags)
    about = data.get("aboutUid", "")
    if not isinstance(about, str):
        raise ReportError("invalid-argument", "aboutUid is a string")
    names = {person["uid"]: person["firstName"] for person in people(db, uid)["people"]}
    if about and about not in names:
        raise ReportError("invalid-argument", "aboutUid is someone from your ronda, or ''")
    since = now - timedelta(days=1)
    recent = [
        receipt
        for receipt in db.collection(f"users/{uid}/reports").stream()
        if (receipt.to_dict() or {}).get("createdAt", since) > since
    ]
    if len(recent) >= DAILY_LIMIT:
        raise ReportError("resource-exhausted", "too many reports today")
    ronda_id, line = _ronda(db, uid, about)
    reference = db.collection("reports").document()
    reference.set(
        {
            "reporterUid": uid,
            "reporterName": rsvp._first_names(db, [uid])[uid],
            "aboutUid": about,
            "aboutName": names.get(about, ""),
            "rondaId": ronda_id,
            "rondaLine": line,
            "tags": tags,
            "text": text,
            "additions": [],
            "status": OPEN,
            "withdrawnAt": None,
            "unread": True,
            "createdAt": now,
            "updatedAt": now,
        }
    )
    db.document(f"users/{uid}/reports/{reference.id}").set({"status": OPEN, "createdAt": now})
    return {"reportId": reference.id}


def _own(db, uid: str, data: dict) -> tuple:
    """The caller's own report that is still theirs to change (not withdrawn): its reference,
    fields and receipt."""
    report_id = _report_id(data)
    reference = db.document(f"reports/{report_id}")
    snapshot = reference.get()
    report = (snapshot.to_dict() or {}) if snapshot.exists else {}
    if report.get("reporterUid") != uid:
        raise ReportError("not-found", "no such report of yours")
    if report.get("withdrawnAt") is not None:
        raise ReportError("failed-precondition", "the report was withdrawn")
    return reference, report, db.document(f"users/{uid}/reports/{report_id}")


def add(db, uid: str, data: object, now: datetime) -> dict:
    """Adds `{reportId, text}` to the caller's own report. The admin sees it as unread again;
    an archived report goes back to Abiertos. Returns `{reportId}`."""
    data = _data(data)
    reference, report, _ = _own(db, uid, data)
    text = _words(data.get("text"), required=True)
    additions = list(report.get("additions", []))
    if len(additions) >= ADDITIONS_LIMIT:
        raise ReportError("resource-exhausted", "the report can't take more")
    reference.update(
        {
            "additions": [*additions, {"text": text, "at": now}],
            "status": OPEN,
            "unread": True,
            "updatedAt": now,
        }
    )
    return {"reportId": reference.id}


def withdraw(db, uid: str, data: object, now: datetime) -> dict:
    """[Retirar] on the caller's own report: it stays in the admin's queue marked «retirado»
    (unread, so the admin sees it was taken back), and the receipt says withdrawn. Returns
    `{reportId}`."""
    reference, _, receipt = _own(db, uid, _data(data))
    reference.update({"withdrawnAt": now, "unread": True, "updatedAt": now})
    receipt.set({"status": WITHDRAWN}, merge=True)
    return {"reportId": reference.id}


def review(db, data: object, now: datetime) -> dict:
    """The admin on report `reportId`: `action` `read` (opened it), `archive` ([Archivar]) or
    `reopen` ([Reabrir]). Returns `{reportId, status}`."""
    data = _data(data)
    report_id = _report_id(data)
    action = data.get("action")
    changes = {
        READ: {"unread": False},
        ARCHIVE: {"status": ARCHIVED, "unread": False},
        REOPEN: {"status": OPEN},
    }.get(action)
    if changes is None:
        raise ReportError("invalid-argument", "action is read, archive or reopen")
    reference = db.document(f"reports/{report_id}")
    snapshot = reference.get()
    if not snapshot.exists:
        raise ReportError("not-found", "no such report")
    reference.update({**changes, "updatedAt": now})
    return {"reportId": report_id, "status": changes.get("status", snapshot.to_dict()["status"])}
