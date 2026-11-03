"""Build one ronda to film on the Firebase emulators: the owner's account and invented neighbours.

From the repo root, with the emulators up (`OBJC_DISABLE_INITIALIZE_FORK_SAFETY=YES firebase
emulators:start` on macOS, docs/STACK.md) and the owner signed in
and onboarded once from the development app:

    FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \\
        scripts/demo_ronda.sh vecina@example.com [--scene ronda]

`demo_ronda.sh` runs this file with `functions/venv`'s Python (docs/STACK.md has how to make
it), because the ronda is built by the functions' own code, not by documents written by hand:
`proposals.ronda_documents` lays out the ronda as Aprobar does, `hosts.set_setup` sets the place,
the hour, the anfitrión and the cola and turns the organiser's weekly card on as "Lugar, hora y
anfitriones" does, and then the jobs the screens wait for run as `run_job {name, force, now}`
runs them: rsvp_push ("Mandarlo ahora"), first_visit, handoff, seguimos_ask, weekly_card,
rain_check, prompt_buddy and attendance_ask. The jobs see this ronda only, so the owner's other
rondas on the emulators are left as they are. The account can be named by email or by uid.

Everything but the owner is invented: five neighbours from the demo set (scripts/demo_data.py,
`demo-` uids) and the covered places the organiser may offer when it rains. Two things are
scripted rather than asked, because a model can't be on the emulators' side of a demo: the
model's words on the weekly card and in the rain proposal (a scripted `ModelClient`, labelled
`guion-demo` in the trace), and the forecast (a rainy afternoon). The code around them is the real
one: the word gates, the card's blocks, the move's options and deadline. Nothing reaches a
phone: the emulators have no FCM, so every push counts as `skipped`, and the screens are what
the app reads from Firestore.

Dates come from the real clock, since the phone's date gates read its own: the meeting is
tomorrow (today for `attendance`, in two days for `rain`), its weekday becomes the ronda's slot
day, and last week's meeting is in the record. The server's clock is the real one too, moved
into 09:00-21:00 Montevideo when it is outside, because the jobs send nothing in quiet hours.
The ronda was approved four weeks before the meeting (`createdAt`), so the meeting is its fifth
week, past `openSeatFromWeek`, and its hosts get the flyer card.

Run it again and it starts over: it deletes what it wrote before (`rondas/demo-ronda` and
everything under it, its acta, runs, counts and links, the owner's buddy and gate marks) and
builds the scene again; only the timestamps differ. Emulator only: it refuses to run without
FIRESTORE_EMULATOR_HOST. The project is GCLOUD_PROJECT, else .firebaserc's default, which is
the one the emulators and the development app use. Best from a clean state: `scripts/reset.py`,
then sign in once, then this.

Scenes (`--scene`), one per shot that can't share a ronda with another:

- `ronda` (default): the owner opens. ¿Venís? with who's coming, the weekly card the organiser
  composed, ¿Seguimos?, "¿Quién espera a …?" for a newcomer, the buddy choice, a buddy's
  "… no vino el …" and the rain proposal (pick before 21:00 tonight, or use `rain`).
- `rain`: as `ronda`, with the meeting in two days, so the proposal's 21:00 deadline is tomorrow.
- `handoff`: the owner closes; the anfitrión said "esta no", so the owner is asked ¿Abrís vos?.
- `newcomer`: the owner joined yesterday: Así va a ser, with who waits and how to know them.
- `attendance`: the meeting is today and the owner opens: ¿Quién vino hoy? on the card.

The cuaderno's postcard is offered the day before the meeting (`ronda`, `handoff`, `newcomer`)
and on the day (`attendance`), once the phone holds lines from this week: its lines live on the
phone only, so write three in the app before filming it.

The Android emulator: start the development flavor against the Mac's emulators with
`flutter run --flavor development -t lib/main_development.dart`; it reaches them at 10.0.2.2
on its own. On a USB phone run `for p in 9099 8088 5001 9199; do adb reverse tcp:$p tcp:$p;
done` and add `--dart-define=FIREBASE_EMULATOR_HOST=127.0.0.1` (docs/STACK.md § Native and
project checklist). Sign in with the emulator's account picker (or
`--dart-define=EMULATOR_GOOGLE_CREDENTIAL=true`), finish onboarding, then run this script. The
rain proposal has no link inside the app on a phone (a push opens it, and there is no FCM
here): film it on web, where the shot list's path opens it.
"""

