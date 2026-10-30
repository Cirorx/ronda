"""rain.py: the rain check and the host's pick, over the Firestore stand-in, a scripted model and
a fake forecast. The first four tests are #49's "Done when"."""

from datetime import date, timedelta

import pytest

import rain
from organiser import moves
from organiser.model import ModelUnavailable
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import (
    DRY,
    HOST,
    RONDA,
    WED_18,
    WED_21,
    WED_22,
    WED_2030,
    WEEK,
    FakeWeather,
    ScriptedModel,
    at,
    call,
    documents,
    rain_script,
    turn,
)
from tests.test_rsvp import Sender

APP = "https://example.test/app/ronda"
RUN = f"{RONDA}_{WEEK}_rain"


def check(db, now=WED_18, *, script=None, sender=None, weather=None, force=False, model=None):
    return rain.run_rain_check(
        db,
        now,
        send=sender or Sender(),
        app_url=APP,
        force=force,
        model=model or ScriptedModel(rain_script() if script is None else script),
        weather=weather or FakeWeather(),
    )


def steps(db, run_id=RUN) -> list[dict]:
    prefix = f"agent_runs/{run_id}/steps/"
    return [db.documents[p] for p in sorted(db.documents) if p.startswith(prefix)]


def acta(db) -> list[dict]:
    prefix = f"acta/{RONDA}/entries/"
    return [db.documents[p] for p in sorted(db.documents) if p.startswith(prefix)]


def move(db) -> dict:
    return db.documents[f"rondas/{RONDA}/moves/{WEEK}"]


def pick(db, choice="covered", uid=HOST, now=WED_2030, sender=None):
    return rain.answer_move(db, uid, RONDA, WEEK, choice, now, send=sender or Sender(), app_url=APP)


