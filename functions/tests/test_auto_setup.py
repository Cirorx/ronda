"""auto_setup.py: the organiser agent's place, hour and host for a new ronda, the checks in code
and the fallback, over the Firestore stand-in and a scripted model."""

from datetime import date

import pytest

import auto_setup
from organiser.model import ModelUnavailable
from tests.auto_form_fakes import BIBLIOTECA, MON_10, PEOPLE, PLAZA, RAMBLA, SEAT, sign_ups
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import ScriptedModel, call, turn

RUN = "auto_p1_1"
REASON = "La plaza queda a dos cuadras de los dos; abre m2, que vive más cerca."


def proposal_group() -> dict:
    return {
        "id": SEAT,
        "barrio": "cordon",
        "pretext": "mate",
        "slot": "thu-afternoon",
        "members": [
            {"uid": uid, "firstName": name, "ageBand": band, "distanceBlocks": 0}
            for uid, (name, band) in PEOPLE.items()
        ],
        "checks": [],
    }


def group(db: FakeFirestore) -> auto_setup.Group:
    users = {
        path[6:]: d
        for path, d in db.documents.items()
        if path.count("/") == 1 and path.startswith("users/")
    }
    return auto_setup.group_of(db, proposal_group(), users, MON_10)


def propose(place_id: str = PLAZA, hour: str = "16:30", host: str = "m2", reason: str = REASON):
    return turn(call("propose_setup", place_id=place_id, hour=hour, host=host, reason=reason))


def run(db: FakeFirestore, script: list) -> tuple[dict | None, ScriptedModel]:
    model = ScriptedModel(script)
    return auto_setup.set_up(db, RUN, group(db), MON_10, lambda: model), model


def steps(db: FakeFirestore) -> list[dict]:
    prefix = f"agent_runs/{RUN}/steps/"
    return [d for p, d in sorted(db.documents.items()) if p.startswith(prefix)]


class TestGroup:
    def test_offers_the_nearest_places_with_each_members_walk(self):
        g = group(FakeFirestore(sign_ups()))

        assert [p.id for p in g.places] == [BIBLIOTECA, PLAZA, RAMBLA]
        assert g.day == date(2026, 11, 5)
        assert g.band == "afternoon"
        assert g.labels == {"m1": "demo-af-1", "m2": "demo-af-2"}
        assert g.walks[RAMBLA] == {"demo-af-1": 5, "demo-af-2": 5}  # about 480 m

    def test_a_member_in_an_unknown_barrio_walks_from_the_seats_barrio(self):
        db = FakeFirestore(sign_ups())
        db.documents["users/demo-af-1"]["barrio"] = "atlantis"

        assert group(db).walks[PLAZA]["demo-af-1"] == 1

    def test_leaves_out_a_name_too_long_for_the_ronda(self):
        db = FakeFirestore(sign_ups())
        db.documents[f"osm_places/{PLAZA}"]["name"] = "la Plaza " + "x" * 60

        assert PLAZA not in [p.id for p in group(db).places]

    def test_an_unknown_band_reads_as_the_afternoon(self):
        data = proposal_group() | {"slot": "thu-siesta"}

        assert auto_setup.group_of(FakeFirestore(sign_ups()), data, {}, MON_10).band == "afternoon"


