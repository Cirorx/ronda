"""¿Alguien se suma?: a member opens their small plan to their ronda (docs/PRODUCT.md § Algo
chico esta semana, "¿Alguien se suma?"; #57).

The plan itself stays on the phone (#56). Only when the member turns on "Avisarle a la ronda"
does its text come here, under the ronda, so the others see one line the next time they open
Mi ronda ("Ana propone: …") and can say [Me sumo]. Nothing is pushed, and nothing is ever shown
as failed, counted or ranked: the author sees only the first names of whoever said they would
come, and when nobody does, nothing at all.

Fixed rules in code (`check_plan`), then Muse Spark 1.3 (`SparkPlan`) as one more reader:
- the plan is ahead of now and within `WINDOW_DAYS`, and its hour is 09:00 to 21:00 (`TIME`);
- the words pass the organiser's word gates (no emoji, voseo, no money, no home or address) and
  the small-plan filter's topics (health, a diet, money, another person), and carry no phone
  number;
- a call or an afternoon without the phone has no place to join, so it isn't shared;
- Spark 1.3 confirms the place is public and there is no address, phone number or money.
A plan that fails any of them is held with a `reason` the app words plainly ("En ese horario no
se puede compartir…"), and stays private on the phone.

Documents (docs/ARCHITECTURE.md § Data model):
- `rondas/{id}/shared_plans/{authorUid}` (no client reads it): author, firstName, activity,
  place, kind, date, time, startsAt, sharedAt, joined {uid: {firstName, at}}. One per author:
  sharing again replaces it and its joins.
- `rondas/{id}/plan_cards/{uid}` (that member only, `get`): plans [{id (the author's uid),
  firstName, activity, place, kind, date, time, joined}] (the others' plans still ahead, with
  whether this member joined) and mine {activity, place, kind, date, time, joined [firstName]}
  | none, plus updatedAt. A member with neither has no card. A card never holds a joiner's uid
  and never shows one member who joined to another.

The callables rewrite the cards of the whole ronda (`refresh`), so a card is always built from
the plans as they are. The hourly `shared_plans` job deletes a plan once its time has passed
(and the plans of anyone who left the ronda) and refreshes; the app also hides a plan whose
time has passed, since the job lags by up to an hour.
"""

import logging
import re
from datetime import UTC, date, datetime, time, timedelta
from enum import StrEnum
from typing import Any, Protocol

from pydantic import BaseModel, ConfigDict

import rsvp
import small_plans
import voice_signup as voice
from organiser import gates

log = logging.getLogger(__name__)

WORDS_MODEL = voice.FIELDS_MODEL

# --- Reasons, limits ----------------------------------------------------------------------

PAST = "past"
HOURS = "time"
WORDS = "words"
MONEY = "money"
ADDRESS = "address"
PHONE = "phone"
PLACE = "place"
OTHER = "other"
"""Why a plan was held, sent to the app as the error's `details.reason`."""

WINDOW_DAYS = small_plans.WINDOW_DAYS + 1
"""A plan is shared at most this many days ahead (the week a plan is made for, and one more)."""
FIRST_HOUR, LAST_HOUR = time(9, 0), time(21, 0)
"""The hours a shared plan may be at: the gates' quiet hours, 09:00 to 21:00 inclusive."""
MAX_ACTIVITY, MAX_PLACE = 120, small_plans.MAX_PLACE
PRIVATE_KINDS = ("call", "noPhone")
"""Plans with nowhere to join: they are never shared."""

_PHONE = re.compile(r"\d(?:[\s.-]?\d){6,}")
"""Seven digits in a row, with the spaces, dots and dashes a number is written with."""
_DATE = re.compile(r"^\d{4}-\d{2}-\d{2}$")
_HOUR = re.compile(r"^(?:[01]\d|2[0-3]):[0-5]\d$")


