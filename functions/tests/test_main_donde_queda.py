"""main.py's ¿Dónde queda? callables: signed-in callers only, the Admin clients and the key
passed through, and a refused photo's reason in the error's details."""

import pytest
from firebase_functions import https_fn

import donde_queda
import main
from tests.fake_firestore import FakeFirestore
from tests.fake_storage import FakeBucket
from tests.test_main import MEMBER, call, error_code

CALLABLES = [main.post_donde_queda, main.pass_donde_queda, main.guess_donde_queda]


@pytest.fixture
def seen(monkeypatch):
    db, bucket = FakeFirestore(), FakeBucket()
    monkeypatch.setattr(main, "_firestore", lambda: db)
    monkeypatch.setattr(main, "_bucket", lambda: bucket)
    monkeypatch.setenv("MODEL_API_KEY", "test-key")
    seen: dict = {"db": db, "bucket": bucket}

    def stand_in(name):
        def run(*args, **kwargs):
            seen[name] = (args, kwargs)
            if error := seen.get("raise"):
                raise error
            return {"status": name}

        return run

    for name in ("post_photo", "pass_turn", "guess"):
        monkeypatch.setattr(donde_queda, name, stand_in(name))
    return seen


@pytest.mark.parametrize("function", CALLABLES)
def test_each_needs_a_signed_in_caller(seen, function):
    with pytest.raises(https_fn.HttpsError) as excinfo:
        call(function, None, {})
    assert error_code(excinfo) == https_fn.FunctionsErrorCode.UNAUTHENTICATED


def test_post_passes_the_caller_the_clients_and_the_key(seen):
    data = {"rondaId": "r1"}

    assert call(main.post_donde_queda, MEMBER, data) == {"status": "post_photo"}
    _, kwargs = seen["post_photo"]
    assert kwargs["uid"] == "demo-001"
    assert kwargs["data"] == data
    assert kwargs["db"] is seen["db"]
    assert kwargs["bucket"] is seen["bucket"]
    assert kwargs["api_key"] == "test-key"


@pytest.mark.parametrize(
    ("function", "name"),
    [(main.pass_donde_queda, "pass_turn"), (main.guess_donde_queda, "guess")],
)
def test_pass_and_guess_run_for_the_caller(seen, function, name):
    assert call(function, MEMBER, {"rondaId": "r1"}) == {"status": name}
    args, _ = seen[name]
    assert args[:3] == (seen["db"], "demo-001", {"rondaId": "r1"})


def test_a_refused_photo_says_why(seen):
    seen["raise"] = donde_queda.DondeQuedaError("failed-precondition", "refused", "houseNumber")

    with pytest.raises(https_fn.HttpsError) as excinfo:
        call(main.post_donde_queda, MEMBER, {})

    assert error_code(excinfo) == https_fn.FunctionsErrorCode.FAILED_PRECONDITION
    assert excinfo.value.details == {"reason": "houseNumber"}


def test_another_refusal_has_no_details(seen):
    seen["raise"] = donde_queda.DondeQuedaError("permission-denied", "not your turn")

    with pytest.raises(https_fn.HttpsError) as excinfo:
        call(main.pass_donde_queda, MEMBER, {})

    assert error_code(excinfo) == https_fn.FunctionsErrorCode.PERMISSION_DENIED
    assert excinfo.value.details is None
