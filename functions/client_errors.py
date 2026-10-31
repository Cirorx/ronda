"""`report_client_error`: the web app's error log (Crashlytics covers Android and iOS).

The phone already scrubs what it sends (packages/error_reporter); this module checks the shape
again, scrubs again with the same rules, caps every field, rate-limits the caller, and writes one
`client_errors/{id}` per report with `expireAt` 30 days on, which Firestore's TTL policy deletes.

A report never holds a name, a phone number, an email, a transcript, a need, a barrio, a photo
or free text: only where it happened (platform, version, build, flavor, screen, step), what
(an error code, a scrubbed first line and a scrubbed stack), when (server time) and, when
signed in, a salted hash of the uid. The uid comes from the auth token only, never from the
payload. It works signed out (App Check isn't set up), so the caller's quota is keyed by the
hashed uid when there is one, otherwise by the hashed IP; the raw IP is never stored.
"""

import hashlib
import re
from collections.abc import Callable
from datetime import datetime, timedelta

COLLECTION = "client_errors"
QUOTA_COLLECTION = "client_error_quota"
RETENTION = timedelta(days=30)

# One call carries at most this many reports (the app batches up to 10).
MAX_REPORTS_PER_CALL = 10
# Reports one caller may store per clock hour; the app sends at most 20 per session.
HOURLY_LIMIT = 60

PLATFORMS = {"web", "android", "ios"}
FLAVORS = {"development", "production"}

# Longest stored value of each field, in characters.
LIMITS = {
    "appVersion": 32,
    "build": 16,
    "screen": 80,
    "step": 80,
    "code": 120,
    "message": 300,
    "stack": 4000,
}
MAX_STACK_LINES = 40

# The uid hash: the same salt and length as packages/error_reporter's `uidHash`, so a
# Crashlytics user and a client_errors row of the same person match.
UID_SALT = "ronda-client-errors:"
HASH_LENGTH = 16


class ClientErrorRefused(Exception):
    """A call the function turns down, with the callable error code to answer."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


# --- Scrubbing: the same rules as packages/error_reporter/lib/src/scrub.dart ----------------

_URL_QUERY = re.compile(r"(https?://[^\s?#'\"]+)\?[^\s'\"]*")
_EMAIL = re.compile(r"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
_QUOTED = re.compile(r"\"[^\"\n]*\"|'[^'\n]*'|«[^»\n]*»|“[^”\n]*”")
# Firestore and Auth ids: 20+ letters and digits with at least one digit and one letter.
_ID = re.compile(
    r"(?<![A-Za-z0-9_-])(?=[A-Za-z0-9_-]*\d)(?=[A-Za-z0-9_-]*[A-Za-z])[A-Za-z0-9_-]{20,}"
)
# Phone numbers and other long numbers: 8+ characters of digits, spaces, dots, dashes, brackets.
_NUMBER = re.compile(r"\+?\d[\d ().-]{6,}\d")


def scrub(text: str) -> str:
    """`text` with URL queries, emails, quoted text, ids and long numbers replaced."""
    text = _URL_QUERY.sub(r"\1?<query>", text)
    text = _EMAIL.sub("<email>", text)
    text = _QUOTED.sub("<text>", text)
    text = _ID.sub("<id>", text)
    return _NUMBER.sub("<number>", text)


def scrub_message(text: str) -> str:
    """The first line only (a FormatException prints its source on the next), scrubbed."""
    first = text.strip().split("\n", 1)[0] if text else ""
    return scrub(first)[: LIMITS["message"]]


def scrub_stack(text: str) -> str:
    """At most MAX_STACK_LINES lines, scrubbed and capped."""
    lines = text.strip().split("\n")[:MAX_STACK_LINES] if text else []
    return scrub("\n".join(lines))[: LIMITS["stack"]]


def short_hash(value: str) -> str:
    return hashlib.sha256(value.encode()).hexdigest()[:HASH_LENGTH]


def uid_hash(uid: str) -> str:
    return short_hash(UID_SALT + uid)


# --- The call -------------------------------------------------------------------------------


def requester_ip(headers, remote_addr: str | None) -> str:
    """The caller's address: the first `X-Forwarded-For` hop (Cloud Run's front end sets it),
    else the socket's."""
    forwarded = (headers.get("X-Forwarded-For") or "") if headers else ""
    first = forwarded.split(",", 1)[0].strip()
    return first or remote_addr or "unknown"


