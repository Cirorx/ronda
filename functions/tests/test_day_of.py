"""day_of.py and the organiser's `get_next_buses`: the day-of reminder with the next city buses
(#65), over the Firestore stand-in, a scripted model and the Intendencia's API played back from a
recorded answer (tests/test_mvd_buses.py). The first tests are #65's "Done when".

The invented ronda meets on Thursday 2026-11-05 at 16:00 at Plaza Gomensoro in Pocitos; the
reminder's run is the dispatcher's at 15:00. Mirta and Jorge said "voy", Ana "esta no", Facu
didn't answer."""

from dataclasses import replace
from datetime import timedelta

import pytest

import day_of
import jobs
import mvd_buses
from organiser import gates
from organiser.model import ModelUnavailable
from organiser.tools import Args, Meeting, Toolbox, get_next_buses
from organiser.trace import Trace
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import (
    RONDA,
    THURSDAY,
    WEEK,
    ScriptedModel,
    at,
    call,
    documents,
    turn,
)
from tests.test_mvd_buses import PLAZA, Api
from tests.test_rsvp import Sender

APP = "https://example.test/app/ronda"
THU_15 = at(5, 15)
RUN = f"{RONDA}_{WEEK}_dayof"
PLACE = {"name": "la Plaza Gomensoro", "landmark": "", "lat": PLAZA[0], "lng": PLAZA[1]}
PLAIN = "Hoy nos vemos a las 16:00 en la Plaza Gomensoro."
STOP = mvd_buses.BusStop(4078, "26 de Marzo y Jose Ellauri", -34.91275, -56.15312)
FOUND = mvd_buses.NextBuses(
    STOP, 30, [mvd_buses.Arrival("191", "Punta Carretas", 6), mvd_buses.Arrival("192", "", 15)]
)


def on(**fields) -> dict[str, dict]:
    """The Pocitos ronda with no `dayOfReminder` field: on, by default."""
    return documents(**{"barrio": "pocitos", "place": PLACE, **fields})


def reminder(include_buses: bool = True) -> list:
    return [
        turn(call("get_next_buses", reason="ver qué ómnibus pasan cerca")),
        turn(call("send_reminder", include_buses=include_buses, reason="avisar a los que van")),
        turn(call("log_acta", summary="Mandó el recordatorio de hoy.", reason="anotar")),
        turn(content="**Listo**: salió el recordatorio."),
    ]


class FakeBuses:
    """`CityBuses` that answers `found`, or raises when `found` is an exception."""

    def __init__(self, found=FOUND) -> None:
        self.found = found
        self.asked: list[tuple[float, float]] = []

    def next_buses(self, lat: float, lng: float):
        self.asked.append((lat, lng))
        if isinstance(self.found, Exception):
            raise self.found
        return self.found


def run(db, now=THU_15, *, script=None, model=None, buses=None, sender=None, force=False):
    return day_of.run_day_of(
        db,
        now,
        send=sender if sender is not None else Sender(),
        app_url=APP,
        force=force,
        model=model or ScriptedModel(reminder() if script is None else script),
        buses=buses or FakeBuses(),
    )


def bodies(sender: Sender) -> dict[str, str]:
    """Each Android phone's message body, by token."""
    return {m["token"]: m["data"]["body"] for m in sender.messages if "data" in m}


def steps(db, run_id=RUN) -> list[dict]:
    prefix = f"agent_runs/{run_id}/steps/"
    return [db.documents[p] for p in sorted(db.documents) if p.startswith(prefix)]


def notes(db) -> list[str]:
    return [s["note"] for s in steps(db) if s["kind"] == "note"]


COUNTS = dict.fromkeys(day_of.COUNTS, 0)