class TestDoneWhen:
    def test_a_rainy_forecast_produces_a_host_proposal(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))
        sender = Sender()

        counts = check(db, sender=sender)

        assert counts == {"rondas": 1, "checked": 1, "already": 0, "failed": 0, "expired": 0}
        assert [m["token"] for m in sender.messages] == [f"tok-{HOST}"]
        message = sender.messages[0]
        assert message["data"]["type"] == "move"
        assert message["data"]["title"] == "El jueves puede llover"
        assert message["data"]["body"].endswith(
            "Jueves 16:00 · lluvia 80%. Ráfagas de 50 km/h. Pronóstico de Open-Meteo."
        )
        assert "Soy un programa" in message["data"]["body"]
        proposal = move(db)
        assert proposal["status"] == "pending"
        assert proposal["hostUid"] == HOST
        assert proposal["hostFallback"] is False
        assert [o["label"] for o in proposal["options"]] == [
            "Al Salón Comunal de El Pinar",
            "Pasarla al viernes",
            "Vamos igual",
        ]
        assert proposal["options"][0]["message"] == (
            "Por la lluvia, el jueves nos vemos en el Salón Comunal de El Pinar a las 16:00. "
            "Lo decidió Mirta."
        )
        assert proposal["recipients"] == 3
        assert proposal["title"] == "El jueves puede llover"
        assert proposal["body"] == (
            "Jueves 16:00 · lluvia 80%. Ráfagas de 50 km/h. Pronóstico de Open-Meteo."
        )
        assert db.documents[f"agent_runs/{RUN}"]["status"] == "done"
        assert (
            db.documents[f"agent_runs/{RUN}"]["note"] == "Listo: le propuse opciones al anfitrión."
        )

    def test_the_hosts_pick_produces_exactly_one_member_push(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))
        check(db)
        sender = Sender()

        result = pick(db, sender=sender)
        again = pick(db, sender=sender)

        assert result == {
            "status": "decided",
            "choice": "covered",
            "sent": 3,
            "held": 0,
            "unreachable": 0,
        }
        members = [s for s in steps(db) if s["kind"] == "message" and s["toRole"] == "member"]
        assert sorted(s["toName"] for s in members) == ["Ana", "Facu", "Jorge"]
        # Jorge has an Android phone and a browser: his one message reaches both.
        assert sorted(m["token"] for m in sender.messages) == [
            "tok-demo-102",
            "tok-demo-103",
            "tok-demo-104",
            "tok-web",
        ]
        texts = {m.get("data", m.get("notification"))["body"] for m in sender.messages}
        assert all(t.endswith(move(db)["options"][0]["message"]) for t in texts)
        assert again["status"] == "already"
        assert len(sender.messages) == 4
        assert move(db)["status"] == "decided"
        week = db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]
        assert week["placeOverride"] == {
            "placeId": "salon-pinar",
            "name": "el Salón Comunal de El Pinar",
        }

    def test_the_acta_shows_every_step(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))
        check(db)
        pick(db)

        trace = steps(db)
        lines = acta(db)
        tool_steps = [s for s in trace if s["kind"] in ("tool", "host")]
        assert [s["tool"] for s in tool_steps if s["kind"] == "tool"] == [
            "get_forecast",
            "get_sunset",
            "get_last_bus",
            "count_rsvps",
            "propose_move",
            "log_acta",
        ]
        assert [line["tool"] for line in lines] == [
            "get_forecast",
            "get_sunset",
            "get_last_bus",
            "count_rsvps",
            "propose_move",
            "log_acta",
            "host_choice",
            "send_member_push",
        ]
        summaries = [line["summary"] for line in lines]
        assert summaries[0] == (
            "Miró el pronóstico del jueves 5/11 a las 16:00: lluvia 80%, ráfagas de 50 km/h "
            "(Open-Meteo)."
        )
        assert summaries[4] == (
            "Le propuso a Mirta, que abre, qué hacer por la lluvia: al Salón Comunal de El "
            "Pinar, pasarla al viernes, vamos igual."
        )
        assert summaries[6] == "Mirta eligió: al Salón Comunal de El Pinar."
        assert summaries[7].startswith("Les avisó a 3 en un solo mensaje: «Por la lluvia")
        assert [line["decidedBy"] for line in lines][-2:] == ["host", "host"]
        messages = [s for s in trace if s["kind"] == "message"]
        assert [(m["toRole"], m["outcome"]) for m in messages] == [
            ("host", "sent"),
            ("member", "sent"),
            ("member", "sent"),
            ("member", "sent"),
        ]
        assert all(m["gate"] == "allowed" for m in messages)

    def test_a_22_00_message_is_blocked(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))
        sender = Sender()

        counts = check(db, WED_22, sender=sender, force=True)

        assert counts["checked"] == 1
        assert sender.messages == []
        assert f"rondas/{RONDA}/moves/{WEEK}" not in db.documents
        run = f"{RUN}_20261104T2200"
        [held] = [s for s in steps(db, run) if s["kind"] == "message"]
        assert held["gate"] == "blocked"
        assert held["gateName"] == "quiet_hours"
        assert held["gateReason"] == "fuera de horario"
        assert held["outcome"] == "held"
        assert held["releaseAt"] == at(5, 9)
        assert held["ts"] >= WED_22
        assert "Frenó la propuesta a Mirta: fuera de horario." in [
            line["summary"] for line in acta(db)
        ]
        assert db.documents[f"agent_runs/{run}"]["forced"] is True


