"""demo_ronda.py against the running emulators; skipped when their hosts aren't set, and where
the functions' packages aren't installed (the scripts' own environment, as in CI).

    cd functions
    FIRESTORE_EMULATOR_HOST=127.0.0.1:8088 FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \\
        venv/bin/pytest -p no:cacheprovider --rootdir ../scripts -c ../scripts/pyproject.toml \\
        ../scripts/tests/test_demo_ronda.py

Uses its own project id, so it never touches what the app's project holds in the same emulators.
The owner is an invented account, `test-owner`, with an invented profile.
"""

import json
import os
import urllib.request
from datetime import UTC, date, datetime, timedelta

import pytest

FIRESTORE = os.environ.get("FIRESTORE_EMULATOR_HOST")
AUTH = os.environ.get("FIREBASE_AUTH_EMULATOR_HOST")

pytestmark = pytest.mark.skipif(
    not (FIRESTORE and AUTH),
    reason="needs FIRESTORE_EMULATOR_HOST and FIREBASE_AUTH_EMULATOR_HOST",
)

demo_ronda = pytest.importorskip("demo_ronda", reason="needs the functions' packages")
import reset  # noqa: E402
import seed  # noqa: E402

PROJECT = "demo-ronda-film"
OWNER = "test-owner"
EMAIL = "vecina@example.com"
RONDA = demo_ronda.RONDA_ID
NOON = datetime(2026, 11, 3, 15, 0, tzinfo=UTC)
"""Tuesday 2026-11-03 at 12:00 in Montevideo: the meeting is Wednesday 2026-11-04."""
MEETING = date(2026, 11, 4)


@pytest.fixture
def db(monkeypatch):
    monkeypatch.setenv("GCLOUD_PROJECT", PROJECT)
    reset.clear(PROJECT)
    client = seed.firestore_client(PROJECT)
    client.document(f"users/{OWNER}").set(
        {"firstName": "Vecina", "ageBand": "60-69", "barrio": "el-pinar-sur", "brings": ["pan"]}
    )
    yield client
    reset.clear(PROJECT)


def build(db, scene: str = "ronda", now: datetime = NOON):
    return demo_ronda.build(db, OWNER, scene, now)


def get(db, path: str) -> dict:
    snapshot = db.document(path).get()
    assert snapshot.exists, path
    return snapshot.to_dict()


def paths(db, root) -> set[str]:
    """Every document path under `root` (a document), itself included when it exists."""
    found = {root.path} if root.get().exists else set()
    for collection in root.collections():
        for reference in collection.list_documents():
            found |= paths(db, reference)
    return found


def tree(db) -> set[str]:
    """What a run leaves for the filmed ronda: its documents, its acta and its runs."""
    runs = {run.path for run in db.collection("agent_runs").list_documents()}
    acta = paths(db, db.document(f"acta/{RONDA}"))
    return paths(db, db.document(f"rondas/{RONDA}")) | acta | runs