class TestDoneWhen:
    def test_the_agent_calls_get_next_buses_and_the_reminder_names_a_line_and_minutes(self):
        db = FakeFirestore(on())
        sender = Sender()
        model = ScriptedModel(reminder())

        counts = run(db, sender=sender, model=model, buses=Api().buses())

        assert counts == {**COUNTS, "rondas": 1, "sent": 1}
        jorge = bodies(sender)["tok-demo-102"]
        assert jorge.endswith(
            f"{PLAIN} Próximos ómnibus en 26 de Marzo y Jose Ellauri, según la Intendencia: "
            "el 192 en 15 minutos."
        )
        assert jorge.startswith("Hola, Jorge. Soy un programa.")
        assert [s.get("tool") for s in steps(db) if s["kind"] == "tool"] == [
            "get_next_buses",
            "send_reminder",
            "log_acta",
        ]
        bus_step = next(s for s in steps(db) if s.get("tool") == "get_next_buses")
        assert bus_step["resultSummary"] == (
            "Miró los próximos ómnibus en 26 de Marzo y Jose Ellauri: el 192 en 15 min "
            "(Intendencia de Montevideo)."
        )
        assert "get_next_buses" in [t["function"]["name"] for t in model.requests[0][1]]

    def test_an_api_failure_leaves_the_reminder_unchanged(self):
        db = FakeFirestore(on())
        sender = Sender()
        api = Api()
        api.fail["/upcomingbuses"] = mvd_buses.httpx.Response(503)

        run(db, sender=sender, script=reminder(include_buses=True), buses=api.buses())

        assert set(bodies(sender).values()) == {
            f"{gates.introduction('Mirta')} {PLAIN}",
            f"{gates.introduction('Jorge')} {PLAIN}",
        }
        bus_step = next(s for s in steps(db) if s.get("tool") == "get_next_buses")
        assert bus_step["status"] == "refused"
        assert bus_step["resultSummary"] == (
            "La Intendencia no contestó a tiempo los próximos ómnibus."
        )

    def test_a_timeout_leaves_the_reminder_unchanged(self):
        db = FakeFirestore(on())
        sender = Sender()
        api = Api()
        api.stall = mvd_buses.BUDGET

        run(db, sender=sender, script=reminder(include_buses=False), buses=api.buses())

        assert bodies(sender)["tok-demo-101"] == f"{gates.introduction('Mirta')} {PLAIN}"