import argparse
import json
import os
import sys
import urllib.request
from collections.abc import Callable, Iterator
from dataclasses import dataclass
from datetime import UTC, date, datetime, time, timedelta
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# The functions' own modules build the ronda; they import each other by bare name.
sys.path.append(str(ROOT / "functions"))
# Demo sign-ups count as they do under the Functions emulator (functions/demo_users.py).
os.environ.setdefault("FUNCTIONS_EMULATOR", "true")

import attendance  # noqa: E402
import buddy  # noqa: E402
import first_visit  # noqa: E402
import handoff  # noqa: E402
import hosts  # noqa: E402
import proposals  # noqa: E402
import rain  # noqa: E402
import rsvp  # noqa: E402
import seguimos  # noqa: E402
import weekly_card  # noqa: E402
from google.cloud import firestore  # noqa: E402
from google.cloud.firestore import DELETE_FIELD, FieldFilter  # noqa: E402
from organiser.model import ToolCall, Turn  # noqa: E402
from organiser.weather import Day  # noqa: E402

import demo_data  # noqa: E402
import seed  # noqa: E402

AUTH_HOST = "FIREBASE_AUTH_EMULATOR_HOST"
RONDA_ID = "demo-ronda"
"""The filmed ronda's id, the same on every run, so the shot list's paths stay put."""

BARRIO = "el-pinar-sur"
PRETEXT = "mate"
BAND = "afternoon"
HOUR = "16:00"
PLACE = {"name": "frente al quiosco", "landmark": "al lado de la parada"}
"""Invented: a public spot in the barrio, as an admin would type it."""

COVERED_PLACE = "demo-salon-el-pinar"
"""The invented covered place near the barrio (data/demo/invented_places.json)."""

SIGN = "tiene el termo verde"
"""How the newcomer knows who waits, in the `newcomer` scene; invented."""

NEIGHBOURS = 5
"""Invented members besides the owner: six in all, a mate ronda's largest."""

MODEL_NAME = "guion-demo"
"""What the trace names as the model: the words are this script's, not a model's."""

RAINY_AFTERNOON = Day(
    hours={hour: (80, 2.4, 45) for hour in range(9, 22)},
    sunset="19:58",
)
"""Invented forecast: rain likely all day, so the organiser proposes a move."""

JOINED_WEEKS_BEFORE = 4
"""The ronda was approved this many weeks before the meeting (27 or more days back): week 1 is
that slot day, so the meeting is week 5, past `openSeatFromWeek` (4), and Mi ronda offers its
hosts the flyer ("Hacer el volante")."""

ANFITRION, COLA, NEWCOMER = "anfitrion", "cola", "newcomer"


@dataclass(frozen=True)
class Scene:
    """One shot's setup: when the meeting is and what the owner is in it."""

    days_ahead: int
    """The meeting is this many days from today, Montevideo."""
    owner: str
    """`anfitrion`, `cola` or `newcomer`."""
    shows: str


SCENES = {
    "ronda": Scene(1, ANFITRION, "the owner opens tomorrow's meeting"),
    "rain": Scene(2, ANFITRION, "the owner opens; the meeting is in two days"),
    "handoff": Scene(1, COLA, "the anfitrión can't, so the owner is asked to open"),
    "newcomer": Scene(1, NEWCOMER, "the owner joined yesterday; tomorrow is their first"),
    "attendance": Scene(0, ANFITRION, "the meeting is today and the owner opens"),
}


class Refused(Exception):
    """The state this script needs isn't there; the message says what to do."""


# --- The clock ----------------------------------------------------------------------------


def job_clock(now: datetime) -> datetime:
    """`now`, moved into the hours the jobs send in (09:00-21:00 Montevideo) when it is
    outside: to 09:00 before them, to 20:00 after."""
    here = rsvp.local(now)
    if here.hour < rsvp.QUIET_UNTIL:
        return here.replace(hour=rsvp.QUIET_UNTIL, minute=0, second=0, microsecond=0)
    if here.hour >= rsvp.QUIET_FROM:
        return here.replace(hour=rsvp.QUIET_FROM - 1, minute=0, second=0, microsecond=0)
    return here


