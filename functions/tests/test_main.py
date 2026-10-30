"""The callables' own code: auth checks, arguments and error codes, over the Firestore stand-in.
`inspect.unwrap` reaches the function under the firebase_functions decorator."""

import copy
import inspect
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
from firebase_functions import https_fn, scheduler_fn

import main
from tests.fake_firestore import FakeFirestore
from tests.fake_storage import FakeBucket, StoredObject
from tests.test_proposals import invented_sign_ups

ADMIN = SimpleNamespace(uid="demo-admin", token={"admin": True})
MEMBER = SimpleNamespace(uid="demo-001", token={})


def call(function, auth, data=None):
    return inspect.unwrap(function)(SimpleNamespace(auth=auth, data=data))


@pytest.fixture
def db(monkeypatch) -> FakeFirestore:
    db = FakeFirestore(invented_sign_ups())
    monkeypatch.setattr(main, "_firestore", lambda: db)
    return db


def error_code(excinfo) -> https_fn.FunctionsErrorCode:
    return excinfo.value.code


class TestAuth:
    @pytest.mark.parametrize("function", [main.propose_groups, main.approve_proposal])
    def test_refuses_a_signed_out_caller(self, function, db):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(function, None, {"proposalId": "x"})
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.UNAUTHENTICATED

    @pytest.mark.parametrize("function", [main.propose_groups, main.approve_proposal])
    def test_refuses_a_member_without_the_admin_claim(self, function, db):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(function, MEMBER, {"proposalId": "x"})
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.PERMISSION_DENIED
        assert not [p for p in db.documents if p.startswith(("proposals/", "rondas/"))]


class TestProposeGroups:
    def test_writes_a_pending_proposal_for_the_admin(self, db):
        summary = call(main.propose_groups, ADMIN)

        assert db.documents[f"proposals/{summary['proposalId']}"]["status"] == "pending"


class TestApproveProposal:
    def test_approves_then_undoes(self, db):
        proposal_id = call(main.propose_groups, ADMIN)["proposalId"]

        approved = call(main.approve_proposal, ADMIN, {"proposalId": proposal_id})
        assert db.documents[f"rondas/{approved['rondaIds'][0]}"]["status"] == "forming"

        call(main.approve_proposal, ADMIN, {"proposalId": proposal_id, "undo": True})
        assert db.documents[f"proposals/{proposal_id}"]["status"] == "pending"

    @pytest.mark.parametrize("data", [None, {}, {"proposalId": ""}, {"proposalId": "a/b"}])
    def test_needs_a_proposal_id(self, data, db):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.approve_proposal, ADMIN, data)
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.INVALID_ARGUMENT

    def test_answers_not_found_for_an_unknown_proposal(self, db):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.approve_proposal, ADMIN, {"proposalId": "nope"})
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.NOT_FOUND


class TestPing:
    def test_answers_its_region(self):
        response = inspect.unwrap(main.ping)(None)

        assert response.status_code == 200
        assert b"southamerica-east1" in response.get_data()

    def test_solver_ping_solves(self):
        assert call(main.solver_ping, None)["status"] == "OPTIMAL"


def test_the_admin_app_starts_on_import_so_callables_can_verify_tokens():
    import firebase_admin

    assert firebase_admin.get_app() is not None


def test_firestore_is_the_admin_client(monkeypatch):
    from firebase_admin import firestore

    monkeypatch.setattr(firestore, "client", lambda: "client")

    assert main._firestore() == "client"


def test_now_is_aware_utc():
    assert main._now().utcoffset().total_seconds() == 0


NOTE_PATH = "audio/demo-001/note-1.wav"
FIELDS = {"firstName": "Graciela", "ageBand": "60-69"}