class TestWho:
    def test_only_the_members_who_said_voy_and_arent_paused(self):
        docs = on()
        docs[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"]["demo-104"] = "yes"
        docs[f"rondas/{RONDA}/members/demo-104"].update(state="paused", pausedUntil="2026-11-20")
        db = FakeFirestore(docs)
        sender = Sender()

        run(db, sender=sender)

        assert sender.tokens == ["tok-demo-101", "tok-demo-102", "tok-web"]
        send = next(s for s in steps(db) if s.get("tool") == "send_reminder")
        assert send["resultSummary"] == (
            "Les recordó la reunión de hoy a 2 con los próximos ómnibus."
        )

    def test_the_push_is_the_organisers_and_opens_the_app(self):
        db = FakeFirestore(on())
        sender = Sender()

        run(db, sender=sender)

        android = next(m for m in sender.messages if m["token"] == "tok-demo-101")
        assert android["data"]["type"] == "agent"
        assert android["data"]["rondaId"] == RONDA
        web = next(m for m in sender.messages if m["token"] == "tok-web")
        assert web["webpush"]["fcm_options"]["link"] == APP

    def test_is_not_the_weeks_routine_message(self):
        docs = on()
        docs["users/demo-101/private/agent"] = {
            "introducedAt": at(1, 10),
            "routine": {WEEK: at(3, 19)},
        }
        db = FakeFirestore(docs)
        sender = Sender()

        run(db, sender=sender)

        assert bodies(sender)["tok-demo-101"] == (
            f"{PLAIN} Próximos ómnibus en 26 de Marzo y Jose Ellauri, según la Intendencia: "
            "el 191 en 6 minutos, el 192 en 15."
        )
        assert "routine" not in str(db.documents["users/demo-102/private/agent"])


class TestWhen:
    @pytest.mark.parametrize(
        "now",
        [at(5, 14), at(5, 16), at(5, 17), at(4, 15), at(6, 15)],
        ids=["two-hours-before", "at-the-start", "after", "the-day-before", "the-day-after"],
    )
    def test_only_within_the_hour_before_the_meeting(self, now):
        db = FakeFirestore(on())
        model = ScriptedModel([])

        counts = run(db, now, model=model)

        assert counts == {**COUNTS, "rondas": 1}
        assert model.requests == []

    def test_half_an_hour_before_is_within_the_hour(self):
        db = FakeFirestore(on(slot={"day": "thu", "time": "afternoon", "hour": "15:30"}))

        assert run(db, at(5, 15))["sent"] == 1

    def test_a_meeting_without_an_hour_gets_none(self):
        db = FakeFirestore(on(slot={"day": "thu", "time": "afternoon"}))

        assert run(db, model=ScriptedModel([])) == {**COUNTS, "rondas": 1}

    def test_on_by_default_without_the_field(self):
        db = FakeFirestore(on())

        assert "dayOfReminder" not in db.documents[f"rondas/{RONDA}"]
        assert run(db)["sent"] == 1

    def test_the_switch_set_true_is_on(self):
        db = FakeFirestore(on(dayOfReminder=True))

        assert run(db)["sent"] == 1

    @pytest.mark.parametrize("value", [None, 0, "false"], ids=["null", "zero", "a-string"])
    def test_only_false_itself_turns_it_off(self, value):
        db = FakeFirestore(on(dayOfReminder=value))

        assert run(db)["sent"] == 1

    def test_the_switch_set_false_sends_nothing(self):
        db = FakeFirestore(on(dayOfReminder=False))
        sender = Sender()

        counts = run(db, sender=sender, model=ScriptedModel([]))

        assert counts == {**COUNTS, "rondas": 1, "off": 1}
        assert sender.messages == []

    def test_a_ronda_that_no_longer_meets_is_skipped(self):
        db = FakeFirestore(on(status="ended"))

        assert run(db, model=ScriptedModel([])) == COUNTS

    def test_once_a_meeting_and_again_only_when_forced(self):
        db = FakeFirestore(on())
        run(db)

        again = run(db, THU_15 + timedelta(minutes=30), model=ScriptedModel([]))
        forced = run(db, at(5, 12), force=True)

        assert again == {**COUNTS, "rondas": 1, "already": 1}
        assert forced["sent"] == 1
        assert f"agent_runs/{RUN}_20261105T1200" in db.documents

    def test_holds_at_night_even_when_forced(self):
        db = FakeFirestore(on())

        counts = run(db, at(5, 22), force=True, model=ScriptedModel([]))

        assert counts == {**COUNTS, "rondas": 1, "held": 1}

    def test_runs_from_the_dispatcher(self, monkeypatch):
        db = FakeFirestore(on())
        monkeypatch.delenv("BASETEN_API_KEY", raising=False)
        monkeypatch.delenv("MVD_API_CLIENT_ID", raising=False)
        sender = Sender()

        counts = jobs.run("day_of", db, THU_15, jobs.Context(send=sender, app_url=APP))

        assert counts["sent"] == 1
        assert bodies(sender)["tok-demo-101"] == f"{gates.introduction('Mirta')} {PLAIN}"


class TestFallback:
    @pytest.mark.parametrize(
        ("script", "why"),
        [
            ([ModelUnavailable("down")], "el modelo terminó (failed)"),
            ([RuntimeError("boom")], "falló (RuntimeError)"),
            ([turn(content="Listo.")], "Listo."),
            (
                [turn(call("get_next_buses", reason="ver ómnibus"))] * day_of.MAX_STEPS,
                "el modelo terminó (capped)",
            ),
        ],
        ids=["model-down", "model-error", "no-call", "capped"],
    )
    def test_without_the_models_reminder_code_sends_it_without_buses(self, script, why):
        db = FakeFirestore(on())
        sender = Sender()

        counts = run(db, sender=sender, script=script)

        assert counts["sent"] == 1
        assert bodies(sender)["tok-demo-102"] == f"{gates.introduction('Jorge')} {PLAIN}"
        assert notes(db) == [f"Ronda mandó el recordatorio sin los ómnibus: {why}."]
        assert db.documents[f"agent_runs/{RUN}"]["status"] == "done"

    def test_without_model_keys_code_sends_it(self, monkeypatch):
        monkeypatch.delenv("BASETEN_API_KEY", raising=False)
        db = FakeFirestore(on())
        sender = Sender()

        counts = day_of.run_day_of(db, THU_15, send=sender, buses=FakeBuses())

        assert counts["sent"] == 1
        assert notes(db) == [
            "Ronda mandó el recordatorio sin los ómnibus: no hay modelo (model keys missing)."
        ]

    def test_a_failure_while_sending_counts_as_failed(self):
        db = FakeFirestore(on())

        counts = run(db, sender=Sender(error=RuntimeError("fcm down")))

        assert counts == {**COUNTS, "rondas": 1, "failed": 1}
        assert db.documents[f"agent_runs/{RUN}"]["status"] == "failed"

    def test_nobody_reached_is_not_sent(self):
        db = FakeFirestore(on())
        failing = {token: "failed" for token in ("tok-demo-101", "tok-demo-102", "tok-web")}

        counts = run(db, sender=Sender(outcomes=failing))

        assert counts == {**COUNTS, "rondas": 1, "notSent": 1}

    def test_a_bus_line_that_fails_a_gate_is_left_out(self):
        db = FakeFirestore(on())
        sender = Sender()
        odd = replace(FOUND, stop=replace(STOP, name="Rambla Inventada 1234"))

        run(db, sender=sender, buses=FakeBuses(odd))

        assert bodies(sender)["tok-demo-102"] == f"{gates.introduction('Jorge')} {PLAIN}"
        assert notes(db) == [
            "Dejó afuera los ómnibus: parece una casa o una dirección: «Rambla Inventada 1234»."
        ]

    def test_the_model_saying_no_buses_sends_it_without_them(self):
        db = FakeFirestore(on())
        sender = Sender()

        run(db, sender=sender, script=reminder(include_buses=False))

        assert bodies(sender)["tok-demo-101"] == f"{gates.introduction('Mirta')} {PLAIN}"

    def test_a_second_send_is_refused(self):
        db = FakeFirestore(on())
        sender = Sender()
        script = reminder()
        script.insert(2, turn(call("send_reminder", include_buses=True, reason="otra vez")))

        run(db, sender=sender, script=script)

        assert len(sender.messages) == 3
        sends = [s for s in steps(db) if s.get("tool") == "send_reminder"]
        assert [s["status"] for s in sends] == ["ok", "refused"]
        assert sends[1]["resultSummary"] == "Ya mandó el recordatorio de hoy."

    def test_a_reminder_every_gate_holds_is_held(self):
        db = FakeFirestore(on(place={**PLACE, "name": "la plaza \U0001f600"}))
        sender = Sender()

        counts = run(db, sender=sender)

        assert counts["notSent"] == 1
        assert sender.messages == []
        send = next(s for s in steps(db) if s.get("tool") == "send_reminder")
        assert send["status"] == "held"
        assert (
            send["resultSummary"]
            == "Les recordó la reunión de hoy a 0 con los próximos ómnibus. Frenó 2."
        )


def toolbox(db, *, now=THU_15, buses=None, **ronda) -> Toolbox:
    ronda_doc = {**db.documents[f"rondas/{RONDA}"], **ronda}
    meeting = Meeting(
        ronda_id=RONDA,
        ronda=ronda_doc,
        day=THURSDAY,
        hour=(ronda_doc.get("slot") or {}).get("hour"),
        week=WEEK,
        lat=PLAZA[0],
        lng=PLAZA[1],
    )
    return Toolbox(
        db=db,
        now=now,
        meeting=meeting,
        weather=None,
        send=Sender(),
        app_url=APP,
        trace=Trace(db, "run", ronda_id=RONDA, week=WEEK, now=now),
        host=None,
        host_fallback=False,
        covered={},
        buses=buses,
    )


ASK = Args(reason="ver ómnibus")


class TestGetNextBuses:
    def test_asks_for_the_stop_nearest_the_rondas_place(self):
        db = FakeFirestore(on())
        buses = FakeBuses()
        box = toolbox(db, buses=buses)

        result = get_next_buses(box, ASK)

        assert buses.asked == [PLAZA]
        assert result.data == {
            "stop": "26 de Marzo y Jose Ellauri",
            "metres": 30,
            "buses": [
                {"line": "191", "destination": "Punta Carretas", "minutes": 6},
                {"line": "192", "destination": "", "minutes": 15},
            ],
            "source": "Intendencia de Montevideo",
        }
        assert box.next_buses == FOUND

    def test_a_stop_with_nothing_coming_says_so(self):
        db = FakeFirestore(on())
        box = toolbox(db, buses=FakeBuses(replace(FOUND, arrivals=[])))

        result = get_next_buses(box, ASK)

        assert result.data["buses"] == []
        assert result.summary == (
            "Miró los próximos ómnibus en 26 de Marzo y Jose Ellauri: no viene ninguno en la "
            "próxima media hora."
        )
        assert box.next_buses is None

    def test_no_stop_near_a_place_outside_montevideo(self):
        db = FakeFirestore(on())

        result = get_next_buses(toolbox(db, buses=FakeBuses(None)), ASK)

        assert result.status == "ok"
        assert result.data == {"stop": None, "buses": []}
        assert "no hay una parada de la Intendencia cerca" in result.summary

    @pytest.mark.parametrize(
        ("ronda", "now", "buses", "summary"),
        [
            (
                {"slot": {"day": "thu", "time": "afternoon"}},
                THU_15,
                FakeBuses(),
                "La reunión no tiene hora: no hay próximos ómnibus que mirar.",
            ),
            (
                {},
                at(5, 13),
                FakeBuses(),
                "La reunión no es dentro de la hora: no hay próximos ómnibus que mirar.",
            ),
            (
                {"place": {"name": "la Plaza Gomensoro"}},
                THU_15,
                FakeBuses(),
                "La ronda no tiene un lugar con ubicación.",
            ),
            ({}, THU_15, None, "No tiene acceso a los ómnibus en vivo de la Intendencia."),
        ],
        ids=["no-hour", "not-within-the-hour", "no-coordinates", "no-keys"],
    )
    def test_refuses_without_asking_the_api(self, ronda, now, buses, summary):
        db = FakeFirestore(on())

        result = get_next_buses(toolbox(db, now=now, buses=buses, **ronda), ASK)

        assert result.status == "refused"
        assert result.summary == summary
        if buses is not None:
            assert buses.asked == []


class TestWords:
    def test_one_minute_is_singular(self):
        found = replace(FOUND, arrivals=[mvd_buses.Arrival("191", "", 1)])

        assert day_of.bus_line(found).endswith("el 191 en 1 minuto.")

    def test_without_a_place_the_reminder_says_only_the_hour(self):
        db = FakeFirestore(on(place={"name": ""}))
        box = toolbox(db, place={"name": ""})

        assert day_of.reminder_text(box.meeting) == "Hoy nos vemos a las 16:00."

    def test_the_model_learns_no_name(self):
        db = FakeFirestore(on())
        model = ScriptedModel(reminder())

        run(db, model=model)

        told = model.requests[0][0][1]["content"]
        assert told == (
            "Ronda: mate en la rambla.\n"
            "Reunión: hoy 2026-11-05 a las 16:00, en la Plaza Gomensoro.\n"
            "Ahora: 15:00."
        )
        for name in ("Mirta", "Jorge", "Ana", "Facu"):
            assert name not in str(model.requests)