class TestTheJob:
    def test_runs_only_the_evening_before_from_18_to_21(self):
        for now in (at(4, 17), WED_21, at(3, 18), at(5, 18)):
            db = FakeFirestore(documents())
            assert check(db, now)["checked"] == 0, now
            assert not [p for p in db.documents if p.startswith("agent_runs/")]

    def test_runs_once_a_week_per_ronda(self):
        db = FakeFirestore(documents())
        check(db)

        counts = check(db, at(4, 19), script=[])

        assert counts["already"] == 1
        assert counts["checked"] == 0

    def test_a_failed_run_is_tried_again_the_next_hour(self):
        db = FakeFirestore(documents())
        broken = ScriptedModel([RuntimeError("boom")])

        assert check(db, model=broken)["failed"] == 1
        assert db.documents[f"agent_runs/{RUN}"]["status"] == "failed"
        assert steps(db)[-1]["why"] == "falló (RuntimeError)"

        assert check(db, at(4, 19))["checked"] == 1
        assert db.documents[f"agent_runs/{RUN}"]["status"] == "done"
        assert f"rondas/{RONDA}/moves/{WEEK}" in db.documents

    def test_the_model_being_down_fails_the_run(self):
        db = FakeFirestore(documents())

        counts = check(db, model=ScriptedModel([ModelUnavailable("APIConnectionError")]))

        assert counts["failed"] == 1
        assert steps(db)[-1]["why"] == "el modelo no respondió (APIConnectionError)"

    def test_without_model_keys_it_fails_without_calling_anything(self, monkeypatch):
        monkeypatch.delenv("BASETEN_API_KEY", raising=False)
        db = FakeFirestore(documents())

        counts = rain.run_rain_check(db, WED_18, send=Sender(), app_url=APP, weather=FakeWeather())

        assert counts["failed"] == 1
        assert steps(db)[-1]["why"] == "no hay modelo (model keys missing)"

    def test_skips_rondas_that_dont_meet(self):
        db = FakeFirestore(documents(status="paused"))

        assert check(db)["rondas"] == 0

    def test_a_dry_forecast_proposes_nothing(self):
        db = FakeFirestore(documents())
        script = [
            turn(call("get_forecast", date="2026-11-05", reason="ver si llueve")),
            turn(content="No llueve, no hace falta nada."),
        ]

        check(db, script=script, weather=FakeWeather(DRY))

        assert f"rondas/{RONDA}/moves/{WEEK}" not in db.documents
        assert acta(db)[0]["summary"].startswith("Miró el pronóstico del jueves 5/11")

    def test_a_host_who_left_is_replaced_by_the_first_active_member(self):
        db = FakeFirestore(documents(hosts={"anfitrion": "demo-999"}))

        check(db)

        assert move(db)["hostUid"] == HOST
        note = next(s for s in steps(db) if s["kind"] == "note")
        assert note["note"].startswith(
            "Ni el anfitrión ni la cola están activos en la ronda: la propuesta"
        )

    def test_the_cola_is_asked_when_the_anfitrion_cant(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST, "cola": "demo-103"}))
        db.documents[f"rondas/{RONDA}/members/{HOST}"]["state"] = "paused"

        check(db)

        assert move(db)["hostUid"] == "demo-103"
        assert move(db)["hostFallback"] is False
        note = next(s for s in steps(db) if s["kind"] == "note")
        assert note["note"] == "El anfitrión no está activo: la propuesta iría a Ana, que cierra."

    def test_without_hosts_the_first_active_member_stands_in_and_it_says_so(self):
        db = FakeFirestore(documents())
        db.documents[f"rondas/{RONDA}/members/demo-101"]["state"] = "paused"

        check(db)

        assert move(db)["hostUid"] == "demo-102"
        assert move(db)["hostFallback"] is True
        note = next(s for s in steps(db) if s["kind"] == "note")
        assert note["note"] == (
            "No hay anfitrión asignado: la propuesta iría a Jorge, el primer miembro activo."
        )
        assert acta(db)[4]["summary"].startswith("Le propuso a Jorge, qué hacer")

    def test_a_ronda_without_active_members_stops(self):
        db = FakeFirestore(documents())
        for uid in ("demo-101", "demo-102", "demo-103", "demo-104"):
            db.documents[f"rondas/{RONDA}/members/{uid}"]["state"] = "left"

        check(db, script=[])

        assert db.documents[f"agent_runs/{RUN}"]["status"] == "stopped"
        assert steps(db)[-1]["why"] == "la ronda no tiene miembros activos"

    def test_reads_the_forecast_at_the_place_then_the_barrio_then_the_coast(self):
        for fields, where in (
            ({}, (-34.80, -55.885)),
            ({"place": {"name": "x"}}, (-34.8000, -55.8850)),
            ({"place": None, "barrio": "nowhere"}, rain.CIUDAD_DE_LA_COSTA),
        ):
            weather = FakeWeather()
            check(FakeFirestore(documents(**fields)), weather=weather)
            assert weather.calls[0][:2] == where

    def test_tells_the_model_the_meeting_and_the_covered_places_but_no_names(self):
        db = FakeFirestore(documents())
        model = ScriptedModel(rain_script())

        check(db, model=model)

        task = model.requests[0][0][1]["content"]
        assert task == (
            "Ronda: mate en la rambla.\n"
            "Reunión: jueves 2026-11-05 a las 16:00, en frente al quiosco.\n"
            "Ahora: miércoles 2026-11-04 18:00.\n"
            "Lugares techados públicos cerca (id: nombre):\n"
            "- salon-pinar: el Salón Comunal de El Pinar"
        )
        for name in ("Mirta", "Jorge", "Ana", "Facu"):
            assert name not in str(model.requests)

    def test_with_no_covered_place_the_task_says_so(self):
        db = FakeFirestore(documents(barrio="lagomar-sur"))
        model = ScriptedModel(rain_script(place_id=""))

        check(db, model=model)

        assert model.requests[0][0][1]["content"].endswith("(id: nombre):\n- ninguno")
        assert [o["id"] for o in move(db)["options"]] == ["postpone", "asIs"]

    def test_without_an_hour_it_reads_the_whole_band_and_invents_none(self):
        db = FakeFirestore(documents(slot={"day": "thu", "time": "evening"}))
        model = ScriptedModel(rain_script())

        check(db, model=model)

        proposal = move(db)
        assert proposal["hour"] is None
        assert proposal["body"].startswith("Jueves a la noche · lluvia 75%.")
        assert [o["message"] for o in proposal["options"]][-1] == (
            "Puede llover, pero el jueves vamos igual, a la noche como siempre. Lo decidió Mirta."
        )
        assert (
            "Reunión: jueves 2026-11-05 a la noche, en frente al quiosco."
            in (model.requests[0][0][1]["content"])
        )

    def test_a_set_hour_is_the_one_every_message_says(self):
        db = FakeFirestore(documents(slot={"day": "thu", "time": "afternoon", "hour": "16:30"}))

        check(db)

        proposal = move(db)
        assert proposal["hour"] == "16:30"
        assert proposal["body"].startswith("Jueves 16:30 · lluvia 80%.")
        assert "a las 16:30" in proposal["options"][0]["message"]