def _text(value, field: str) -> str:
    if not isinstance(value, str):
        return ""
    return value.strip()[: LIMITS[field]]


def _clean(report) -> dict:
    if not isinstance(report, dict):
        raise ClientErrorRefused("invalid-argument", "each report is an object")
    platform = report.get("platform")
    flavor = report.get("flavor")
    code = scrub(_text(report.get("code"), "code"))
    return {
        "platform": platform if platform in PLATFORMS else "other",
        "flavor": flavor if flavor in FLAVORS else "other",
        "appVersion": scrub(_text(report.get("appVersion"), "appVersion")),
        "build": scrub(_text(report.get("build"), "build")),
        "screen": scrub(_text(report.get("screen"), "screen")),
        "step": scrub(_text(report.get("step"), "step")),
        "code": code or "unknown",
        "message": scrub_message(report.get("message") or "")
        if isinstance(report.get("message"), str)
        else "",
        "stack": scrub_stack(report.get("stack") or "")
        if isinstance(report.get("stack"), str)
        else "",
        "fatal": report.get("fatal") is True,
    }


def reports_from(data) -> list[dict]:
    """The call's reports, checked and scrubbed; refuses anything that isn't 1 to 10 objects."""
    reports = data.get("reports") if isinstance(data, dict) else None
    if not isinstance(reports, list) or not reports:
        raise ClientErrorRefused("invalid-argument", "reports is a non-empty list")
    if len(reports) > MAX_REPORTS_PER_CALL:
        raise ClientErrorRefused(
            "invalid-argument", f"at most {MAX_REPORTS_PER_CALL} reports per call"
        )
    return [_clean(report) for report in reports]


def _take_quota(db, key: str, wanted: int, now: datetime, in_transaction: Callable) -> int:
    """Counts `wanted` reports against this caller's hour and answers how many fit."""
    reference = db.document(f"{QUOTA_COLLECTION}/{key}_{now:%Y%m%d%H}")

    def take(transaction) -> int:
        snapshot = reference.get(transaction=transaction)
        used = (snapshot.to_dict() or {}).get("count", 0) if snapshot.exists else 0
        allowed = max(0, min(wanted, HOURLY_LIMIT - used))
        if allowed:
            transaction.set(
                reference,
                {"count": used + allowed, "expireAt": now + timedelta(hours=2)},
            )
        return allowed

    return in_transaction(db, take)


def _in_transaction(db, function: Callable):
    from google.cloud import firestore

    return firestore.transactional(function)(db.transaction())


def report(
    db,
    data,
    *,
    uid: str | None,
    ip: str,
    now: datetime,
    in_transaction: Callable = _in_transaction,
) -> dict:
    """Stores the call's reports as `client_errors/{id}`; answers how many were kept."""
    reports = reports_from(data)
    hashed_uid = uid_hash(uid) if uid else None
    key = f"u{hashed_uid}" if hashed_uid else f"ip{short_hash(UID_SALT + ip)}"
    allowed = _take_quota(db, key, len(reports), now, in_transaction)
    if not allowed:
        raise ClientErrorRefused("resource-exhausted", "too many error reports this hour")
    batch = db.batch()
    for each in reports[:allowed]:
        fields = {**each, "at": now, "expireAt": now + RETENTION}
        if hashed_uid:
            fields["uidHash"] = hashed_uid
        batch.set(db.collection(COLLECTION).document(), fields)
    batch.commit()
    return {"accepted": allowed}
