"""The callables' own code: auth checks, arguments and error codes, over the Firestore stand-in.
`inspect.unwrap` reaches the function under the firebase_functions decorator."""

import inspect
from types import SimpleNamespace

import pytest
from firebase_functions import https_fn

import main
from tests.fake_firestore import FakeFirestore
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