@dataclass(frozen=True)
class Dates:
    """The scene's calendar, from today in Montevideo."""

    meeting: date
    last: date
    """Last week's meeting, which is in the record."""
    joined: datetime
    """When the ronda was approved (its `createdAt`) and its first members joined: on the slot
    day four weeks before the meeting, so the meeting is its fifth week."""
    newcomer_joined: datetime

    @property
    def slot_day(self) -> str:
        return rsvp.DAYS[self.meeting.weekday()]

    @property
    def week(self) -> str:
        return rsvp.iso_week(self.meeting)


def dates(scene: Scene, now: datetime) -> Dates:
    today = rsvp.local(now).date()
    meeting = today + timedelta(days=scene.days_ahead)
    last = meeting - timedelta(weeks=1)
    joined = datetime.combine(
        meeting - timedelta(weeks=JOINED_WEEKS_BEFORE), time(12), tzinfo=rsvp.MONTEVIDEO
    )
    return Dates(meeting, last, joined.astimezone(UTC), now - timedelta(days=1))


# --- Who ----------------------------------------------------------------------------------


@dataclass(frozen=True)
class Cast:
    owner: str
    neighbours: tuple[str, ...]
    anfitrion: str
    cola: str
    newcomer: str
    missed: str
    """Missed last week without saying so; the owner is their buddy (not in `newcomer`)."""

    @property
    def members(self) -> tuple[str, ...]:
        return (self.owner, *self.neighbours)


def demo_people() -> dict[str, dict]:
    """The invented 30 set's profiles by uid (scripts/demo_data.py)."""
    problem = demo_data.invented_problem(30)
    return {
        path.removeprefix("users/"): fields
        for path, fields in demo_data.user_documents(problem).items()
    }


def cast(owner: str, scene: Scene, people: dict[str, dict]) -> Cast:
    """The first neighbours of the demo set, in uid order, and who plays what."""
    neighbours = tuple(sorted(people)[:NEIGHBOURS])
    first, second, _, fourth, fifth = neighbours
    roles = {
        ANFITRION: (owner, first, fifth),
        COLA: (first, owner, fifth),
        NEWCOMER: (first, second, owner),
    }[scene.owner]
    return Cast(owner, neighbours, *roles, missed=fourth)


# --- The emulators ------------------------------------------------------------------------


def owner_uid(account: str, project: str) -> str:
    """`account`'s uid: itself, or the Auth emulator's account with that email."""
    if "@" not in account:
        return account
    if not (host := os.environ.get(AUTH_HOST)):
        raise Refused(f"{AUTH_HOST} is not set: give the uid, or the Auth emulator's host.")
    request = urllib.request.Request(
        f"http://{host}/identitytoolkit.googleapis.com/v1/projects/{project}/accounts:lookup",
        data=json.dumps({"email": [account]}).encode(),
        headers={"Authorization": "Bearer owner", "Content-Type": "application/json"},
    )
    with urllib.request.urlopen(request, timeout=30) as response:
        users = json.load(response).get("users", [])
    if not users:
        raise Refused(f"No account for {account} in the Auth emulator: sign in once first.")
    return users[0]["localId"]


class OneRonda:
    """The client with `rondas` narrowed to one ronda for the jobs' sweeps, so they run for
    the filmed ronda only and leave the owner's other rondas as they are."""

    def __init__(self, client: firestore.Client, ronda_id: str) -> None:
        self._client = client
        self._ronda_id = ronda_id

    def collection(self, path: str):
        collection = self._client.collection(path)
        return _Only(collection, self._ronda_id) if path == "rondas" else collection

    def __getattr__(self, name: str):
        return getattr(self._client, name)


class _Only:
    def __init__(self, collection, ronda_id: str) -> None:
        self._collection = collection
        self._ronda_id = ronda_id

    def stream(self) -> Iterator:
        snapshot = self._collection.document(self._ronda_id).get()
        if snapshot.exists:
            yield snapshot

    def __getattr__(self, name: str):
        return getattr(self._collection, name)


def no_fcm(messages: list[dict]) -> list[str]:
    """The sender: the emulators have no FCM, so nothing goes out (`skipped`, as the functions
    emulator reports it)."""
    return ["skipped"] * len(messages)


# --- Starting over ------------------------------------------------------------------------


