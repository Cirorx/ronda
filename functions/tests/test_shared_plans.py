"""¿Alguien se suma? (shared_plans.py): the checks before a plan is shared, what each member's
card holds, joining and taking it back, and the hourly job. Muse Spark 1.3 is a scripted
stand-in. The ronda is the rain check's: Mirta (demo-101), Jorge, Ana and Facu in El Pinar Sur;
every person is invented."""

from datetime import timedelta
from types import SimpleNamespace

import pytest

import shared_plans as sp
import voice_signup as voice
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import RONDA, at, documents

NOW = at(4, 10)  # Wednesday 2026-11-04, 10:00 in Montevideo
MIRTA, JORGE, ANA, FACU = "demo-101", "demo-102", "demo-103", "demo-104"
CARD = f"rondas/{RONDA}/plan_cards/"
PLAN = f"rondas/{RONDA}/shared_plans/"

WALK = {
    "rondaId": RONDA,
    "activity": "Caminar 30 minutos por la rambla",
    "place": "desde la parada 23",
    "kind": "walk",
    "date": "2026-11-05",
    "time": "19:00",
}


class Spark:
    def __init__(self, reason: str = "", error: Exception | None = None):
        self._reason, self._error, self.seen = reason, error, []

    def reason(self, line: str) -> str:
        self.seen.append(line)
        if self._error:
            raise self._error
        return self._reason


@pytest.fixture
def db() -> FakeFirestore:
    docs = documents()
    for uid in (MIRTA, JORGE, ANA, FACU):
        docs[f"users/{uid}"] = {**docs[f"users/{uid}"], "terms": {"version": "2026-10-27"}}
    return FakeFirestore(docs)


def share(db, uid=MIRTA, now=NOW, checker=None, **changes):
    return sp.share(uid=uid, data={**WALK, **changes}, db=db, checker=checker or Spark(), now=now)


def held(db, **changes) -> str:
    with pytest.raises(sp.SharedPlanError) as excinfo:
        share(db, **changes)
    assert excinfo.value.code == "failed-precondition"
    return excinfo.value.reason


def card(db, uid):
    return db.documents.get(CARD + uid)