class TestTheAgent:
    def test_its_setup_is_kept_once_code_accepts_every_field(self):
        db = FakeFirestore(sign_ups())

        setup, _ = run(db, [propose(), turn(content="Listo.")])

        assert setup == {
            "placeId": PLAZA,
            "place": {"name": "la Plaza Inventada"},
            "hour": "16:30",
            "anfitrion": "demo-af-2",
            "cola": "demo-af-1",
            "anfitrionName": "Beto",
            "colaName": "Ana",
            "reason": "La plaza queda a dos cuadras de los dos; abre Beto, que vive más cerca.",
            "by": "agent",
            "runId": RUN,
        }

    def test_never_learns_a_name(self):
        db = FakeFirestore(sign_ups())

        _, model = run(db, [propose(), turn(content="Listo.")])

        words = str(model.requests)
        assert "Ana" not in words and "Beto" not in words and "demo-af" not in words
        assert "m1" in words and "la Plaza Inventada" in words

    def test_the_trace_names_the_job_the_call_and_what_was_kept(self):
        db = FakeFirestore(sign_ups())

        run(db, [propose(), turn(content="Listo.")])

        trace = db.documents[f"agent_runs/{RUN}"]
        assert (trace["job"], trace["status"], trace["rondaId"]) == ("auto_setup", "done", "")
        assert trace["note"].startswith("La plaza queda")
        kinds = [s["kind"] for s in steps(db)]
        assert kinds == ["model", "tool", "model", "note"]
        assert steps(db)[1]["status"] == "ok"
        assert steps(db)[3]["note"].startswith("Aceptado: la Plaza Inventada a las 16:30")

    @pytest.mark.parametrize(
        ("call_args", "why"),
        [
            ({"place_id": "lo-de-ana"}, "no es un lugar de la lista"),
            ({"hour": "18:00"}, "fuera de la franja: elegí entre las 14:00 y las 17:00"),
            ({"place_id": BIBLIOTECA}, "está cerrado a las 16:30"),
            ({"host": "m7"}, "no es del grupo"),
            ({"reason": "Nos vemos con el termo 🧉"}, "tiene un emoji"),
        ],
    )
    def test_code_refuses_a_field_that_does_not_hold_and_takes_the_retry(self, call_args, why):
        db = FakeFirestore(sign_ups())

        setup, model = run(db, [propose(**call_args), propose(), turn(content="Listo.")])

        assert setup["by"] == "agent" and setup["placeId"] == PLAZA
        refused = steps(db)[1]
        assert refused["status"] == "refused" and why in refused["resultSummary"]
        assert why in model.requests[1][0][-1]["content"]

    def test_a_second_call_is_refused(self):
        db = FakeFirestore(sign_ups())

        setup, _ = run(db, [propose(), propose(place_id=RAMBLA), turn(content="Listo.")])

        assert setup["placeId"] == PLAZA
        assert steps(db)[3]["status"] == "refused"

    def test_writes_no_acta_line_since_there_is_no_ronda_yet(self):
        db = FakeFirestore(sign_ups())

        run(db, [propose(), turn(content="Listo.")])

        assert not [p for p in db.documents if p.startswith("acta/")]


CODE_SETUP = {
    "placeId": PLAZA,
    "place": {"name": "la Plaza Inventada"},
    "hour": "16:00",
    "anfitrion": "demo-af-1",
    "cola": "demo-af-2",
    "anfitrionName": "Ana",
    "colaName": "Beto",
    "reason": auto_setup.FALLBACK_REASON,
    "by": "code",
    "runId": RUN,
}


class TestTheFallback:
    def test_without_a_model_code_picks_the_nearest_open_place_the_usual_hour_and_the_rotation(
        self,
    ):
        db = FakeFirestore(sign_ups())

        def no_model():
            raise ModelUnavailable("model keys missing")

        setup = auto_setup.set_up(db, RUN, group(db), MON_10, no_model)

        assert setup == CODE_SETUP
        assert db.documents[f"agent_runs/{RUN}"]["status"] == "failed"
        assert steps(db)[-1]["note"].startswith("Regla fija (no quedó una propuesta")

    def test_when_the_model_fails_mid_run(self):
        db = FakeFirestore(sign_ups())

        setup, _ = run(db, [ModelUnavailable("down")])

        assert setup == CODE_SETUP

    def test_when_every_answer_is_refused(self):
        db = FakeFirestore(sign_ups())

        setup, _ = run(db, [propose(host="m9"), propose(host="m9"), turn(content="No pude.")])

        assert setup == CODE_SETUP

    def test_when_the_run_breaks(self):
        db = FakeFirestore(sign_ups())

        setup, _ = run(db, [RuntimeError("boom")])

        assert setup == CODE_SETUP
        assert db.documents[f"agent_runs/{RUN}"]["status"] == "failed"

    def test_with_no_place_near_the_group_there_is_no_setup_and_no_model_call(self):
        db = FakeFirestore(sign_ups(places=False))

        setup, model = run(db, [])

        assert setup is None and model.requests == []
        assert "no hay lugares cerca" in steps(db)[-1]["note"]
        assert "Espera al admin" in steps(db)[-1]["note"]

    def test_with_only_places_closed_at_the_usual_hour_there_is_no_setup(self):
        db = FakeFirestore(sign_ups())
        for place in (PLAZA, RAMBLA):
            del db.documents[f"osm_places/{place}"]

        setup, _ = run(db, [ModelUnavailable("down")])

        assert setup is None


@pytest.mark.parametrize(
    ("setup", "complete"),
    [
        (CODE_SETUP, True),
        (None, False),
        ({**CODE_SETUP, "hour": ""}, False),
        ({**CODE_SETUP, "place": {}}, False),
    ],
)
def test_complete(setup, complete):
    assert auto_setup.complete(setup) is complete