class TestExtract:
    @pytest.fixture
    def reads(self, monkeypatch):
        """Stands in for the Admin clients and `read_voice_note`; returns what it was given."""
        import voice_signup

        db = FakeFirestore({"users/demo-001": {"terms": {"version": "2026-10-27"}}})
        monkeypatch.setattr(main, "_firestore", lambda: db)
        monkeypatch.setattr(main, "_bucket", lambda: SimpleNamespace(blob=lambda path: path))
        monkeypatch.setenv("MODEL_API_KEY", "test-key")
        seen: dict = {}

        def read(**kwargs):
            seen.update(kwargs)
            if error := seen.get("raise"):
                raise error
            return FIELDS

        monkeypatch.setattr(voice_signup, "read_voice_note", read)
        return seen

    def test_refuses_a_signed_out_caller(self, reads):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.extract, None, {"path": NOTE_PATH})
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.UNAUTHENTICATED

    def test_reads_the_callers_note_with_their_user_document(self, reads):
        assert call(main.extract, MEMBER, {"path": NOTE_PATH}) == FIELDS
        assert reads["uid"] == "demo-001"
        assert reads["path"] == NOTE_PATH
        assert reads["user"] == {"terms": {"version": "2026-10-27"}}
        assert reads["blob"](NOTE_PATH) == NOTE_PATH
        assert reads["api_key"] == "test-key"

    def test_passes_no_path_when_the_data_is_not_a_map(self, reads):
        call(main.extract, MEMBER, "audio/demo-001/note-1.wav")
        assert reads["path"] is None

    @pytest.mark.parametrize(
        ("error", "code"),
        [
            ("TermsMissing", https_fn.FunctionsErrorCode.FAILED_PRECONDITION),
            ("BadVoiceNote", https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ("PermissionError", https_fn.FunctionsErrorCode.PERMISSION_DENIED),
            ("NotFound", https_fn.FunctionsErrorCode.NOT_FOUND),
            ("ModelUnavailable", https_fn.FunctionsErrorCode.UNAVAILABLE),
        ],
    )
    def test_maps_each_failure_to_its_code(self, reads, monkeypatch, error, code):
        from google.api_core.exceptions import NotFound

        import voice_signup

        raised = {
            "TermsMissing": voice_signup.TermsMissing("demo-001"),
            "BadVoiceNote": voice_signup.BadVoiceNote("x"),
            "PermissionError": PermissionError("x"),
            "NotFound": NotFound("x"),
            "ModelUnavailable": voice_signup.ModelUnavailable("x"),
        }[error]
        reads["raise"] = raised

        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.extract, MEMBER, {"path": NOTE_PATH})
        assert error_code(excinfo) == code


def test_bucket_is_the_default_admin_bucket(monkeypatch):
    from firebase_admin import storage

    monkeypatch.setattr(storage, "bucket", lambda: "bucket")

    assert main._bucket() == "bucket"


class TestVoiceSignUp:
    """`extract` end to end with only Meta faked: the real `read_voice_note` over the Firestore and
    Storage stand-ins. The phone's writes after it are proven in `rules/users.test.js`."""

    def test_extract_writes_no_document_and_leaves_no_note(self, monkeypatch):
        import httpx
        import openai

        from tests.test_voice_signup import GRACIELA, spark_returning, transcript, wav

        documents = {"users/demo-001": {"terms": {"version": "2026-10-27"}}}
        db = FakeFirestore(copy.deepcopy(documents))
        bucket = FakeBucket({NOTE_PATH: StoredObject(wav(), datetime.now(UTC))})
        monkeypatch.setattr(main, "_firestore", lambda: db)
        monkeypatch.setattr(main, "_bucket", lambda: bucket)
        monkeypatch.setenv("MODEL_API_KEY", "test-key")
        voice_transcribe = httpx.MockTransport(lambda _: transcript("Hola, soy Graciela"))
        client = httpx.Client
        monkeypatch.setattr(httpx, "Client", lambda: client(transport=voice_transcribe))
        monkeypatch.setattr(openai, "OpenAI", lambda **_: spark_returning(GRACIELA)[0])

        fields = call(main.extract, MEMBER, {"path": NOTE_PATH})

        assert fields["firstName"] == "Graciela"
        assert set(fields) == {"firstName", "ageBand", "barrio", "pretexts", "slots", "brings"}
        assert "audio/" not in repr(fields)
        assert db.documents == documents
        assert bucket.objects == {}


SWEEP_TIME = datetime(2026, 10, 29, 15, 0, tzinfo=UTC)


class TestSweepAudio:
    def test_runs_every_hour_in_the_region_on_one_instance(self):
        endpoint = main.sweep_audio.__firebase_endpoint__

        assert endpoint.scheduleTrigger["schedule"] == "every 1 hours"
        assert endpoint.region == [main.REGION]
        assert endpoint.maxInstances == 1

    def test_deletes_the_notes_older_than_an_hour_before_the_scheduled_time(self, monkeypatch):
        bucket = FakeBucket(
            {
                "audio/demo-001/old.wav": StoredObject(b"", SWEEP_TIME - timedelta(hours=2)),
                "audio/demo-001/new.wav": StoredObject(b"", SWEEP_TIME - timedelta(minutes=5)),
            }
        )
        monkeypatch.setattr(main, "_bucket", lambda: bucket)

        event = scheduler_fn.ScheduledEvent(job_name="sweep", schedule_time=SWEEP_TIME)
        inspect.unwrap(main.sweep_audio)(event)

        assert set(bucket.objects) == {"audio/demo-001/new.wav"}