def clear(db: firestore.Client, owner: str, people: dict[str, dict]) -> None:
    """Deletes what an earlier run wrote for the filmed ronda, and nothing of anyone else's."""
    db.recursive_delete(db.document(f"rondas/{RONDA_ID}"))
    db.recursive_delete(db.document(f"acta/{RONDA_ID}"))
    db.document(f"seguimos_counts/{RONDA_ID}").delete()
    for run in db.collection("agent_runs").list_documents():
        if run.id.startswith(f"{RONDA_ID}_"):
            db.recursive_delete(run)
    offers = db.collection_group("offers").where(filter=FieldFilter("rondaId", "==", RONDA_ID))
    for offer in offers.stream():
        offer.reference.delete()
    for uid in (owner, *people):
        db.document(f"users/{uid}/rondas/{RONDA_ID}").delete()
        # What the gates remember: who was introduced, and the week's routine push.
        db.document(f"users/{uid}/private/agent").delete()
    if db.document(f"users/{owner}").get().exists:
        db.document(f"users/{owner}").update({"buddyUid": DELETE_FIELD})


# --- Building it --------------------------------------------------------------------------


def write_people(db: firestore.Client, crew: Cast, people: dict[str, dict]) -> dict[str, dict]:
    """The neighbours' profiles and the covered places, as the demo seed writes them; returns
    every member's profile, the owner's as the app saved it."""
    owner = db.document(f"users/{crew.owner}").get()
    profile = (owner.to_dict() or {}) if owner.exists else {}
    if not profile.get("firstName"):
        raise Refused(
            "That account has no profile yet: sign in to the app and finish onboarding first."
        )
    batch = db.batch()
    for uid in crew.neighbours:
        batch.set(db.document(f"users/{uid}"), people[uid])
    for path, fields in demo_data.place_documents({}).items():
        batch.set(db.document(path), fields)
    batch.commit()
    return {crew.owner: profile} | {uid: people[uid] for uid in crew.neighbours}


def approve(db: firestore.Client, crew: Cast, when: Dates, profiles: dict[str, dict]) -> None:
    """The ronda as Aprobar writes it (`proposals.ronda_documents`), approved and joined four
    weeks before the meeting, the newcomer yesterday."""
    slot = f"{when.slot_day}-{BAND}"
    group = {
        "id": f"{BARRIO}_{PRETEXT}_{slot}",
        "barrio": BARRIO,
        "pretext": PRETEXT,
        "slot": slot,
        "members": [{"uid": uid} for uid in crew.members],
    }
    documents = proposals.ronda_documents({"groups": [group]}, [RONDA_ID], profiles, when.joined)
    for path in (
        f"rondas/{RONDA_ID}/members/{crew.newcomer}",
        f"users/{crew.newcomer}/rondas/{RONDA_ID}",
    ):
        documents[path]["joinedAt"] = when.newcomer_joined
    batch = db.batch()
    for path, fields in documents.items():
        batch.set(db.document(path), fields)
    batch.commit()


def last_week(db: firestore.Client, crew: Cast, when: Dates) -> None:
    """Last week's meeting in the record: everyone said yes, and the one who missed it came
    without saying so. It makes the buddy choice due and gives the buddy something to hear."""
    came = [uid for uid in crew.members if uid != crew.newcomer]
    sent = datetime.combine(when.last - timedelta(days=2), time(19), tzinfo=rsvp.MONTEVIDEO)
    db.document(f"rondas/{RONDA_ID}/weeks/{rsvp.iso_week(when.last)}").set(
        {
            "date": when.last.isoformat(),
            "rsvp": dict.fromkeys(came, rsvp.YES),
            "rsvpSentAt": sent,
            "attendance": {uid: uid != crew.missed for uid in came},
        }
    )
    if crew.owner != crew.newcomer:
        db.document(f"users/{crew.missed}").update({"buddyUid": crew.owner})


# --- The scripted model -------------------------------------------------------------------


class ScriptedModel:
    """A `ModelClient` that answers with the turns it was given, in order."""

    def __init__(self, turns: list[Turn]) -> None:
        self._turns = list(turns)

    @property
    def name(self) -> str:
        return MODEL_NAME

    def complete(self, messages: list[dict], tools: list[dict]) -> Turn:
        return self._turns.pop(0)


class Forecast:
    """The invented forecast, the same for every day and place."""

    def day(self, lat: float, lng: float, on: date) -> Day:
        return RAINY_AFTERNOON