class TestChecks:
    @pytest.mark.parametrize(
        ("changes", "reason"),
        [
            ({"kind": "call"}, "place"),
            ({"kind": "noPhone"}, "place"),
            ({"date": "2026-11-03"}, "past"),
            ({"date": "2026-11-20"}, "past"),
            ({"time": "08:30"}, "time"),
            ({"time": "21:30"}, "time"),
            ({"place": ""}, "place"),
            ({"place": "al 099 123 456"}, "phone"),
            ({"activity": "Caminar, llamame al 2601 2345"}, "phone"),
            ({"activity": "Caminar y comprar pan"}, "money"),
            ({"activity": "Caminar, traé plata"}, "money"),
            ({"activity": "Caminar con 🙂"}, "words"),
            ({"activity": "Si quieres, caminemos"}, "words"),
            ({"place": "en lo de Marta"}, "address"),
            ({"place": "en Av. Giannattasio 4500"}, "address"),
            ({"activity": "Caminar por mi salud"}, "other"),
            ({"activity": "Caminar con mi hija"}, "other"),
        ],
    )
    def test_code_holds_a_plan_with_the_reason(self, db, changes, reason):
        assert held(db, **changes) == reason
        assert PLAN + MIRTA not in db.documents

    def test_a_plan_at_the_edges_of_the_hours_is_fine(self, db):
        assert share(db, time="09:00") == {"status": "shared"}
        assert share(db, time="21:00") == {"status": "shared"}

    def test_the_plan_is_checked_in_montevideo_time(self, db):
        # 2026-11-05 00:30 in Montevideo is still "tomorrow" there at 23:00 UTC-3 today.
        late = at(4, 23, 30)

        assert held(db, now=late, date="2026-11-04", time="19:00") == "past"

    def test_spark_reads_it_after_code_and_can_hold_it(self, db):
        spark = Spark("address")

        with pytest.raises(sp.SharedPlanError) as excinfo:
            share(db, checker=spark)

        assert excinfo.value.reason == "address"
        assert spark.seen == ["Caminar 30 minutos por la rambla\ndesde la parada 23"]
        assert PLAN + MIRTA not in db.documents

    def test_spark_is_not_asked_when_code_already_held_it(self, db):
        spark = Spark()

        with pytest.raises(sp.SharedPlanError):
            share(db, checker=spark, time="08:00")

        assert spark.seen == []

    @pytest.mark.parametrize(
        "changes",
        [
            {"rondaId": ""},
            {"rondaId": "a/b"},
            {"activity": ""},
            {"activity": 5},
            {"activity": "a\nb"},
            {"activity": "x" * 121},
            {"place": 3},
            {"kind": "party"},
            {"date": "tomorrow"},
            {"time": "7pm"},
            {"date": "2026-13-45"},
        ],
    )
    def test_a_malformed_request_is_invalid(self, db, changes):
        with pytest.raises(sp.SharedPlanError) as excinfo:
            share(db, **changes)

        assert excinfo.value.code == "invalid-argument"

    def test_a_request_that_is_not_a_map_is_invalid(self, db):
        with pytest.raises(sp.SharedPlanError) as excinfo:
            sp.share(uid=MIRTA, data="x", db=db, checker=Spark(), now=NOW)

        assert excinfo.value.code == "invalid-argument"

    def test_only_a_member_who_has_not_left_shares(self, db):
        db.documents[f"rondas/{RONDA}/members/{ANA}"]["state"] = "left"

        for uid in (ANA, "demo-stranger"):
            with pytest.raises(sp.SharedPlanError) as excinfo:
                share(db, uid=uid)
            assert excinfo.value.code == "permission-denied"

    def test_the_terms_come_first(self, db):
        del db.documents[f"users/{MIRTA}"]["terms"]

        with pytest.raises(sp.SharedPlanError) as excinfo:
            share(db)

        assert excinfo.value.code == "failed-precondition"
        assert excinfo.value.reason is None

    def test_a_member_with_no_first_name_cannot_share(self, db):
        del db.documents[f"users/{MIRTA}"]["firstName"]

        with pytest.raises(sp.SharedPlanError) as excinfo:
            share(db)

        assert excinfo.value.code == "failed-precondition"

    def test_a_spark_that_is_down_raises_unavailable(self, db):
        with pytest.raises(voice.ModelUnavailable):
            share(db, checker=Spark(error=voice.ModelUnavailable("down")))


class TestSparkPlan:
    def reply(self, *, allowed=True, reason=sp.PlanReason.OK, error=None, parsed=True):
        verdict = sp.PlanVerdict(allowed=allowed, reason=reason) if parsed else None
        calls = []

        def parse(**kwargs):
            calls.append(kwargs)
            if error:
                raise error
            return SimpleNamespace(
                choices=[SimpleNamespace(message=SimpleNamespace(parsed=verdict))]
            )

        client = SimpleNamespace(chat=SimpleNamespace(completions=SimpleNamespace(parse=parse)))
        return sp.SparkPlan(client), calls

    def test_an_allowed_plan_has_no_reason(self):
        checker, calls = self.reply()

        assert checker.reason("Ir a la feria") == ""
        assert calls[0]["model"] == "muse-spark-1.3"
        assert calls[0]["response_format"] is sp.PlanVerdict
        assert calls[0]["messages"][1] == {"role": "user", "content": "Ir a la feria"}

    @pytest.mark.parametrize(
        ("reason", "held"),
        [
            (sp.PlanReason.NOT_PUBLIC, "place"),
            (sp.PlanReason.ADDRESS, "address"),
            (sp.PlanReason.PHONE, "phone"),
            (sp.PlanReason.MONEY, "money"),
            (sp.PlanReason.OTHER, "other"),
        ],
    )
    def test_each_reason_maps_to_what_the_app_says(self, reason, held):
        checker, _ = self.reply(allowed=False, reason=reason)

        assert checker.reason("x") == held

    def test_allowed_with_a_reason_still_holds_it(self):
        checker, _ = self.reply(allowed=True, reason=sp.PlanReason.ADDRESS)

        assert checker.reason("x") == "address"

    def test_not_allowed_with_ok_is_other(self):
        checker, _ = self.reply(allowed=False, reason=sp.PlanReason.OK)

        assert checker.reason("x") == "other"

    def test_a_failing_model_is_unavailable(self):
        checker, _ = self.reply(error=RuntimeError("boom"))

        with pytest.raises(voice.ModelUnavailable):
            checker.reason("x")

    def test_no_parsed_verdict_is_unavailable(self):
        checker, _ = self.reply(parsed=False)

        with pytest.raises(voice.ModelUnavailable):
            checker.reason("x")