class TestMakeMateFlyer:
    @pytest.fixture
    def made(self, monkeypatch):
        """Stands in for the Admin clients and `make_mate_flyer`; returns what it was given."""
        import mate_flyer

        db, bucket = FakeFirestore(), FakeBucket()
        monkeypatch.setattr(main, "_firestore", lambda: db)
        monkeypatch.setattr(main, "_bucket", lambda: bucket)
        monkeypatch.setenv("MODEL_API_KEY", "test-key")
        seen: dict = {"db": db, "bucket": bucket}

        def make(**kwargs):
            seen["call"] = kwargs
            if error := seen.get("raise"):
                raise error
            return {"flyerId": "flyer-1"}

        monkeypatch.setattr(mate_flyer, "make_mate_flyer", make)
        return seen

    def test_refuses_a_signed_out_caller(self, made):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.make_mate_flyer, None, {"rondaId": "r1"})
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.UNAUTHENTICATED
        assert "call" not in made

    def test_makes_the_callers_flyer_with_the_admin_clients_and_the_key(self, made):
        data = {"rondaId": "r1", "photoPath": "flyer_photos/demo-001/p.jpg"}

        assert call(main.make_mate_flyer, MEMBER, data) == {"flyerId": "flyer-1"}
        seen = made["call"]
        assert seen["uid"] == "demo-001"
        assert seen["data"] == data
        assert seen["db"] is made["db"]
        assert seen["bucket"] is made["bucket"]
        assert seen["api_key"] == "test-key"
        assert seen["now"].utcoffset().total_seconds() == 0

    def test_maps_a_flyer_error_to_its_code(self, made):
        import mate_flyer

        made["raise"] = mate_flyer.FlyerError("failed-precondition", "nothing found")

        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.make_mate_flyer, MEMBER, {})
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.FAILED_PRECONDITION


class TestDispatch:
    def test_runs_on_the_hour_in_montevideo_in_the_region_on_one_instance(self):
        endpoint = main.dispatch.__firebase_endpoint__

        assert endpoint.scheduleTrigger["schedule"] == "0 * * * *"
        assert endpoint.scheduleTrigger["timeZone"] == "America/Montevideo"
        assert endpoint.region == [main.REGION]
        assert endpoint.maxInstances == 1

    def test_runs_every_job_at_the_scheduled_time(self, monkeypatch):
        import jobs

        seen = {}
        monkeypatch.setattr(main, "_firestore", lambda: "db")
        monkeypatch.setattr(jobs, "run_due", lambda db, now, context: seen.update(db=db, now=now))

        event = scheduler_fn.ScheduledEvent(job_name="dispatch", schedule_time=SWEEP_TIME)
        inspect.unwrap(main.dispatch)(event)

        assert seen == {"db": "db", "now": SWEEP_TIME}


class TestRunJob:
    @pytest.fixture
    def runs(self, monkeypatch):
        import jobs

        seen: dict = {}
        monkeypatch.setattr(main, "_firestore", lambda: "db")

        def run(name, db, now, context):
            if name != "rsvp_push":
                raise jobs.UnknownJob(name)
            seen.update(name=name, db=db, now=now, force=context.force)
            return {"pushed": 1}

        monkeypatch.setattr(jobs, "run", run)
        return seen

    @pytest.mark.parametrize(
        ("auth", "code"),
        [
            (None, https_fn.FunctionsErrorCode.UNAUTHENTICATED),
            (MEMBER, https_fn.FunctionsErrorCode.PERMISSION_DENIED),
        ],
    )
    def test_is_for_the_admin_only(self, runs, auth, code):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.run_job, auth, {"name": "rsvp_push"})
        assert error_code(excinfo) == code
        assert runs == {}

    def test_runs_a_job_now(self, runs):
        before = datetime.now(UTC)

        assert call(main.run_job, ADMIN, {"name": "rsvp_push"}) == {
            "name": "rsvp_push",
            "pushed": 1,
        }
        assert runs["now"] >= before
        assert runs["force"] is False

    def test_runs_a_job_at_a_given_time_and_forced(self, runs):
        call(main.run_job, ADMIN, {"name": "rsvp_push", "now": "2026-10-29T19:00:00-03:00",
                                   "force": True})  # fmt: skip

        assert runs["now"] == datetime(2026, 10, 29, 22, 0, tzinfo=UTC)
        assert runs["force"] is True

    @pytest.mark.parametrize(
        "data",
        [
            {"name": "nope"},
            None,
            {"name": "rsvp_push", "now": "yesterday"},
            {"name": "rsvp_push", "now": 5},
            {"name": "rsvp_push", "now": "2026-10-29T19:00:00"},
        ],
    )
    def test_refuses_bad_arguments(self, runs, data):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.run_job, ADMIN, data)
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.INVALID_ARGUMENT


