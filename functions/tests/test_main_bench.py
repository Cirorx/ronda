"""main.py's bench functions (#48): the `answer_bench_offer` callable and the two triggers that
run the bench at once, over the Firestore stand-in. `inspect.unwrap` reaches each function
under its firebase_functions decorator."""

import inspect
from types import SimpleNamespace

import pytest
from firebase_functions import https_fn

import bench
import main
from tests.organiser_fakes import RONDA, WEEK
from tests.test_bench import bench_db

EVA = SimpleNamespace(uid="demo-201", token={})
OFFER = f"{RONDA}_{WEEK}_01"


def call(function, auth, data=None):
    return inspect.unwrap(function)(SimpleNamespace(auth=auth, data=data))


def snapshot(fields):
    return SimpleNamespace(exists=fields is not None, to_dict=lambda: fields)


def event(before, after, **params):
    return SimpleNamespace(
        data=SimpleNamespace(before=snapshot(before), after=snapshot(after)), params=params
    )


@pytest.fixture
def db(monkeypatch):
    db = bench_db()
    db.documents[f"users/demo-201/offers/{OFFER}"] = {
        "rondaId": RONDA,
        "week": WEEK,
        "date": "2026-11-05",
        "hour": "16:00",
        "status": "pending",
        "deadline": main._now().replace(year=2100),
    }
    monkeypatch.setattr(main, "_firestore", lambda: db)
    return db


@pytest.fixture
def runs(monkeypatch):
    ran = []
    monkeypatch.setattr(bench, "run_bench", lambda db, now, **kwargs: ran.append(kwargs))
    return ran


class TestAnswerBenchOffer:
    def test_refuses_a_signed_out_caller(self, db):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.answer_bench_offer, None, {"offerId": OFFER, "take": True})
        assert excinfo.value.code == https_fn.FunctionsErrorCode.UNAUTHENTICATED

    def test_takes_the_callers_own_offer(self, db):
        result = call(main.answer_bench_offer, EVA, {"offerId": OFFER, "take": True})

        assert result["status"] == "taken"
        assert db.documents[f"users/demo-201/offers/{OFFER}"]["status"] == "taken"

    @pytest.mark.parametrize(
        ("data", "code"),
        [
            (None, https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"offerId": OFFER, "take": "sí"}, https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"offerId": "otra", "take": False}, https_fn.FunctionsErrorCode.NOT_FOUND),
        ],
    )
    def test_maps_each_refusal_to_its_code(self, db, data, code):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.answer_bench_offer, EVA, data)
        assert excinfo.value.code == code


class TestTriggers:
    def test_an_answer_that_changes_runs_its_rondas_bench(self, runs, monkeypatch):
        monkeypatch.setattr(main, "_firestore", lambda: None)
        trigger = inspect.unwrap(main.bench_on_answer)

        trigger(event(None, {"week": WEEK, "answer": "no"}, rondaId=RONDA, uid="u"))
        trigger(
            event({"week": WEEK, "answer": "no"}, {"week": WEEK, "answer": "yes"}, rondaId=RONDA)
        )
        trigger(
            event({"week": WEEK, "answer": "no"}, {"week": WEEK, "answer": "no"}, rondaId=RONDA)
        )

        assert [r["ronda_id"] for r in runs] == [RONDA, RONDA]

    def test_an_answered_offer_runs_its_rondas_bench(self, runs, monkeypatch):
        monkeypatch.setattr(main, "_firestore", lambda: None)
        trigger = inspect.unwrap(main.bench_on_offer)
        pending = {"status": "pending", "rondaId": RONDA}

        trigger(event(pending, {**pending, "status": "declined"}))
        trigger(event(pending, {**pending, "status": "taken"}))
        trigger(event(pending, {**pending, "status": "expired"}))
        trigger(event({**pending, "status": "taken"}, {**pending, "status": "taken"}))
        trigger(event(None, pending))

        assert [r["ronda_id"] for r in runs] == [RONDA, RONDA]

    @pytest.mark.parametrize("function", [main.bench_on_answer, main.bench_on_offer])
    def test_the_triggers_get_the_model_keys_in_the_region(self, function):
        endpoint = function.__firebase_endpoint__
        assert endpoint.region == [main.REGION]
        assert {s["key"] for s in endpoint.secretEnvironmentVariables} == {
            "MODEL_API_KEY",
            "BASETEN_API_KEY",
        }


class TestAnswerWaitlist:
    @pytest.fixture
    def waiting(self, monkeypatch):
        from tests.fake_firestore import FakeFirestore

        db = FakeFirestore(
            {
                "waiting/demo-201": {
                    "seatId": "s",
                    "status": "didntFill",
                    "alternatives": [],
                    "deadline": "2026-11-15",
                    "start": "2026-11-21",
                }
            }
        )
        monkeypatch.setattr(main, "_firestore", lambda: db)
        return db

    def test_refuses_a_signed_out_caller(self, waiting):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.answer_waitlist, None, {"choice": "wait"})
        assert excinfo.value.code == https_fn.FunctionsErrorCode.UNAUTHENTICATED

    def test_records_the_callers_pick(self, waiting):
        assert call(main.answer_waitlist, EVA, {"choice": "wait"})["choice"] == "wait"
        assert waiting.documents["waiting/demo-201"]["status"] == "open"

    @pytest.mark.parametrize(
        ("data", "code"),
        [
            (None, https_fn.FunctionsErrorCode.INVALID_ARGUMENT),
            ({"choice": "join"}, https_fn.FunctionsErrorCode.FAILED_PRECONDITION),
        ],
    )
    def test_maps_each_refusal_to_its_code(self, waiting, data, code):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(main.answer_waitlist, EVA, data)
        assert excinfo.value.code == code