class TestSharing:
    def test_sharing_stores_the_plan_and_gives_the_others_a_line(self, db):
        assert share(db) == {"status": "shared"}

        stored = db.documents[PLAN + MIRTA]
        assert stored["firstName"] == "Mirta"
        assert stored["startsAt"] == at(5, 19)
        assert stored["joined"] == {}
        line = {
            "id": MIRTA,
            "firstName": "Mirta",
            "activity": "Caminar 30 minutos por la rambla",
            "place": "desde la parada 23",
            "kind": "walk",
            "date": "2026-11-05",
            "time": "19:00",
            "joined": False,
        }
        for uid in (JORGE, ANA, FACU):
            assert card(db, uid) == {"plans": [line], "mine": None, "updatedAt": NOW}

    def test_the_author_has_a_card_of_their_own_with_nobody_in_it_yet(self, db):
        share(db)

        assert card(db, MIRTA) == {
            "plans": [],
            "mine": {
                "activity": "Caminar 30 minutos por la rambla",
                "place": "desde la parada 23",
                "kind": "walk",
                "date": "2026-11-05",
                "time": "19:00",
                "joined": [],
            },
            "updatedAt": NOW,
        }

    def test_a_member_who_left_has_no_card_and_never_sees_it(self, db):
        db.documents[f"rondas/{RONDA}/members/{FACU}"]["state"] = "left"
        db.documents[CARD + FACU] = {"plans": [], "mine": None}

        share(db)

        assert card(db, FACU) is None

    def test_sharing_again_replaces_the_plan_and_its_joins(self, db):
        share(db)
        sp.join(db, JORGE, {"rondaId": RONDA, "authorUid": MIRTA}, NOW)

        share(db, time="18:00", now=NOW + timedelta(minutes=5))

        assert db.documents[PLAN + MIRTA]["joined"] == {}
        assert card(db, MIRTA)["mine"]["joined"] == []
        assert card(db, JORGE)["plans"][0]["time"] == "18:00"

    def test_the_cards_list_plans_in_the_order_they_happen(self, db):
        share(db, uid=MIRTA, date="2026-11-06")
        share(db, uid=JORGE, activity="Ir a la feria", place="de Solymar", kind="feria")

        assert [p["firstName"] for p in card(db, ANA)["plans"]] == ["Jorge", "Mirta"]
        assert [p["firstName"] for p in card(db, MIRTA)["plans"]] == ["Jorge"]