class SharedPlanError(Exception):
    """A call the callables refuse: `code` is the callable's error code and `reason`, when a
    plan was held, says why."""

    def __init__(self, code: str, message: str, reason: str | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.reason = reason


def _held(reason: str) -> SharedPlanError:
    return SharedPlanError("failed-precondition", f"held: {reason}", reason)


# --- The checks ----------------------------------------------------------------------------


def starts_at(on: str, at: str) -> datetime:
    """The moment of a plan on `on` (`YYYY-MM-DD`) at `at` (`HH:MM`), Montevideo time. Raises
    `ValueError` for either not being one."""
    if not _DATE.match(on) or not _HOUR.match(at):
        raise ValueError("not a date and a time")
    return datetime.combine(date.fromisoformat(on), time.fromisoformat(at), tzinfo=rsvp.MONTEVIDEO)


_GATE_REASONS = {"emoji": WORDS, "voseo": WORDS, "money": MONEY, "public_place": ADDRESS}


def check_plan(*, activity: str, place: str, kind: str, begins: datetime, now: datetime) -> str:
    """The reason a plan may not be shared, or "" when code finds none. Spark 1.3 reads it
    after this (`SparkPlan`)."""
    if kind in PRIVATE_KINDS:
        return PLACE
    here = rsvp.local(now)
    if begins <= here or begins.date() > here.date() + timedelta(days=WINDOW_DAYS):
        return PAST
    if not FIRST_HOUR <= begins.timetz().replace(tzinfo=None) <= LAST_HOUR:
        return HOURS
    words = f"{activity}\n{place}".strip()
    if _PHONE.search(words):
        return PHONE
    if not place:
        return PLACE
    if found := small_plans.topic(words):
        return MONEY if found == "money" else OTHER
    verdict = gates.check_words(words)
    if not verdict.allowed:
        return _GATE_REASONS.get(verdict.gate, WORDS)
    return ""


class PlanReason(StrEnum):
    OK = "ok"
    NOT_PUBLIC = "place"
    ADDRESS = "address"
    PHONE = "phone"
    MONEY = "money"
    OTHER = "other"


class PlanVerdict(BaseModel):
    """Spark 1.3's strict answer about the plan's words."""

    model_config = ConfigDict(extra="forbid")
    allowed: bool
    reason: PlanReason


PLAN_INSTRUCTIONS = (
    "Revisás planes chicos que un vecino de Ciudad de la Costa, Uruguay, quiere compartir con "
    "su ronda de vecinos: qué quiere hacer y dónde, escrito en español o en inglés. Respondé "
    "allowed=false si el plan no nombra un lugar público (una plaza, una rambla, una feria, "
    "una biblioteca, una esquina o un comercio están bien; una casa, un departamento o "
    "'mi casa' no), si da una dirección con número de puerta, si incluye un número de "
    "teléfono, si menciona plata o precios, o si nombra o describe a una persona o tiene algo "
    "ofensivo. reason: ok, place (el lugar no es público o no hay), address, phone, money u "
    "other."
)

_REASONS = {
    PlanReason.NOT_PUBLIC: PLACE,
    PlanReason.ADDRESS: ADDRESS,
    PlanReason.PHONE: PHONE,
    PlanReason.MONEY: MONEY,
    PlanReason.OTHER: OTHER,
}


class PlanChecker(Protocol):
    """Muse Spark 1.3: the reason the plan may not be shown to the ronda, or "" for none."""

    def reason(self, line: str) -> str: ...


class SparkPlan:
    """`PlanChecker` on the Meta Model API's strict structured output, at low reasoning
    effort."""

    def __init__(self, client: Any) -> None:
        self._client = client  # an openai.OpenAI on META_BASE

    def reason(self, line: str) -> str:
        try:
            response = self._client.chat.completions.parse(
                model=WORDS_MODEL,
                response_format=PlanVerdict,
                reasoning_effort="low",
                messages=[
                    {"role": "system", "content": PLAN_INSTRUCTIONS},
                    {"role": "user", "content": line},
                ],
            )
        except Exception as error:  # the SDK's errors share no useful base with httpx's
            raise voice.ModelUnavailable(type(error).__name__) from error
        verdict = response.choices[0].message.parsed
        if verdict is None:
            raise voice.ModelUnavailable("spark: no verdict")
        if verdict.allowed and verdict.reason == PlanReason.OK:
            return ""
        return _REASONS.get(verdict.reason, OTHER)


# --- Documents -----------------------------------------------------------------------------


def _plans_ref(db, ronda_id: str):
    return db.collection(f"rondas/{ronda_id}/shared_plans")


def _plan_ref(db, ronda_id: str, author: str):
    return db.document(f"rondas/{ronda_id}/shared_plans/{author}")


def _card_ref(db, ronda_id: str, uid: str):
    return db.document(f"rondas/{ronda_id}/plan_cards/{uid}")


def _left(member: dict | None) -> bool:
    return member is None or member.get("state") == "left"


def _live(plans: dict[str, dict], members: dict[str, dict], now: datetime) -> dict[str, dict]:
    """The plans still ahead whose author is still in the ronda."""
    return {
        author: plan
        for author, plan in plans.items()
        if plan["startsAt"] > now and not _left(members.get(author))
    }


def build_card(uid: str, plans: dict[str, dict], members: dict[str, dict]) -> dict | None:
    """What member `uid` reads: the others' plans with whether they joined, their own plan with
    the first names of who joined it, or `None` when they have neither. Never a joiner's uid."""
    ordered = sorted(plans.items(), key=lambda item: (item[1]["startsAt"], item[0]))
    others = [
        {
            "id": author,
            "firstName": plan["firstName"],
            "activity": plan["activity"],
            "place": plan["place"],
            "kind": plan["kind"],
            "date": plan["date"],
            "time": plan["time"],
            "joined": uid in plan["joined"],
        }
        for author, plan in ordered
        if author != uid
    ]
    own = plans.get(uid)
    mine = None
    if own is not None:
        names = [
            who["firstName"]
            for who in sorted(own["joined"].values(), key=lambda who: who["at"])
            if not _left(members.get(who["uid"]))
        ]
        mine = {
            "activity": own["activity"],
            "place": own["place"],
            "kind": own["kind"],
            "date": own["date"],
            "time": own["time"],
            "joined": names,
        }
    if not others and mine is None:
        return None
    return {"plans": others, "mine": mine}


def _stored(db, ronda_id: str) -> dict[str, dict]:
    stored = {}
    for snapshot in _plans_ref(db, ronda_id).stream():
        plan = snapshot.to_dict() or {}
        joined = {uid: {**who, "uid": uid} for uid, who in (plan.get("joined") or {}).items()}
        stored[snapshot.id] = {**plan, "joined": joined}
    return stored


def refresh(db, ronda_id: str, now: datetime) -> int:
    """Rewrites every member's card from the plans as they are, and deletes the cards that no
    longer hold anything. Returns how many cards there are."""
    members = rsvp._members(db, ronda_id)
    plans = _live(_stored(db, ronda_id), members, now)
    written = set()
    for uid, member in members.items():
        if _left(member):
            continue
        if (card := build_card(uid, plans, members)) is not None:
            _card_ref(db, ronda_id, uid).set({**card, "updatedAt": now})
            written.add(uid)
    for snapshot in db.collection(f"rondas/{ronda_id}/plan_cards").stream():
        if snapshot.id not in written:
            _card_ref(db, ronda_id, snapshot.id).delete()
    return len(written)


# --- The hourly job ------------------------------------------------------------------------


def run_shared_plans(db, now: datetime) -> dict:
    """The hourly job (`jobs.JOBS["shared_plans"]`): refreshes every ronda holding a shared plan
    and deletes the plans whose time has passed or whose author left. Sends nothing. Returns
    counts."""
    counts = {"rondas": 0, "deleted": 0, "cards": 0}
    for snapshot in db.collection("rondas").stream():
        stored = _stored(db, snapshot.id)
        if not stored:
            continue
        counts["rondas"] += 1
        # Cards first: if the job stops between the two, the next hour finds the plans again.
        counts["cards"] += refresh(db, snapshot.id, now)
        live = _live(stored, rsvp._members(db, snapshot.id), now)
        for author in stored.keys() - live.keys():
            _plan_ref(db, snapshot.id, author).delete()
            counts["deleted"] += 1
    return counts


# --- The callables -------------------------------------------------------------------------


def _part(data: dict, name: str) -> str:
    value = data.get(name)
    if not isinstance(value, str) or not value or "/" in value:
        raise SharedPlanError("invalid-argument", f"{name} is required")
    return value


def _line(data: dict, name: str, limit: int, *, required: bool) -> str:
    value = data.get(name, "")
    if not isinstance(value, str):
        raise SharedPlanError("invalid-argument", f"{name} is text")
    words = " ".join(value.split())
    if (required and not words) or len(words) > limit or "\n" in value:
        raise SharedPlanError("invalid-argument", f"{name} is one line of up to {limit}")
    return words


def _member(db, ronda_id: str, uid: str) -> dict:
    """The caller's profile, once they are a member of this ronda (not left) with a first name."""
    member = db.document(f"rondas/{ronda_id}/members/{uid}").get()
    if not member.exists or _left(member.to_dict() or {}):
        raise SharedPlanError("permission-denied", "not a member of this ronda")
    user = db.document(f"users/{uid}").get().to_dict() or {}
    if not user.get("firstName"):
        raise SharedPlanError("failed-precondition", "no first name yet")
    return user


def share(*, uid: str, data: object, db, checker: PlanChecker, now: datetime) -> dict:
    """The `share_small_plan` callable, `{rondaId, activity, place?, kind, date, time}`: opens
    the caller's plan to their ronda unless a check holds it (`SharedPlanError` with the
    reason). A plan the caller shared before is replaced, and its joins with it."""
    data = data if isinstance(data, dict) else {}
    ronda_id = _part(data, "rondaId")
    activity = _line(data, "activity", MAX_ACTIVITY, required=True)
    place = _line(data, "place", MAX_PLACE, required=False)
    kind = data.get("kind")
    if kind not in small_plans.KINDS:
        raise SharedPlanError("invalid-argument", "kind is a small plan's kind")
    try:
        begins = starts_at(str(data.get("date")), str(data.get("time")))
    except ValueError as error:
        raise SharedPlanError(
            "invalid-argument", "date and time are YYYY-MM-DD and HH:MM"
        ) from error
    user = _member(db, ronda_id, uid)
    if not user.get("terms"):
        raise SharedPlanError("failed-precondition", "accept the terms first")
    if reason := check_plan(activity=activity, place=place, kind=kind, begins=begins, now=now):
        raise _held(reason)
    if reason := checker.reason(f"{activity}\n{place}".strip()):
        raise _held(reason)
    _plan_ref(db, ronda_id, uid).set(
        {
            "author": uid,
            "firstName": user["firstName"],
            "activity": activity,
            "place": place,
            "kind": kind,
            "date": data["date"],
            "time": data["time"],
            "startsAt": begins.astimezone(UTC),
            "sharedAt": now,
            "joined": {},
        }
    )
    refresh(db, ronda_id, now)
    log.info("share_small_plan %s: shared, %d chars", ronda_id, len(activity) + len(place))
    return {"status": "shared"}


def withdraw(db, uid: str, data: object, now: datetime) -> dict:
    """`withdraw_small_plan {rondaId}`: the author takes their plan back, and with it every
    "Me sumo". Withdrawing what isn't shared is fine."""
    data = data if isinstance(data, dict) else {}
    ronda_id = _part(data, "rondaId")
    _plan_ref(db, ronda_id, uid).delete()
    refresh(db, ronda_id, now)
    return {"status": "withdrawn"}


def join(db, uid: str, data: object, now: datetime) -> dict:
    """`join_small_plan {rondaId, authorUid}`: "Me sumo" on another member's plan still ahead.
    Joining twice is one join."""
    data = data if isinstance(data, dict) else {}
    ronda_id, author = _part(data, "rondaId"), _part(data, "authorUid")
    if author == uid:
        raise SharedPlanError("invalid-argument", "it is your own plan")
    first_name = _member(db, ronda_id, uid)["firstName"]
    ref = _plan_ref(db, ronda_id, author)

    def record(transaction) -> None:
        snapshot = ref.get(transaction=transaction)
        plan = snapshot.to_dict() if snapshot.exists else None
        if plan is None or plan["startsAt"] <= now:
            raise SharedPlanError("failed-precondition", "that plan is over")
        joined = dict(plan.get("joined") or {})
        if uid not in joined:
            joined[uid] = {"firstName": first_name, "at": now}
            transaction.update(ref, {"joined": joined})

    rsvp._in_transaction(db, record)
    refresh(db, ronda_id, now)
    return {"status": "joined"}


def leave(db, uid: str, data: object, now: datetime) -> dict:
    """`leave_small_plan {rondaId, authorUid}`: a member takes back their "Me sumo". Leaving
    what they hadn't joined, or a plan that is gone, is fine."""
    data = data if isinstance(data, dict) else {}
    ronda_id, author = _part(data, "rondaId"), _part(data, "authorUid")
    ref = _plan_ref(db, ronda_id, author)

    def record(transaction) -> None:
        snapshot = ref.get(transaction=transaction)
        plan = snapshot.to_dict() if snapshot.exists else None
        if plan is None or uid not in (plan.get("joined") or {}):
            return
        joined = {who: at for who, at in plan["joined"].items() if who != uid}
        transaction.update(ref, {"joined": joined})

    rsvp._in_transaction(db, record)
    refresh(db, ronda_id, now)
    return {"status": "left"}
