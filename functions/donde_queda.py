"""¿Dónde queda?: a weekly barrio photo game for each ronda (docs/PRODUCT.md § The weekly loop,
"¿Dónde queda?"; #58).

Each week one member is asked on Mi ronda to photograph something of the barrio ("una puerta,
un mural, un árbol"), with the answer line the reveal shows and an optional hint. The others
drop one pin each on a small map of the ronda's area. On the next week's card: "Era la puerta
verde de Gestido y Rivera." and "Cerca: 3 de 5". No names, no points, no history, and no push:
people open it themselves.

Fixed rules in code, never the model:
- **The turn** goes round the active members by when they joined (`turn_order`), one on from
  last week's first; a member paused over the meeting is skipped. "Esta semana no", or two days
  without a photo, passes it to the next, saying nothing to anyone; once everyone was asked the
  week has no game.
- **The photo** arrives with every face already pixelated on the phone (`packages/face_blur`)
  at `donde_queda_photos/{uid}/{photoId}.jpg`, is re-saved without EXIF and deleted once read,
  whatever happens. SAM 3.1 looks for people, number plates and house numbers (one English
  phrase per request, as for the flyer). A visible house number, a person as the subject or an
  empty photo is refused with the reason (`judge`); people passing and plates are pixelated
  here too. The published photo is `donde_queda/{rondaId}/{week}.jpg`, read by the ronda's
  members only (storage.rules).
- **The words** (the answer line and the hint) pass the organiser's word gates (no emoji,
  voseo, no money, no home or address) and then Muse Spark 1.3, which holds anything that
  points at someone's home or names a person.
- **The location** is never read from the photo: the answer is the pin the photographer drops.
  The reveal keeps only the line and the counts; the photo, the pin and every guess are deleted
  then (Storage's lifecycle rules on both prefixes are the backstop).

Documents (docs/ARCHITECTURE.md § Data model):
- `rondas/{id}/donde_queda/{isoWeek}` (no client reads it): week, meeting, status (asking |
  open | nobody | revealed), asked, askedAt, passed [uids], starter; once posted photographer,
  photoPath, line, hint, pin {lat, lng}, guesses {uid: {lat, lng}}, postedAt; once revealed
  only week, status, revealedFor, reveal {line, close, guessed}, revealedAt.
- `rondas/{id}/views/donde_queda` (the ronda's members): current {week, status, area {lat, lng,
  zoom}, closesOn, photoPath?, hint?} | null, reveal {week, line, close, guessed} | null,
  updatedAt.
- `rondas/{id}/donde_queda_players/{uid}` (that member only): week, asked, posted, guessed,
  updatedAt.
- `rondas/{id}/private/donde_queda` (no client): lastStarter, week.

The meeting week is the ISO week of the slot's next day (`rsvp.next_meeting`): a game runs from
the day after one meeting to the end of the next one's day, and the job reveals it the day after.
"""

import asyncio
import io
import logging
import re
import time
from collections.abc import Callable
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta
from enum import StrEnum
from typing import Any, Protocol

from PIL import Image, ImageStat
from pydantic import BaseModel, ConfigDict

import mate_flyer
import rsvp
from organiser import gates
from ronda_solver.demo import DEMO_BARRIOS
from ronda_solver.geo import metres_between
from voice_signup import META_BASE

log = logging.getLogger(__name__)

WORDS_MODEL = "muse-spark-1.3"

# --- Statuses, refusals and limits -------------------------------------------------------

ASKING = "asking"
OPEN = "open"
NOBODY = "nobody"
REVEALED = "revealed"

HOUSE_NUMBER_REFUSED = "houseNumber"
PERSON_REFUSED = "person"
EMPTY_REFUSED = "empty"
WORDS_REFUSED = "words"
"""Why a photo was refused, sent to the app as the error's `details.reason`."""

PERSON = "person"
PLATE = "license plate"
HOUSE_NUMBER = "house number"
CONCEPTS = (PERSON, PLATE, HOUSE_NUMBER)
"""What SAM 3.1 looks for, one English noun phrase per request (Spanish found nothing in the
smoke test, docs/MODELS.md)."""

PERSON_SUBJECT_SHARE = 0.12
"""A person whose box covers this share of the photo or more is its subject: refused. Smaller,
they were passing by, and are pixelated."""