class TestJoining:
    def args(self, author=MIRTA):
        return {"rondaId": RONDA, "authorUid": author}

    def test_joining_shows_the_author_the_first_name_and_marks_the_line(self, db):
        share(db)

        assert sp.join(db, JORGE, self.args(), NOW) == {"status": "joined"}
        sp.join(db, ANA, self.args(), NOW + timedelta(minutes=1))

        assert card(db, MIRTA)["mine"]["joined"] == ["Jorge", "Ana"]
        assert card(db, JORGE)["plans"][0]["joined"] is True
        assert card(db, FACU)["plans"][0]["joined"] is False

    def test_nobody_but_the_author_ever_reads_who_joined(self, db):
        share(db)
        sp.join(db, JORGE, self.args(), NOW)

        for uid in (JORGE, ANA, FACU):
            assert "Jorge" not in str(card(db, uid)).replace("'firstName': 'Jorge'", "")
            assert JORGE not in str(card(db, uid))
        assert JORGE not in str(card(db, MIRTA))

    def test_joining_twice_is_one_join(self, db):
        share(db)
        sp.join(db, JORGE, self.args(), NOW)
        sp.join(db, JORGE, self.args(), NOW + timedelta(minutes=5))

        assert list(db.documents[PLAN + MIRTA]["joined"]) == [JORGE]

    def test_one_who_left_the_ronda_is_not_named(self, db):
        share(db)
        sp.join(db, JORGE, self.args(), NOW)
        db.documents[f"rondas/{RONDA}/members/{JORGE}"]["state"] = "left"

        sp.refresh(db, RONDA, NOW)

        assert card(db, MIRTA)["mine"]["joined"] == []
        assert card(db, JORGE) is None

    def test_the_author_cannot_join_their_own_plan(self, db):
        share(db)

        with pytest.raises(sp.SharedPlanError) as excinfo:
            sp.join(db, MIRTA, self.args(), NOW)

        assert excinfo.value.code == "invalid-argument"

    def test_a_plan_that_is_not_there_or_is_over_cannot_be_joined(self, db):
        with pytest.raises(sp.SharedPlanError) as missing:
            sp.join(db, JORGE, self.args(), NOW)
        share(db)
        with pytest.raises(sp.SharedPlanError) as over:
            sp.join(db, JORGE, self.args(), at(5, 19, 1))

        assert missing.value.code == over.value.code == "failed-precondition"

    def test_only_a_member_joins(self, db):
        share(db)

        with pytest.raises(sp.SharedPlanError) as excinfo:
            sp.join(db, "demo-stranger", self.args(), NOW)

        assert excinfo.value.code == "permission-denied"

    @pytest.mark.parametrize("data", [None, {}, {"rondaId": RONDA}, {"authorUid": MIRTA}])
    def test_both_ids_are_needed(self, db, data):
        with pytest.raises(sp.SharedPlanError) as excinfo:
            sp.join(db, JORGE, data, NOW)

        assert excinfo.value.code == "invalid-argument"

    def test_taking_back_me_sumo_drops_the_name_and_says_nothing(self, db):
        share(db)
        sp.join(db, JORGE, self.args(), NOW)
        sp.join(db, ANA, self.args(), NOW + timedelta(minutes=1))

        assert sp.leave(db, JORGE, self.args(), NOW) == {"status": "left"}

        assert card(db, MIRTA)["mine"]["joined"] == ["Ana"]
        assert card(db, JORGE)["plans"][0]["joined"] is False

    def test_leaving_what_was_never_joined_or_is_gone_is_fine(self, db):
        sp.leave(db, JORGE, self.args(), NOW)
        share(db)
        sp.leave(db, JORGE, self.args(), NOW)

        assert db.documents[PLAN + MIRTA]["joined"] == {}

    def test_the_author_withdrawing_takes_every_join_and_card_with_it(self, db):
        share(db)
        sp.join(db, JORGE, self.args(), NOW)

        assert sp.withdraw(db, MIRTA, {"rondaId": RONDA}, NOW) == {"status": "withdrawn"}

        assert PLAN + MIRTA not in db.documents
        assert all(card(db, uid) is None for uid in (MIRTA, JORGE, ANA, FACU))

    def test_withdrawing_what_is_not_shared_is_fine(self, db):
        assert sp.withdraw(db, MIRTA, {"rondaId": RONDA}, NOW) == {"status": "withdrawn"}

    def test_withdrawing_needs_a_ronda(self, db):
        with pytest.raises(sp.SharedPlanError):
            sp.withdraw(db, MIRTA, {}, NOW)


class TestTheJob:
    def test_a_plan_is_deleted_once_its_time_has_passed_and_the_cards_go(self, db):
        share(db)
        sp.join(db, JORGE, {"rondaId": RONDA, "authorUid": MIRTA}, NOW)

        before = sp.run_shared_plans(db, at(5, 18, 59))
        after = sp.run_shared_plans(db, at(5, 19, 0, month=11))

        assert before == {"rondas": 1, "deleted": 0, "cards": 4}
        assert after == {"rondas": 1, "deleted": 1, "cards": 0}
        assert PLAN + MIRTA not in db.documents
        assert all(card(db, uid) is None for uid in (MIRTA, JORGE, ANA, FACU))

    def test_a_plan_whose_author_left_goes_too(self, db):
        share(db)
        db.documents[f"rondas/{RONDA}/members/{MIRTA}"]["state"] = "left"

        counts = sp.run_shared_plans(db, NOW)

        assert counts["deleted"] == 1
        assert card(db, JORGE) is None

    def test_a_ronda_with_nothing_shared_is_left_alone(self, db):
        assert sp.run_shared_plans(db, NOW) == {"rondas": 0, "deleted": 0, "cards": 0}
        assert not [path for path in db.documents if "plan_cards" in path]

    def test_the_job_is_registered_and_sends_nothing(self, db):
        import jobs

        share(db)

        counts = jobs.run("shared_plans", db, NOW, jobs.Context(send=lambda m: 1 / 0))

        assert counts["rondas"] == 1