class TestTheRonda:
    def test_is_what_aprobar_and_the_setup_sheet_leave(self, db):
        built = build(db)

        ronda = get(db, f"rondas/{RONDA}")
        assert ronda["slot"] == {"day": "wed", "time": "afternoon", "hour": "16:00"}
        assert ronda["place"] == demo_ronda.PLACE
        assert ronda["hosts"]["anfitrion"] == OWNER
        assert ronda["hosts"]["cola"] == built.crew.cola
        assert ronda["agentCard"] is True
        assert ronda["status"] == "forming"
        assert ronda["openSeatFromWeek"] == 4
        assert len(ronda["turns"]) == 3
        members = {m.id for m in db.collection(f"rondas/{RONDA}/members").list_documents()}
        assert members == {OWNER, *built.crew.neighbours}
        assert all(uid.startswith("demo-") for uid in built.crew.neighbours)
        assert get(db, f"users/{OWNER}/rondas/{RONDA}")

    def test_puts_the_meeting_tomorrow_on_the_real_clock(self, db):
        built = build(db)

        assert built.when.meeting == MEETING
        assert get(db, f"rondas/{RONDA}/views/week")["date"] == MEETING.isoformat()
        assert get(db, f"rondas/{RONDA}/weeks/2026-W45")["rsvpSentAt"]

    def test_is_old_enough_for_the_hosts_flyer(self, db):
        build(db)

        created = demo_ronda.rsvp.local(get(db, f"rondas/{RONDA}")["createdAt"]).date()
        assert created == MEETING - timedelta(weeks=4)
        assert (NOON.date() - created).days >= 21
        first_week = created  # the slot day itself: week 1
        assert (MEETING - first_week).days // 7 + 1 >= 4
        assert all(
            date.fromisoformat(week.get().to_dict()["date"]) > created
            for week in db.collection(f"rondas/{RONDA}/weeks").list_documents()
        )

    def test_leaves_venis_to_the_owner_and_shows_who_is_coming(self, db):
        build(db)

        view = get(db, f"rondas/{RONDA}/views/week")
        assert len(view["going"]) == 2
        assert OWNER not in {person["uid"] for person in view["going"]}
        assert not db.document(f"rondas/{RONDA}/answers/{OWNER}").get().exists

    def test_has_the_organisers_card_with_who_opens_and_who_is_new(self, db):
        built = build(db)

        card = get(db, f"rondas/{RONDA}/views/card")
        assert card["status"] == "agent"
        assert card["blocks"] == ["host", "newcomer"]
        assert card["model"] == demo_ronda.MODEL_NAME
        words = json.dumps(card["messages"], ensure_ascii=False)
        assert "Vecina" in words
        assert built.people[built.crew.newcomer]["firstName"] in words

    def test_asks_the_host_who_waits_for_the_newcomer(self, db):
        built = build(db)

        welcome = get(db, f"rondas/{RONDA}/welcomes/{built.crew.newcomer}")
        assert welcome["status"] == "open"
        assert welcome["date"] == MEETING.isoformat()

    def test_asks_seguimos(self, db):
        build(db)

        assert get(db, f"rondas/{RONDA}/seguimos/{OWNER}")["status"] == "open"

    def test_makes_the_buddy_choice_due_and_tells_the_owner_who_missed(self, db):
        built = build(db)

        assert get(db, f"rondas/{RONDA}/weeks/2026-W44")["date"] == "2026-10-28"
        ask = get(db, f"rondas/{RONDA}/buddy_asks/{OWNER}")
        assert ask["asks"][0]["firstName"] == built.people[built.crew.missed]["firstName"]
        assert "buddyUid" not in get(db, f"users/{OWNER}")

    def test_proposes_a_move_to_the_owner_for_the_rain(self, db):
        build(db)

        move = get(db, f"rondas/{RONDA}/moves/2026-W45")
        assert move["hostUid"] == OWNER
        assert move["status"] == "pending"
        assert {option["id"] for option in move["options"]} == {"covered", "postpone", "asIs"}


class TestTheScenes:
    def test_rain_puts_the_meeting_two_days_out(self, db):
        built = build(db, "rain")

        assert built.when.meeting == MEETING + timedelta(days=1)
        assert get(db, f"rondas/{RONDA}/moves/2026-W45")["hostUid"] == OWNER

    def test_handoff_asks_the_owner_to_open(self, db):
        built = build(db, "handoff")

        ronda = get(db, f"rondas/{RONDA}")
        assert ronda["hosts"]["cola"] == OWNER
        assert get(db, f"rondas/{RONDA}/weeks/2026-W45")["rsvp"][built.crew.anfitrion] == "no"
        assert get(db, f"rondas/{RONDA}/handoff_asks/{OWNER}")["status"] == "open"

    def test_newcomer_shows_asi_va_a_ser_with_who_waits(self, db):
        built = build(db, "newcomer")

        welcome = get(db, f"rondas/{RONDA}/welcomes/{OWNER}")
        assert welcome["status"] == "set"
        assert welcome["waiterUid"] == built.crew.anfitrion
        assert welcome["sign"] == demo_ronda.SIGN
        assert not db.document(f"rondas/{RONDA}/seguimos/{OWNER}").get().exists

    def test_attendance_writes_todays_roll_for_the_owner(self, db):
        build(db, "attendance")

        roll = get(db, f"rondas/{RONDA}/rolls/2026-W45")
        assert roll["date"] == "2026-11-03"
        assert roll["askedUid"] == OWNER
        assert get(db, f"rondas/{RONDA}/views/week")["week"] == "2026-W45"