EMPTY_SPREAD = 12.0
"""A photo whose grey levels spread less than this (standard deviation, 0-255) shows nothing: a
pocket, a black lens, a blank wall."""

BLUR_PADDING = 0.1
BLUR_CELLS = 8
"""Pixelation of a person or a plate: the box grown by a tenth on each side, about eight cells
across its long side, as the phone does for faces."""

PHOTO_SIDE = 1280
"""The published photo's long side, and what SAM sees."""
JPEG_QUALITY = 85

ASK_TIME = timedelta(hours=48)
"""An ask with no photo after this long passes to the next member, like "Esta semana no"."""

MIN_PLAYERS = 3
"""A game needs the photographer and two to guess, so "Cerca: 1 de 1" never tells on anyone."""

CLOSE_METRES = 250
"""A guess within two and a half blocks of the photographer's pin came close."""

AREA_METRES = 1500
"""Pins are taken within this of the barrio's centroid: the map is about two kilometres across
(MAP_ZOOM, four tiles a side), and this reaches its corners."""

MAP_ZOOM = 16

TEXT_LIMIT = 80
"""The answer line and the hint are one line each."""

PHOTO_PATH = re.compile(
    r"^donde_queda_photos/(?P<uid>[A-Za-z0-9_-]{1,128})/(?P<id>[A-Za-z0-9_-]{1,64})\.jpg$"
)
WEEK = re.compile(r"^\d{4}-W\d{2}$")


class DondeQuedaError(Exception):
    """A call the callables refuse; `code` is the callable's error code and `reason`, when the
    photo or its words were refused, says why."""

    def __init__(self, code: str, message: str, reason: str | None = None) -> None:
        super().__init__(message)
        self.code = code
        self.reason = reason


# --- Whose turn ----------------------------------------------------------------------------


def turn_order(members: dict[str, dict], meeting: date) -> list[str]:
    """Who takes turns for the meeting on `meeting`: the active members by when they joined, a
    member paused over it left out."""
    playing = {
        uid: m
        for uid, m in members.items()
        if m.get("state", "active") == "active"
        or (m.get("state") == "paused" and not rsvp._paused_on(m, meeting))
    }
    return sorted(playing, key=lambda uid: (str(playing[uid].get("joinedAt", "")), uid))


def starter(
    order: list[str], last: str | None, *, joined: dict[str, str] | None = None
) -> str | None:
    """Who is asked first this week: the one after last week's first. When that person is no
    longer in the order, whoever joined after them (from the top again past the end)."""
    if not order:
        return None
    if last in order:
        return order[(order.index(last) + 1) % len(order)]
    if last is not None and joined and last in joined:
        after = [uid for uid in order if joined.get(uid, "") > joined[last]]
        if after:
            return after[0]
    return order[0]


def next_asked(order: list[str], current: str, *, passed: list[str]) -> str | None:
    """Who is asked after `current` passed: the next in the order not asked yet this week, or
    nobody once everyone was."""
    start = order.index(current) + 1 if current in order else 0
    for uid in order[start:] + order[:start]:
        if uid not in passed:
            return uid
    return None


# --- The photo -----------------------------------------------------------------------------


@dataclass(frozen=True)
class Verdict:
    """What happens to a photo: refused (`refusal`, one of the `*_REFUSED`) or published with
    `blur` pixelated."""

    refusal: str | None
    blur: list[mate_flyer.Mask] = field(default_factory=list)


def is_empty(image: Image.Image) -> bool:
    """Whether the photo shows nothing: its grey levels barely change."""
    return ImageStat.Stat(image.convert("L")).stddev[0] < EMPTY_SPREAD


def _share(mask: mate_flyer.Mask, image: Image.Image) -> float:
    return mask.area / (image.width * image.height)


def judge(image: Image.Image, found: dict[str, list[mate_flyer.Mask]]) -> Verdict:
    """Refuses a photo with a house number in it, one whose subject is a person, or an empty
    one, in that order; otherwise blurs everyone passing by and every number plate."""
    if found.get(HOUSE_NUMBER):
        return Verdict(HOUSE_NUMBER_REFUSED)
    people = found.get(PERSON, [])
    if any(_share(m, image) >= PERSON_SUBJECT_SHARE for m in people):
        return Verdict(PERSON_REFUSED)
    if is_empty(image):
        return Verdict(EMPTY_REFUSED)
    return Verdict(None, [*people, *found.get(PLATE, [])])