class TestExpiry:
    def test_an_unanswered_proposal_stays_as_it_is_at_21(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))
        check(db)
        sender = Sender()

        counts = check(db, WED_21, sender=sender, script=[])

        assert counts["expired"] == 1
        assert move(db)["status"] == "expired"
        assert sender.messages == []
        assert acta(db)[-1]["summary"] == "Mirta no eligió antes de las 21: queda como está."
        assert steps(db)[-1]["kind"] == "host"
        assert check(db, at(4, 22), script=[])["expired"] == 0

    def test_a_pending_proposal_before_21_stays_pending(self):
        db = FakeFirestore(documents())
        check(db)

        assert check(db, at(4, 20), script=[])["expired"] == 0
        assert move(db)["status"] == "pending"

    def test_a_late_pick_is_refused(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))
        check(db)

        with pytest.raises(rain.MoveError) as late:
            pick(db, now=WED_21)
        assert late.value.code == "failed-precondition"

        check(db, WED_21, script=[])
        with pytest.raises(rain.MoveError) as expired:
            pick(db, now=WED_2030)
        assert expired.value.code == "failed-precondition"

    def test_an_expired_proposal_without_a_host_name_says_the_host(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))
        check(db)
        db.documents[f"rondas/{RONDA}/moves/{WEEK}"]["hostName"] = ""

        check(db, WED_21, script=[])

        assert acta(db)[-1]["summary"].startswith("El anfitrión no eligió")