class TestRunningItAgain:
    def test_starts_over_from_the_same_state(self, db):
        build(db, "handoff")
        build(db)
        first = tree(db)

        build(db)

        assert tree(db) == first
        assert not db.document(f"rondas/{RONDA}/handoff_asks/{OWNER}").get().exists

    def test_leaves_nothing_of_the_last_scene_behind(self, db):
        build(db)
        build(db, "handoff")

        # A fresh ¿seguimos?, not the last scene's, closed by this one's ¿Venís? push.
        assert get(db, f"rondas/{RONDA}/seguimos/{OWNER}")["status"] == "open"

    def test_leaves_other_rondas_alone(self, db):
        db.document("rondas/someone-else").set(
            {"pretext": "truco", "slot": {"day": "wed", "time": "afternoon"}, "status": "active"}
        )
        db.document(f"rondas/someone-else/members/{OWNER}").set({"state": "active"})

        build(db)

        assert not list(db.collection("rondas/someone-else/weeks").list_documents())
        assert not list(db.collection("rondas/someone-else/views").list_documents())


class TestTheClock:
    @pytest.mark.parametrize(
        ("hour", "moved"), [(3, 9), (8, 9), (9, 9), (14, 14), (20, 20), (21, 20), (23, 20)]
    )
    def test_moves_the_jobs_into_the_hours_they_send_in(self, hour, moved):
        now = datetime(2026, 11, 3, hour, 30, tzinfo=demo_ronda.rsvp.MONTEVIDEO)

        assert demo_ronda.job_clock(now).hour == moved
        assert demo_ronda.job_clock(now).date() == now.date()


class TestRefusing:
    def test_without_the_firestore_emulator(self, monkeypatch, capsys):
        monkeypatch.delenv("FIRESTORE_EMULATOR_HOST")

        assert demo_ronda.main([OWNER]) == 1
        assert "FIRESTORE_EMULATOR_HOST" in capsys.readouterr().out

    def test_an_account_without_a_profile(self, db, capsys):
        assert demo_ronda.main(["nobody-here"]) == 1
        assert "onboarding" in capsys.readouterr().out
        assert not db.document(f"rondas/{RONDA}").get().exists

    def test_an_email_the_auth_emulator_doesnt_know(self, db, capsys):
        assert demo_ronda.main([EMAIL]) == 1
        assert "sign in once" in capsys.readouterr().out


def test_finds_the_owner_by_email_and_prints_the_shot_list(db, capsys):
    request = urllib.request.Request(
        f"http://{AUTH}/identitytoolkit.googleapis.com/v1/projects/{PROJECT}/accounts",
        data=json.dumps({"localId": OWNER, "email": EMAIL}).encode(),
        headers={"Authorization": "Bearer owner", "Content-Type": "application/json"},
    )
    urllib.request.urlopen(request, timeout=30).close()

    assert demo_ronda.main([EMAIL, "--scene", "rain"]) == 0

    out = capsys.readouterr().out
    assert f"/lluvia/{RONDA}/" in out
    assert "Shot list:" in out


def test_builds_the_ronda_in_the_owners_barrio_and_band(db, monkeypatch):
    for name in ("BARRIO", "BAND", "HOUR"):
        monkeypatch.setattr(demo_ronda, name, getattr(demo_ronda, name))
    seed.write(db, {f"users/{OWNER}": {"firstName": "Ciro", "ageBand": "18-29"}})

    assert demo_ronda.main([OWNER, "--barrio", "palermo", "--band", "evening"]) == 0

    ronda = get(db, f"rondas/{RONDA}")
    assert ronda["barrio"] == "palermo"
    assert ronda["slot"]["time"] == "evening"
    assert ronda["slot"]["hour"] == "19:00"