def blur_boxes(image: Image.Image, boxes: list[mate_flyer.Mask]) -> Image.Image:
    """`image` with each box (grown by `BLUR_PADDING`) pixelated into about `BLUR_CELLS` cells
    across; the same image when there is nothing to blur."""
    if not boxes:
        return image
    out = image.copy()
    for box in boxes:
        pad_x = (box.right - box.left) * BLUR_PADDING
        pad_y = (box.bottom - box.top) * BLUR_PADDING
        left = max(0, int(box.left - pad_x))
        top = max(0, int(box.top - pad_y))
        right = min(out.width, int(box.right + pad_x) + 1)
        bottom = min(out.height, int(box.bottom + pad_y) + 1)
        if right <= left or bottom <= top:
            continue
        piece = out.crop((left, top, right, bottom))
        cell = max(1, max(piece.size) // BLUR_CELLS)
        small = piece.resize(
            (max(1, piece.width // cell), max(1, piece.height // cell)), Image.Resampling.BOX
        )
        out.paste(small.resize(piece.size, Image.Resampling.NEAREST), (left, top))
    return out


def encode(image: Image.Image) -> bytes:
    """The published photo: a JPEG with no EXIF (Pillow writes none unless given some)."""
    out = io.BytesIO()
    image.convert("RGB").save(out, format="JPEG", quality=JPEG_QUALITY)
    return out.getvalue()


# --- The words -----------------------------------------------------------------------------


def word_gates(text: str) -> str:
    """The first word gate `text` fails (emoji, voseo, money, an address or a home), or ""."""
    verdict = gates.check_words(text)
    return "" if verdict.allowed else verdict.gate


class WordsReason(StrEnum):
    OK = "ok"
    ADDRESS = "address"
    PERSON = "person"
    OTHER = "other"


class WordsVerdict(BaseModel):
    """Spark 1.3's strict answer about the line and the hint."""

    model_config = ConfigDict(extra="forbid")
    allowed: bool
    reason: WordsReason


WORDS_INSTRUCTIONS = (
    "Revisás textos cortos de un juego entre vecinos de Ciudad de la Costa, Uruguay: alguien "
    "sacó una foto de algo del barrio (una puerta, un mural, un árbol) y escribió qué es y, si "
    "quiso, una pista. Los demás adivinan dónde queda. Respondé allowed=false si el texto da "
    "una dirección con número de puerta, señala la casa de una persona, nombra o describe a "
    "una persona, o tiene algo ofensivo. Una esquina, una calle sin número, un comercio, una "
    "plaza o un lugar público están bien. reason: ok, address, person u other."
)


class WordChecker(Protocol):
    """Muse Spark 1.3: whether the line and the hint may be shown to the ronda."""

    def allowed(self, texts: list[str]) -> bool: ...


class SparkWords:
    """`WordChecker` on the Meta Model API's strict structured output (voice_signup.read_fields'
    request shape), at low reasoning effort."""

    def __init__(self, client: Any) -> None:
        self._client = client  # an openai.OpenAI on META_BASE

    def allowed(self, texts: list[str]) -> bool:
        try:
            response = self._client.chat.completions.parse(
                model=WORDS_MODEL,
                response_format=WordsVerdict,
                reasoning_effort="low",
                messages=[
                    {"role": "system", "content": WORDS_INSTRUCTIONS},
                    {"role": "user", "content": "\n".join(f"- {t}" for t in texts)},
                ],
            )
        except Exception as error:  # the SDK's errors share no useful base with httpx's
            raise mate_flyer.ModelUnavailable(f"spark {type(error).__name__}") from error
        verdict = response.choices[0].message.parsed
        if verdict is None:
            raise mate_flyer.ModelUnavailable("spark: no verdict")
        return verdict.allowed and verdict.reason == WordsReason.OK


# --- Where ---------------------------------------------------------------------------------


def _point(value: object) -> tuple[float, float] | None:
    if not isinstance(value, dict):
        return None
    lat, lng = value.get("lat"), value.get("lng")
    if not all(isinstance(v, int | float) and not isinstance(v, bool) for v in (lat, lng)):
        return None
    return float(lat), float(lng)


def within(centre: dict, pin: object) -> bool:
    """Whether `pin` ({lat, lng}) lies in the ronda's area around `centre`."""
    point = _point(pin)
    return point is not None and metres_between(_point(centre), point) <= AREA_METRES


def came_close(pin: dict, guesses: dict[str, dict]) -> tuple[int, int]:
    """How many guesses landed within `CLOSE_METRES` of the pin, and how many there were."""
    target = _point(pin)
    close = sum(
        1
        for guess in guesses.values()
        if (point := _point(guess)) is not None and metres_between(target, point) <= CLOSE_METRES
    )
    return close, len(guesses)


def area(ronda: dict) -> dict | None:
    """The map's centre and zoom: the ronda's barrio centroid, never a member's place."""
    centroid = DEMO_BARRIOS.get(ronda.get("barrio") or "")
    if centroid is None:
        return None
    return {"lat": centroid[0], "lng": centroid[1], "zoom": MAP_ZOOM}


# --- Documents -----------------------------------------------------------------------------


def _game_ref(db, ronda_id: str, week: str):
    return db.document(f"rondas/{ronda_id}/donde_queda/{week}")


def _player_ref(db, ronda_id: str, uid: str):
    return db.document(f"rondas/{ronda_id}/donde_queda_players/{uid}")


def _view_ref(db, ronda_id: str):
    return db.document(f"rondas/{ronda_id}/views/donde_queda")


def photo_path(ronda_id: str, week: str) -> str:
    """Where the published photo lives, under the ronda."""
    return f"donde_queda/{ronda_id}/{week}.jpg"


def _player(db, ronda_id: str, uid: str, week: str, now: datetime, **flags: bool) -> None:
    fields = {"asked": False, "posted": False, "guessed": False, **flags}
    _player_ref(db, ronda_id, uid).set({"week": week, **fields, "updatedAt": now})


def current_view(game: dict | None, ronda: dict) -> dict | None:
    """What members read of this week's game: its status, the map, and once posted the photo's
    path and the hint. Never who was asked, the pin or anyone's guess."""
    if game is None:
        return None
    view = {
        "week": game["week"],
        "status": game["status"],
        "area": area(ronda),
        "closesOn": game.get("meeting", ""),
    }
    if game["status"] == OPEN:
        view["photoPath"] = game["photoPath"]
        view["hint"] = game.get("hint", "")
    return view


def _write_current(db, ronda_id: str, game: dict, ronda: dict, now: datetime) -> None:
    _view_ref(db, ronda_id).set(
        {"current": current_view(game, ronda), "updatedAt": now}, merge=True
    )


# --- The weekly job ------------------------------------------------------------------------


def _delete_photo(bucket_of: Callable[[], Any], path: str) -> None:
    try:
        bucket_of().blob(path).delete()
    except Exception as error:  # already gone; the lifecycle rule is the backstop
        log.warning("donde_queda: photo delete failed (%s)", type(error).__name__)


def _delete_players(db, ronda_id: str, week: str) -> None:
    for snapshot in db.collection(f"rondas/{ronda_id}/donde_queda_players").stream():
        if (snapshot.to_dict() or {}).get("week") == week:
            db.document(f"rondas/{ronda_id}/donde_queda_players/{snapshot.id}").delete()


def reveal(db, ronda_id: str, game: dict, for_week: str, now: datetime, bucket_of) -> dict:
    """Closes an open game: counts who came close, keeps only the line and the counts, and
    deletes the photo, the pin, every guess and the players' cards. Returns the reveal."""
    close, guessed = came_close(game.get("pin") or {}, game.get("guesses") or {})
    shown = {"week": game["week"], "line": game.get("line", ""), "close": close, "guessed": guessed}
    _game_ref(db, ronda_id, game["week"]).set(
        {
            "week": game["week"],
            "status": REVEALED,
            "revealedFor": for_week,
            "reveal": shown,
            "revealedAt": now,
        }
    )
    _delete_photo(bucket_of, game["photoPath"])
    _delete_players(db, ronda_id, game["week"])
    return shown


def _ask(db, ronda_id: str, game: dict, uid: str | None, now: datetime) -> dict:
    """Moves the turn to `uid`, or to nobody."""
    if uid is None:
        game.update(status=NOBODY, asked="")
    else:
        game.update(asked=uid, askedAt=now)
        _player(db, ronda_id, uid, game["week"], now, asked=True)
    _game_ref(db, ronda_id, game["week"]).set(game)
    return game


def pass_on(db, ronda_id: str, game: dict, order: list[str], now: datetime) -> dict:
    """The asked member passes ("Esta semana no", or two days without a photo): the next one in
    the order is asked, and nobody hears why."""
    current = game["asked"]
    passed = [*game.get("passed", []), current]
    game["passed"] = passed
    _player(db, ronda_id, current, game["week"], now)
    return _ask(db, ronda_id, game, next_asked(order, current, passed=passed), now)


def start(db, ronda_id: str, ronda: dict, week: str, meeting: date, order, now) -> dict | None:
    """Opens this week's game by asking the member after last week's first, if enough play."""
    if len(order) < MIN_PLAYERS:
        return None
    pointer_ref = db.document(f"rondas/{ronda_id}/private/donde_queda")
    last = (pointer_ref.get().to_dict() or {}).get("lastStarter")
    members = rsvp._members(db, ronda_id)
    joined = {uid: str(m.get("joinedAt", "")) for uid, m in members.items()}
    first = starter(order, last, joined=joined)
    pointer_ref.set({"lastStarter": first, "week": week})
    game = {
        "week": week,
        "meeting": meeting.isoformat(),
        "status": ASKING,
        "passed": [],
        "starter": first,
    }
    return _ask(db, ronda_id, game, first, now)


def step_ronda(db, ronda_id: str, ronda: dict, now: datetime, bucket_of, counts: dict) -> None:
    """One ronda's hour: reveals last week's game, drops older ones, starts or moves this
    week's turn, and rewrites what members read."""
    meeting = rsvp.next_meeting(ronda["slot"]["day"], rsvp.local(now).date())
    week = rsvp.iso_week(meeting)
    games = {
        s.id: s.to_dict() or {} for s in db.collection(f"rondas/{ronda_id}/donde_queda").stream()
    }
    shown = None
    for game_week, game in sorted(games.items()):
        if game_week >= week:
            continue
        status = game.get("status")
        if status == OPEN:
            shown = reveal(db, ronda_id, game, week, now, bucket_of)
            counts["revealed"] += 1
        elif status == REVEALED and game.get("revealedFor") == week:
            shown = game.get("reveal")
        else:
            _game_ref(db, ronda_id, game_week).delete()
            _delete_players(db, ronda_id, game_week)
            counts["deleted"] += 1

    order = turn_order(rsvp._members(db, ronda_id), meeting)
    game = games.get(week)
    if game is None:
        game = start(db, ronda_id, ronda, week, meeting, order, now)
        counts["asked"] += game is not None
    elif game.get("status") == ASKING and now - game["askedAt"] >= ASK_TIME:
        game = pass_on(db, ronda_id, game, order, now)
        counts["passed"] += 1
    _view_ref(db, ronda_id).set(
        {"current": current_view(game, ronda), "reveal": shown, "updatedAt": now}
    )


def _default_bucket():  # pragma: no cover - the Admin SDK's bucket, only in a deployed function
    from firebase_admin import storage

    return storage.bucket()


def run_donde_queda(db, now: datetime, *, bucket=None) -> dict:
    """The hourly job (`jobs.JOBS["donde_queda"]`): every open ronda with a barrio on the map.
    Sends nothing. Returns counts."""
    counts = {"rondas": 0, "asked": 0, "passed": 0, "revealed": 0, "deleted": 0}

    def bucket_of():
        return bucket if bucket is not None else _default_bucket()

    for snapshot in db.collection("rondas").stream():
        ronda = snapshot.to_dict() or {}
        if ronda.get("status") not in rsvp.OPEN_STATUSES or area(ronda) is None:
            continue
        if (ronda.get("slot") or {}).get("day") not in rsvp.DAYS:
            continue
        counts["rondas"] += 1
        step_ronda(db, snapshot.id, ronda, now, bucket_of, counts)
    return counts


# --- The callables -------------------------------------------------------------------------


def _part(data: dict, name: str, pattern: re.Pattern | None = None) -> str:
    value = data.get(name)
    if not isinstance(value, str) or not value or "/" in value:
        raise DondeQuedaError("invalid-argument", f"{name} is required")
    if pattern is not None and not pattern.match(value):
        raise DondeQuedaError("invalid-argument", f"{name} is malformed")
    return value


def _game(db, ronda_id: str, week: str) -> dict:
    snapshot = _game_ref(db, ronda_id, week).get()
    return (snapshot.to_dict() or {}) if snapshot.exists else {}


def _ronda(db, ronda_id: str) -> dict:
    snapshot = db.document(f"rondas/{ronda_id}").get()
    if not snapshot.exists:
        raise DondeQuedaError("not-found", "no such ronda")
    return snapshot.to_dict() or {}


def _asked_game(db, uid: str, ronda_id: str, week: str) -> dict:
    game = _game(db, ronda_id, week)
    if game.get("status") != ASKING:
        raise DondeQuedaError("failed-precondition", "the turn is over")
    if game.get("asked") != uid:
        raise DondeQuedaError("permission-denied", "it isn't your turn")
    return game


def pass_turn(db, uid: str, data: object, now: datetime) -> dict:
    """ "Esta semana no", `{rondaId, week}`, from the member asked: the turn moves on."""
    data = data if isinstance(data, dict) else {}
    ronda_id, week = _part(data, "rondaId"), _part(data, "week", WEEK)
    game = _asked_game(db, uid, ronda_id, week)
    ronda = _ronda(db, ronda_id)
    order = turn_order(rsvp._members(db, ronda_id), date.fromisoformat(game["meeting"]))
    game = pass_on(db, ronda_id, game, order, now)
    _write_current(db, ronda_id, game, ronda, now)
    return {"status": "passed"}


def _text(data: dict, name: str, *, required: bool) -> str:
    value = data.get(name, "")
    if not isinstance(value, str):
        raise DondeQuedaError("invalid-argument", f"{name} is text")
    value = " ".join(value.split())
    if (required and not value) or len(value) > TEXT_LIMIT or "\n" in data.get(name, ""):
        raise DondeQuedaError("invalid-argument", f"{name} is one line of up to {TEXT_LIMIT}")
    return value


def photo_uid(path: object) -> str:
    """The uid in `donde_queda_photos/{uid}/{id}.jpg`, or `INVALID_ARGUMENT` for any other."""
    if not isinstance(path, str) or not (match := PHOTO_PATH.match(path)):
        raise DondeQuedaError("invalid-argument", "photoPath is donde_queda_photos/{uid}/{id}.jpg")
    return match["uid"]


async def _segment(png: bytes, segmenter: mate_flyer.Segmenter) -> dict[str, list]:
    found = await asyncio.gather(*(segmenter.segment(png, concept) for concept in CONCEPTS))
    return {
        concept: [m for m in masks if any(m.raster)]
        for concept, masks in zip(CONCEPTS, found, strict=True)
    }


async def _with_sam(api_key: str, png: bytes) -> dict[str, list]:  # pragma: no cover - network
    from openai import AsyncOpenAI

    client = AsyncOpenAI(base_url=META_BASE, api_key=api_key, timeout=60, max_retries=2)
    try:
        return await _segment(png, mate_flyer.MetaSam(client))
    finally:
        await client.close()


def _spark(api_key: str) -> WordChecker:  # pragma: no cover - network
    from openai import OpenAI

    return SparkWords(OpenAI(base_url=META_BASE, api_key=api_key, timeout=30, max_retries=2))


def _refuse(reason: str) -> DondeQuedaError:
    return DondeQuedaError("failed-precondition", f"refused: {reason}", reason)


def post_photo(
    *,
    uid: str,
    data: object,
    db,
    bucket,
    api_key: str,
    now: datetime,
    segmenter: mate_flyer.Segmenter | None = None,
    checker: WordChecker | None = None,
) -> dict:
    """The `post_donde_queda` callable, `{rondaId, week, photoPath, line, hint?, lat, lng}`:
    the member asked posts their photo, what it is and where (their pin). The words and the
    photo are checked, people and plates blurred, and the photo published under the ronda.
    The upload is deleted once its path is known to be the caller's, whatever happens."""
    data = data if isinstance(data, dict) else {}
    ronda_id, week = _part(data, "rondaId"), _part(data, "week", WEEK)
    if photo_uid(data.get("photoPath")) != uid:
        raise DondeQuedaError("permission-denied", "not your photo")
    upload = bucket.blob(data["photoPath"])
    started = time.perf_counter()
    try:
        game = _asked_game(db, uid, ronda_id, week)
        ronda = _ronda(db, ronda_id)
        line = _text(data, "line", required=True)
        hint = _text(data, "hint", required=False)
        pin = {"lat": data.get("lat"), "lng": data.get("lng")}
        centre = area(ronda)
        if centre is None or not within(centre, pin):
            raise DondeQuedaError("invalid-argument", "the pin is outside the ronda's area")
        if any(word_gates(text) for text in (line, hint) if text):
            raise _refuse(WORDS_REFUSED)
        try:
            words = checker or _spark(api_key)
            if not words.allowed([text for text in (line, hint) if text]):
                raise _refuse(WORDS_REFUSED)
            try:
                image = mate_flyer.scaled(
                    mate_flyer.read_photo(upload.download_as_bytes()), PHOTO_SIDE
                )
            except mate_flyer.FlyerError as error:
                raise DondeQuedaError(error.code, str(error)) from error
            if is_empty(image):
                raise _refuse(EMPTY_REFUSED)
            png = io.BytesIO()
            image.save(png, format="PNG")
            found = asyncio.run(
                _segment(png.getvalue(), segmenter)
                if segmenter is not None
                else _with_sam(api_key, png.getvalue())
            )
        except mate_flyer.ModelUnavailable as error:
            raise DondeQuedaError("unavailable", "try again in a moment") from error
        verdict = judge(image, found)
        if verdict.refusal:
            raise _refuse(verdict.refusal)
        published = photo_path(ronda_id, week)
        jpeg = encode(blur_boxes(image, verdict.blur))
        bucket.blob(published).upload_from_string(jpeg, content_type="image/jpeg")
        game.update(
            status=OPEN,
            photographer=uid,
            photoPath=published,
            line=line,
            hint=hint,
            pin={"lat": float(pin["lat"]), "lng": float(pin["lng"])},
            guesses={},
            postedAt=now,
        )
        _game_ref(db, ronda_id, week).set(game)
        _player(db, ronda_id, uid, week, now, posted=True)
        _write_current(db, ronda_id, game, ronda, now)
        log.info(
            "post_donde_queda %s %s: %d blurred, %d ms, %d bytes",
            ronda_id,
            week,
            len(verdict.blur),
            (time.perf_counter() - started) * 1000,
            len(jpeg),
        )
        return {"status": OPEN}
    finally:
        try:
            upload.delete()
        except Exception as error:  # already gone; the 1-day lifecycle rule is the backstop
            log.warning("post_donde_queda: upload delete failed (%s)", type(error).__name__)


def guess(db, uid: str, data: object, now: datetime) -> dict:
    """ "Es acá", `{rondaId, week, lat, lng}`: a member of the ronda, not the photographer,
    drops their one pin on this week's open game."""
    data = data if isinstance(data, dict) else {}
    ronda_id, week = _part(data, "rondaId"), _part(data, "week", WEEK)
    member = db.document(f"rondas/{ronda_id}/members/{uid}").get()
    if not member.exists or (member.to_dict() or {}).get("state") == "left":
        raise DondeQuedaError("permission-denied", "not a member of this ronda")
    ronda = _ronda(db, ronda_id)
    pin = {"lat": data.get("lat"), "lng": data.get("lng")}
    centre = area(ronda)
    if centre is None or not within(centre, pin):
        raise DondeQuedaError("invalid-argument", "the pin is outside the ronda's area")
    ref = _game_ref(db, ronda_id, week)

    def record(transaction) -> None:
        game = ref.get(transaction=transaction).to_dict() or {}
        if game.get("status") != OPEN:
            raise DondeQuedaError("failed-precondition", "no game to guess")
        if game.get("photographer") == uid:
            raise DondeQuedaError("permission-denied", "it's your photo")
        guesses = dict(game.get("guesses") or {})
        if uid in guesses:
            raise DondeQuedaError("already-exists", "one pin each")
        guesses[uid] = {"lat": float(pin["lat"]), "lng": float(pin["lng"])}
        transaction.update(ref, {"guesses": guesses})

    rsvp._in_transaction(db, record)
    _player(db, ronda_id, uid, week, now, guessed=True)
    return {"status": "guessed"}