def _turn(name: str = "", content: str = "", **arguments) -> Turn:
    calls = (ToolCall(f"call_{name}", name, json.dumps(arguments, ensure_ascii=False)),)
    return Turn(content=content, tool_calls=calls if name else (), model=MODEL_NAME)


def card_script(*, newcomer: bool) -> list[Turn]:
    """The weekly card's words: who opens and, when `newcomer`, who is new; code fills in the
    names."""
    blocks = [
        {
            "kind": "host",
            "title": "Esta semana abre {anfitrion}",
            "text": "Llega diez minutos antes y saluda a los que van llegando.",
        },
        {
            "kind": "newcomer",
            "title": "Viene alguien nuevo",
            "text": "Se suma {nuevo}. Si lo ves llegar, acercate.",
        },
    ][: 2 if newcomer else 1]
    return [
        _turn("compose_card", blocks=blocks, reason="armar los avisos de la semana"),
        _turn("log_acta", summary="Armó la tarjeta de la semana.", reason="dejarlo anotado"),
        _turn(content="Listo."),
    ]


def rain_script(meeting: date) -> list[Turn]:
    """The rain check's words: the forecast, a covered place or the next day, an acta line."""
    return [
        _turn("get_forecast", date=meeting.isoformat(), reason="ver si llueve en la ronda"),
        _turn(
            "propose_move",
            place_id=COVERED_PLACE,
            postpone_to=(meeting + timedelta(days=1)).isoformat(),
            reason="llueve fuerte a la hora de la ronda y hay un salón techado cerca",
        ),
        _turn(
            "log_acta",
            summary="Por la lluvia, le propuso opciones a quien abre.",
            reason="dejarlo anotado",
        ),
        _turn(content="Listo."),
    ]


# --- The run ------------------------------------------------------------------------------


@dataclass(frozen=True)
class Built:
    scene: str
    owner_name: str
    crew: Cast
    when: Dates
    now: datetime
    jobs: dict[str, dict]
    people: dict[str, dict]


def build(db: firestore.Client, account: str, scene_name: str, now: datetime) -> Built:
    """Starts over and builds `scene_name` for `account` at `now` (the real clock)."""
    scene = SCENES[scene_name]
    owner = owner_uid(account, db.project)
    people = demo_people()
    crew = cast(owner, scene, people)
    clock = job_clock(now)
    when = dates(scene, clock)
    clear(db, owner, people)
    profiles = write_people(db, crew, people)
    approve(db, crew, when, profiles)
    last_week(db, crew, when)
    hosts.set_setup(
        db,
        {
            "rondaId": RONDA_ID,
            "place": PLACE,
            "hour": HOUR,
            "anfitrion": crew.anfitrion,
            "cola": crew.cola,
            "agentCard": True,
        },
        clock,
    )

    one = OneRonda(db, RONDA_ID)
    jobs: dict[str, dict] = {}

    def job(name: str, run: Callable[[], dict]) -> None:
        jobs[name] = run()

    job("rsvp_push", lambda: rsvp.run_rsvp_push(one, clock, send=no_fcm, force=True))
    answers = {crew.anfitrion: rsvp.YES, crew.cola: rsvp.YES, crew.neighbours[2]: rsvp.YES}
    if scene.owner == COLA:
        answers[crew.anfitrion] = rsvp.NO
    answers.pop(crew.owner, None)  # the owner answers ¿Venís? on camera
    for uid, answer in answers.items():
        rsvp.answer(db, uid, RONDA_ID, answer, clock)
    job("first_visit", lambda: first_visit.run_first_visit(one, clock))
    if scene.owner == NEWCOMER:
        first_visit.set_waiter(
            db,
            crew.anfitrion,
            {
                "rondaId": RONDA_ID,
                "newcomerUid": crew.owner,
                "waiterUid": crew.anfitrion,
                "sign": SIGN,
            },
            clock,
        )
    if scene.owner == COLA:
        job("handoff", lambda: handoff.run_handoff(one, clock, send=no_fcm, force=True))
    if scene.owner != NEWCOMER:
        job("seguimos_ask", lambda: seguimos.run_seguimos_ask(one, clock, send=no_fcm, force=True))
    job(
        "weekly_card",
        lambda: weekly_card.run_weekly_card(
            one,
            clock,
            send=no_fcm,
            force=True,
            model=ScriptedModel(card_script(newcomer=scene.owner != NEWCOMER)),
            weather=Forecast(),
        ),
    )
    if scene.owner == ANFITRION and scene.days_ahead > 0:
        job(
            "rain_check",
            lambda: rain.run_rain_check(
                one,
                clock,
                send=no_fcm,
                force=True,
                model=ScriptedModel(rain_script(when.meeting)),
                weather=Forecast(),
            ),
        )
    if scene.owner != NEWCOMER:
        job("prompt_buddy", lambda: buddy.run_prompt_buddy(one, clock, send=no_fcm, force=True))
    if scene.days_ahead == 0:
        job(
            "attendance_ask",
            lambda: attendance.run_attendance_ask(one, clock, send=no_fcm, force=True),
        )
    return Built(scene_name, profiles[owner]["firstName"], crew, when, clock, jobs, people)