class TestAnswerMove:
    @pytest.fixture
    def db(self) -> FakeFirestore:
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))
        check(db)
        return db

    def test_refuses_anyone_but_the_host(self, db):
        with pytest.raises(rain.MoveError) as error:
            pick(db, uid="demo-102")
        assert error.value.code == "permission-denied"

    def test_refuses_a_week_without_a_proposal(self, db):
        with pytest.raises(rain.MoveError) as error:
            rain.answer_move(db, HOST, RONDA, "2026-W46", "asIs", WED_2030, send=Sender())
        assert error.value.code == "not-found"

    def test_refuses_a_choice_that_isnt_offered(self, db):
        with pytest.raises(rain.MoveError) as error:
            pick(db, choice="home")
        assert error.value.code == "invalid-argument"

    def test_postponing_moves_the_date_and_tells_the_members(self, db):
        sender = Sender()

        result = pick(db, choice="postpone", sender=sender)

        assert result["sent"] == 3
        week = db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]
        assert week["dateOverride"] == "2026-11-06"
        assert sender.messages[0]["data"]["body"].endswith(
            "Por la lluvia, la ronda del jueves pasa al viernes a las 16:00, en el mismo lugar. "
            "Lo decidió Mirta."
        )

    def test_going_anyway_changes_nothing_but_still_tells_the_members(self, db):
        sender = Sender()

        pick(db, choice="asIs", sender=sender)

        week = db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]
        assert "placeOverride" not in week and "dateOverride" not in week
        assert (
            sender.messages[0]["data"]["title"]
            == "Jueves 16:00 · mate en la rambla · frente al quiosco"
        )

    def test_going_anyway_without_a_place_names_none(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}, place=None))
        check(db)

        assert pick(db, choice="asIs")["sent"] == 3

    def test_the_first_message_introduces_the_program_and_the_second_doesnt(self, db):
        sender = Sender()
        db.documents["users/demo-103/private/agent"] = {"introducedAt": WED_18}

        pick(db, sender=sender)

        bodies = {m["token"]: m.get("data", {}).get("body", "") for m in sender.messages}
        assert bodies["tok-demo-104"].startswith("Hola, Facu. Soy un programa.")
        assert bodies["tok-demo-103"].startswith("Por la lluvia")
        assert db.documents["users/demo-104/private/agent"]["introducedAt"] == WED_2030

    def test_paused_members_get_nothing(self, db):
        db.documents[f"rondas/{RONDA}/members/demo-104"].update(
            {"state": "paused", "pausedUntil": "2026-11-19"}
        )
        sender = Sender()

        assert pick(db, sender=sender)["sent"] == 2

    def test_a_held_message_is_counted_and_logged(self, db):
        db.documents[f"rondas/{RONDA}/moves/{WEEK}"]["options"][0]["message"] = "Nos vemos 🧉"

        result = pick(db)

        assert result["held"] == 3
        assert acta(db)[-1]["summary"] == "Frenó el mensaje para 3: tiene un emoji (🧉)."

    def test_a_failed_send_puts_the_proposal_back(self, db):
        with pytest.raises(ConnectionError):
            pick(db, sender=Sender(error=ConnectionError("fcm")))

        assert move(db)["status"] == "pending"
        assert "choice" not in move(db)

    def test_a_pick_racing_another_answers_what_won(self, db, monkeypatch):
        real = rain.rsvp._in_transaction

        def racing(db_, function):
            db.documents[f"rondas/{RONDA}/moves/{WEEK}"].update(
                {"status": "decided", "choice": "asIs", "sent": 3}
            )
            return real(db_, function)

        monkeypatch.setattr(rain.rsvp, "_in_transaction", racing)

        assert pick(db) == {"status": "already", "choice": "asIs", "sent": 3, "held": 0}


def test_the_deadline_is_21_the_evening_before():
    assert moves.deadline(date(2026, 11, 5)) == WED_21
    assert moves.deadline(date(2026, 11, 5) + timedelta(days=2)) == at(6, 21)


def test_an_option_goes_to_a_place_with_its_article():
    assert moves.towards("el Club Solymar") == "Al Club Solymar"
    assert moves.towards("la Biblioteca de Lagomar") == "A la Biblioteca de Lagomar"