class TestAnswerRsvp:
    @pytest.fixture
    def ronda(self, monkeypatch):
        from tests.test_rsvp import documents

        db = FakeFirestore(documents())
        monkeypatch.setattr(main, "_firestore", lambda: db)
        monkeypatch.setattr(main, "_now", lambda: datetime(2026, 10, 29, 22, 0, tzinfo=UTC))
        return db

    def test_refuses_a_signed_out_caller(self, ronda):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.answer_rsvp, None, {"rondaId": "ronda-1", "answer": "yes"})
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.UNAUTHENTICATED

    def test_records_the_callers_answer(self, ronda):
        result = call(
            main.answer_rsvp, MEMBER, {"rondaId": "ronda-1", "answer": "yes", "week": "2026-W44"}
        )

        assert result == {"week": "2026-W44", "answer": "yes"}
        assert ronda.documents["rondas/ronda-1/weeks/2026-W44"]["rsvp"] == {"demo-001": "yes"}

    def test_pauses_with_the_no(self, ronda):
        call(main.answer_rsvp, MEMBER, {"rondaId": "ronda-1", "answer": "no", "pauseWeeks": 2})

        assert ronda.documents["rondas/ronda-1/members/demo-001"]["state"] == "paused"

    @pytest.mark.parametrize(
        ("data", "code"),
        [
            (None, https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"answer": "yes"}, https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"rondaId": "a/b", "answer": "yes"}, https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"rondaId": "ronda-1", "answer": "yes", "week": 44},
             https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"rondaId": "ronda-1", "answer": "maybe"},
             https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"rondaId": "nope", "answer": "yes"}, https_fn.FunctionsErrorCode.NOT_FOUND),
            ({"rondaId": "ronda-1", "answer": "yes", "week": "2026-W43"},
             https_fn.FunctionsErrorCode.FAILED_PRECONDITION),
        ],
    )  # fmt: skip
    def test_maps_each_refusal_to_its_code(self, ronda, data, code):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.answer_rsvp, MEMBER, data)
        assert error_code(excinfo) == code

    def test_refuses_someone_outside_the_ronda(self, ronda):
        stranger = SimpleNamespace(uid="demo-999", token={})

        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.answer_rsvp, stranger, {"rondaId": "ronda-1", "answer": "yes"})
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.PERMISSION_DENIED


class TestAnswerSeguimos:
    @pytest.fixture
    def ronda(self, monkeypatch):
        from tests.test_seguimos import ASK, ask, documents

        db = FakeFirestore(documents())
        ask(db)
        monkeypatch.setattr(main, "_firestore", lambda: db)
        monkeypatch.setattr(main, "_now", lambda: ASK + timedelta(hours=1))
        return db

    def test_refuses_a_signed_out_caller(self, ronda):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.answer_seguimos, None, {"rondaId": "ronda-1", "answer": "yes"})
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.UNAUTHENTICATED

    def test_records_the_callers_answer_privately(self, ronda):
        result = call(main.answer_seguimos, MEMBER, {"rondaId": "ronda-1", "answer": "yes"})

        assert result == {"answer": "yes"}
        assert ronda.documents["rondas/ronda-1/private/seguimos"]["answers"] == {"demo-001": "yes"}

    @pytest.mark.parametrize(
        ("data", "code"),
        [
            (None, https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"answer": "yes"}, https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"rondaId": "a/b", "answer": "yes"}, https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"rondaId": "ronda-1", "answer": "maybe"},
             https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"rondaId": "nope", "answer": "yes"}, https_fn.FunctionsErrorCode.NOT_FOUND),
            ({"rondaId": "ronda-1", "choice": "wait"},
             https_fn.FunctionsErrorCode.FAILED_PRECONDITION),
        ],
    )  # fmt: skip
    def test_maps_each_refusal_to_its_code(self, ronda, data, code):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.answer_seguimos, MEMBER, data)
        assert error_code(excinfo) == code

    def test_refuses_someone_outside_the_ronda(self, ronda):
        stranger = SimpleNamespace(uid="demo-999", token={})

        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.answer_seguimos, stranger, {"rondaId": "ronda-1", "answer": "yes"})
        assert error_code(excinfo) == https_fn.FunctionsErrorCode.PERMISSION_DENIED