def shot_list(built: Built) -> list[str]:
    """What to open in the app for each screen this scene shows."""
    crew, when, scene = built.crew, built.when, SCENES[built.scene]

    def name(uid: str) -> str:
        return built.people.get(uid, {}).get("firstName", "")

    shots = [
        f"Mi ronda (/): the card for {when.meeting.isoformat()} at {HOUR}, {PLACE['name']}, "
        "¿Venís? with who's coming, and the organiser's weekly card in it",
    ]
    if scene.owner != NEWCOMER:
        shots.append("Mi ronda, top: ¿Seguimos? with [Sí] [No]")
    if scene.owner == ANFITRION and scene.days_ahead > 0:
        shots.append(f"Mi ronda, under the card: «¿Quién espera a {name(crew.newcomer)}?»")
    if scene.owner != NEWCOMER:
        shots += [
            "Mi ronda, below: «tu persona de confianza», the buddy choice",
            f"Mi ronda, below: «{name(crew.missed)} no vino el …» with [Le escribo]",
        ]
    if scene.owner == ANFITRION and scene.days_ahead > 0:
        eve = when.meeting - timedelta(days=1)
        shots.append(
            f"Rain proposal, on web: /lluvia/{RONDA_ID}/{when.week} (pick before 21:00 on "
            f"{eve.isoformat()})"
        )
    if scene.owner == COLA:
        shots.append(f"Mi ronda, on the card: «{name(crew.anfitrion)} no puede mañana. ¿Abrís…»")
    if scene.owner == NEWCOMER:
        shots.append(
            f"Mi ronda, under the card: «Así va a ser», «Te espera {name(crew.anfitrion)}…»"
        )
    if scene.days_ahead == 0:
        shots.append(
            f"Mi ronda, on the card: [¿Quién vino hoy?], or /asistencia/{RONDA_ID}/{when.week}"
        )
    if scene.owner in (ANFITRION, COLA):
        shots.append("Flyer: Mi ronda → bottom, under the acta link («Hacer el volante»)")
    shots += [
        f"Lo que hizo el programa: the acta link on Mi ronda, or /acta/{RONDA_ID}",
        "Admin, with the claim (scripts/set_admin.py): /admin/rondas and /admin/programa",
    ]
    if scene.days_ahead <= 1:
        shots.append("Cuaderno: write three lines, then the postcard is offered (eve or day of)")
    return shots


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("account", help="the owner's email in the Auth emulator, or their uid")
    parser.add_argument("--scene", choices=SCENES, default="ronda", help="which shot to set up")
    args = parser.parse_args(argv)

    if missing := seed.missing_hosts(seed.FIRESTORE_HOST):
        print(f"{', '.join(missing)} is not set: this script only writes to the emulators.")
        return 1

    project = seed.project_id()
    db = seed.firestore_client(project)
    real = datetime.now(UTC)
    try:
        built = build(db, args.account, args.scene, real)
    except Refused as why:
        print(why)
        return 1

    moved = "" if built.now == rsvp.local(real) else " (moved into the jobs' hours)"
    print(
        f"Built ronda {RONDA_ID} in {project}: scene {args.scene}, {SCENES[args.scene].shows}. "
        f"{built.owner_name} with {len(built.crew.neighbours)} invented neighbours; meeting "
        f"{built.when.meeting.isoformat()} ({built.when.week}); jobs ran at "
        f"{built.now:%H:%M}{moved}."
    )
    for job, counts in built.jobs.items():
        print(f"  {job}: {counts}")
    print("Shot list:")
    for shot in shot_list(built):
        print(f"  - {shot}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
