"""main.py's ¿Alguien se suma? callables: signed-in callers only, the Admin client and Spark
passed through, and a held plan's reason in the error's details."""

import pytest
from firebase_functions import https_fn

import main
import shared_plans
import voice_signup as voice
from tests.fake_firestore import FakeFirestore
from tests.test_main import MEMBER, call, error_code

CALLABLES = [
    main.share_small_plan,
    main.withdraw_small_plan,
    main.join_small_plan,
    main.leave_small_plan,
]


@pytest.fixture
def seen(monkeypatch):
    db = FakeFirestore()
    monkeypatch.setattr(main, "_firestore", lambda: db)
    monkeypatch.setenv("MODEL_API_KEY", "test-key")
    seen: dict = {"db": db}

    def stand_in(name):
        def run(*args, **kwargs):
            seen[name] = (args, kwargs)
            if error := seen.get("raise"):
                raise error
            return {"status": name}

        return run

    for name in ("share", "withdraw", "join", "leave"):
        monkeypatch.setattr(shared_plans, name, stand_in(name))
    return seen


@pytest.mark.parametrize("function", CALLABLES)
def test_each_needs_a_signed_in_caller(seen, function):
    with pytest.raises(https_fn.HttpsError) as excinfo:
        call(function, None, {})

    assert error_code(excinfo) == https_fn.FunctionsErrorCode.UNAUTHENTICATED


def test_share_passes_the_caller_the_database_and_a_spark_checker(seen):
    data = {"rondaId": "r1"}

    assert call(main.share_small_plan, MEMBER, data) == {"status": "share"}

    _, kwargs = seen["share"]
    assert kwargs["uid"] == "demo-001"
    assert kwargs["data"] == data
    assert kwargs["db"] is seen["db"]
    assert isinstance(kwargs["checker"], shared_plans.SparkPlan)


@pytest.mark.parametrize(
    ("function", "name"),
    [
        (main.withdraw_small_plan, "withdraw"),
        (main.join_small_plan, "join"),
        (main.leave_small_plan, "leave"),
    ],
)
def test_the_others_run_for_the_caller(seen, function, name):
    assert call(function, MEMBER, {"rondaId": "r1"}) == {"status": name}

    args, _ = seen[name]
    assert args[:3] == (seen["db"], "demo-001", {"rondaId": "r1"})


def test_a_held_plan_says_why(seen):
    seen["raise"] = shared_plans.SharedPlanError("failed-precondition", "held: time", "time")

    with pytest.raises(https_fn.HttpsError) as excinfo:
        call(main.share_small_plan, MEMBER, {})

    assert error_code(excinfo) == https_fn.FunctionsErrorCode.FAILED_PRECONDITION
    assert excinfo.value.details == {"reason": "time"}


def test_another_refusal_has_no_details(seen):
    seen["raise"] = shared_plans.SharedPlanError("permission-denied", "not a member")

    with pytest.raises(https_fn.HttpsError) as excinfo:
        call(main.join_small_plan, MEMBER, {})

    assert error_code(excinfo) == https_fn.FunctionsErrorCode.PERMISSION_DENIED
    assert excinfo.value.details is None


def test_a_model_that_is_down_is_unavailable(seen):
    seen["raise"] = voice.ModelUnavailable("down")

    with pytest.raises(https_fn.HttpsError) as excinfo:
        call(main.share_small_plan, MEMBER, {})

    assert error_code(excinfo) == https_fn.FunctionsErrorCode.UNAVAILABLE
