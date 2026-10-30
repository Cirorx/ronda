"""The organiser's tools and its outbox, one call at a time, over the Firestore stand-in and the
rainy Thursday of `organiser_fakes`."""

import json

import pytest

import rsvp
from organiser import gates, outbox
from organiser.model import ToolCall
from organiser.tools import TOOLS, Meeting, Toolbox, ToolError
from organiser.trace import Trace
from rain import _covered_places
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import (
    DRY,
    HOST,
    RONDA,
    THURSDAY,
    WED_18,
    WED_22,
    WEEK,
    FakeWeather,
    at,
    call,
    documents,
)
from tests.test_rsvp import Sender

APP = "https://example.test/app/ronda"


def toolbox(db=None, *, now=WED_18, weather=None, sender=None, fallback=False, **ronda_fields):
    db = db or FakeFirestore(documents(**ronda_fields))
    ronda = db.documents[f"rondas/{RONDA}"]
    meeting = Meeting(RONDA, ronda, THURSDAY, rsvp.meeting_hour(ronda), WEEK, -34.8, -55.885)
    return Toolbox(
        db=db,
        now=now,
        meeting=meeting,
        weather=weather or FakeWeather(),
        send=sender or Sender(),
        app_url=APP,
        trace=Trace(db, "run-1", ronda_id=RONDA, week=WEEK, now=now, clock=lambda: 0.0),
        host=outbox.Recipient(HOST, "Mirta", outbox.HOST),
        host_fallback=fallback,
        covered=_covered_places(db, ronda.get("barrio", "")),
        model_name=lambda: "scripted",
        clock=lambda: 0.0,
    )


def use(box: Toolbox, name: str, **arguments) -> dict:
    return box.run(name, box.parse(call(name, **arguments)))


def acta(box: Toolbox) -> list[str]:
    prefix = f"acta/{RONDA}/entries/"
    return [
        box.db.documents[p]["summary"] for p in sorted(box.db.documents) if p.startswith(prefix)
    ]


def steps(box: Toolbox) -> list[dict]:
    prefix = "agent_runs/run-1/steps/"
    return [box.db.documents[p] for p in sorted(box.db.documents) if p.startswith(prefix)]


D = THURSDAY.isoformat()
R = "porque sí"


class TestToolbox:
    def test_offers_every_tool_with_a_strict_schema_and_a_required_reason(self):
        specs = toolbox().specs()

        assert [s["function"]["name"] for s in specs] == list(TOOLS)
        for spec in specs:
            schema = spec["function"]["parameters"]
            assert schema["additionalProperties"] is False
            assert "reason" in schema["required"]
            assert set(schema["required"]) == set(schema["properties"])
            assert "anyOf" not in json.dumps(schema)

    @pytest.mark.parametrize(
        ("tool_call", "message"),
        [
            (call("delete_everything", reason=R), "No existe la herramienta 'delete_everything'"),
            (call("count_rsvps"), "Argumentos inválidos para count_rsvps: reason: Field required"),
            (call("count_rsvps", reason=R, extra=1), "extra: Extra inputs are not permitted"),
            (call("get_forecast", date="jueves", reason=R), "date: String should match pattern"),
        ],
    )
    def test_refuses_a_call_that_doesnt_fit_and_says_why(self, tool_call, message):
        with pytest.raises(ToolError, match=message):
            toolbox().parse(tool_call)

    def test_reads_missing_or_broken_arguments_as_invalid(self):
        box = toolbox()
        for arguments, problem in (("", "reason: Field required"), ("{not json", "argumentos:")):
            with pytest.raises(ToolError, match=problem):
                box.parse(ToolCall("c", "count_rsvps", arguments))

    def test_logs_each_call_in_the_trace_and_the_acta(self):
        box = toolbox()

        use(box, "count_rsvps", reason="contar")

        [step] = steps(box)
        assert step | {"ts": None} == {
            "n": 1,
            "ts": None,
            "kind": "tool",
            "tool": "count_rsvps",
            "argsSummary": "",
            "reason": "contar",
            "resultSummary": "Contó las respuestas: van 2, no pueden 1, sin contestar 1.",
            "status": "ok",
            "latencyMs": 0,
            "model": "scripted",
        }
        assert acta(box) == ["Contó las respuestas: van 2, no pueden 1, sin contestar 1."]


class TestForecastAndSunset:
    def test_reads_the_meeting_hours(self):
        result = use(toolbox(), "get_forecast", date=D, reason=R)

        assert result == {
            "status": "ok",
            "date": D,
            "hour": 16,
            "rainProbability": 80,
            "rainMm": 2.4,
            "gustsKmh": 50,
            "rainLikely": True,
            "source": "Open-Meteo",
        }

    def test_a_dry_day_is_not_likely(self):
        assert (
            use(toolbox(weather=FakeWeather(DRY)), "get_forecast", date=D, reason=R)["rainLikely"]
            is False
        )

    @pytest.mark.parametrize("tool", ["get_forecast", "get_sunset"])
    @pytest.mark.parametrize("day", ["2026-11-03", "2026-11-12", "2026-13-01"])
    def test_refuses_days_without_a_forecast(self, tool, day):
        box = toolbox()

        assert use(box, tool, date=day, reason=R)["status"] == "refused"
        assert acta(box) == [f"No pidió un día con pronóstico: {day}."]

    def test_says_when_open_meteo_is_down(self):
        box = toolbox(weather=FakeWeather(fail=True))

        assert use(box, "get_forecast", date=D, reason=R)["status"] == "refused"
        assert use(box, "get_sunset", date=D, reason=R)["status"] == "refused"
        assert acta(box) == [
            "No pudo leer el pronóstico del jueves 5/11.",
            "No pudo leer a qué hora atardece el jueves 5/11.",
        ]

    def test_reads_the_sunset(self):
        box = toolbox()

        assert use(box, "get_sunset", date=D, reason=R)["sunset"] == "19:52"
        assert acta(box) == ["Miró a qué hora atardece el jueves 5/11: 19:52."]


class TestLastBus:
    def test_reads_the_barrios_flyer(self):
        box = toolbox()

        result = use(box, "get_last_bus", date=D, reason=R)

        assert result["time"] == "21:10"
        assert result["route"] == "711"
        assert acta(box) == [
            "Miró el último ómnibus del jueves 5/11: 21:10, línea 711 (horario publicado)."
        ]

    def test_without_a_route_it_says_the_time_only(self):
        db = FakeFirestore(documents())
        db.documents["flyers/abcd1234"]["lastBus"]["weekday"] = {"time": "20:40"}
        box = toolbox(db)

        use(box, "get_last_bus", date=D, reason=R)

        assert acta(box) == ["Miró el último ómnibus del jueves 5/11: 20:40 (horario publicado)."]

    def test_prefers_a_flyer_hung_in_the_barrio_itself(self):
        db = FakeFirestore(documents())
        db.documents["flyers/zzzz9999"] = {
            "kind": "tearOff",
            "barrio": "el-pinar-sur",
            "nearBarrios": ["el-pinar-sur"],
            "lastBus": {"weekday": {"time": "22:05", "route": "7"}},
        }

        assert use(toolbox(db), "get_last_bus", date=D, reason=R)["time"] == "22:05"

    def test_without_a_stored_bus_it_says_so(self):
        box = toolbox(barrio="shangrila")

        result = use(box, "get_last_bus", date="2026-11-07", reason=R)

        assert result == {"status": "ok", "dayType": "saturday", "time": None}
        assert acta(box) == ["Buscó el último ómnibus: no hay horario guardado para este barrio."]

    def test_refuses_a_date_that_isnt_one(self):
        assert use(toolbox(), "get_last_bus", date="2026-02-30", reason=R)["status"] == "refused"


class TestCount:
    def test_reads_nothing_from_another_weeks_view(self):
        db = FakeFirestore(documents())
        db.documents[f"rondas/{RONDA}/views/week"]["week"] = "2026-W44"

        assert use(toolbox(db), "count_rsvps", reason=R) == {
            "status": "ok",
            "week": WEEK,
            "going": 0,
            "no": 0,
            "unanswered": 0,
        }

    def test_reads_nothing_before_the_view_exists(self):
        db = FakeFirestore(documents())
        del db.documents[f"rondas/{RONDA}/views/week"]

        assert use(toolbox(db), "count_rsvps", reason=R)["going"] == 0


class TestProposeMove:
    def propose(self, box, place_id="salon-pinar", postpone_to="2026-11-06"):
        return use(box, "propose_move", place_id=place_id, postpone_to=postpone_to, reason=R)

    def test_proposes_once_a_week(self):
        box = toolbox()
        sender = box.send

        assert self.propose(box) == {
            "status": "ok",
            "proposed": True,
            "options": ["covered", "postpone", "asIs"],
            "delivery": "sent",
        }
        assert self.propose(box) == {"status": "ok", "proposed": True}
        assert len(sender.messages) == 1
        assert sender.messages[0]["data"] | {"title": "", "body": ""} == {
            "type": "move",
            "rondaId": RONDA,
            "week": WEEK,
            "title": "",
            "body": "",
        }
        assert acta(box)[-1] == "Ya le había propuesto qué hacer al anfitrión esta semana."

    def test_links_a_browser_to_the_hosts_screen(self):
        db = FakeFirestore(documents())
        db.documents[f"users/{HOST}/tokens/tok-{HOST}"]["platform"] = "web"
        box = toolbox(db)

        self.propose(box)

        link = box.send.messages[0]["webpush"]["fcm_options"]["link"]
        assert link == f"https://example.test/app/lluvia/{RONDA}/{WEEK}"

    @pytest.mark.parametrize(
        ("box_fields", "args", "summary"),
        [
            (
                {"weather": FakeWeather(DRY)},
                {},
                "No propuso nada: el pronóstico da 10% de lluvia, menos del 60%.",
            ),
            (
                {"weather": FakeWeather(fail=True)},
                {},
                "No propuso nada: no pudo leer el pronóstico.",
            ),
            (
                {},
                {"place_id": "plaza-pinar"},
                "No propuso nada: 'plaza-pinar' no es un lugar techado de la lista.",
            ),
            (
                {},
                {"postpone_to": "2026-11-05"},
                "No propuso nada: 2026-11-05 no está entre el día siguiente a la reunión y 3 días "
                "después.",
            ),
            (
                {},
                {"postpone_to": "2026-11-09"},
                "No propuso nada: 2026-11-09 no está entre el día siguiente a la reunión y 3 días "
                "después.",
            ),
            (
                {},
                {"postpone_to": "2026-13-45"},
                "No propuso nada: 2026-13-45 no es una fecha.",
            ),
            (
                {"now": at(5, 10)},
                {},
                "No propuso nada: ya pasó la hora para que el anfitrión elija.",
            ),
        ],
    )
    def test_refuses_what_isnt_a_proposal_to_make(self, box_fields, args, summary):
        box = toolbox(**box_fields)

        result = self.propose(box, **args)

        assert result["status"] == "refused"
        assert acta(box) == [summary]
        assert f"rondas/{RONDA}/moves/{WEEK}" not in box.db.documents
        assert box.send.messages == []

    def test_holds_a_proposal_at_night_and_writes_no_move(self):
        box = toolbox(now=WED_22)

        assert self.propose(box) == {
            "status": "held",
            "proposed": False,
            "held": "fuera de horario",
        }
        assert f"rondas/{RONDA}/moves/{WEEK}" not in box.db.documents
        tool, message = steps(box)
        assert (tool["kind"], tool["status"]) == ("tool", "held")
        assert message["outcome"] == "held"

    def test_offers_only_going_anyway_when_nothing_else_fits(self):
        box = toolbox()

        self.propose(box, place_id="", postpone_to="")

        move = box.db.documents[f"rondas/{RONDA}/moves/{WEEK}"]
        assert move["options"] == [
            {
                "id": "asIs",
                "label": "Vamos igual",
                "message": "Puede llover, pero el jueves vamos igual, a las 16:00 como siempre. "
                "Lo decidió Mirta.",
            }
        ]

    def test_a_stand_in_host_isnt_called_the_one_who_opens(self):
        box = toolbox(fallback=True)

        self.propose(box)

        assert acta(box)[0].startswith("Le propuso a Mirta, qué hacer por la lluvia")

    def test_a_failed_send_leaves_no_move(self):
        box = toolbox(sender=Sender(error=ConnectionError("fcm")))

        with pytest.raises(ConnectionError):
            self.propose(box)

        assert f"rondas/{RONDA}/moves/{WEEK}" not in box.db.documents


class TestSendMemberPush:
    def test_the_rsvp_was_this_weeks_routine_message(self):
        box = toolbox()

        result = use(box, "send_member_push", text="Mañana llueve.", reason=R)

        assert result == {
            "status": "held",
            "sent": 0,
            "held": 4,
            "why": ["ya recibió el mensaje de rutina de esta semana"],
        }
        assert acta(box) == [
            "Frenó un mensaje para los miembros: ya recibió el mensaje de rutina de esta semana."
        ]
        assert box.send.messages == []

    def test_sends_once_without_markdown_and_then_the_week_is_used(self):
        db = FakeFirestore(documents())
        del db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]
        box = toolbox(db)

        first = use(box, "send_member_push", text="**Mañana** llevá paraguas.", reason=R)
        second = use(box, "send_member_push", text="Otra vez.", reason=R)

        assert first == {"status": "ok", "sent": 4, "held": 0, "unreachable": 0}
        assert second["status"] == "held"
        assert box.send.messages[0]["data"]["body"].endswith("Mañana llevá paraguas.")
        assert acta(box)[0] == "Les avisó a 4: «Mañana llevá paraguas.»."
        history = db.documents["users/demo-102/private/agent"]
        assert history == {"introducedAt": WED_18, "routine": {WEEK: WED_18}}

    def test_a_tu_form_is_held_for_everyone(self):
        db = FakeFirestore(documents())
        del db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]
        box = toolbox(db)

        result = use(box, "send_member_push", text="¿Vienes mañana?", reason=R)

        assert result["why"] == ["no está en voseo: «Vienes»"]

    def test_some_held_and_some_sent_counts_both(self):
        db = FakeFirestore(documents())
        del db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]
        db.documents["users/demo-103/private/agent"] = {
            "introducedAt": WED_18,
            "routine": {WEEK: WED_18},
        }
        box = toolbox(db)

        result = use(box, "send_member_push", text="Mañana llueve.", reason=R)

        assert result == {"status": "ok", "sent": 3, "held": 1, "unreachable": 0}


class TestLogActa:
    def test_writes_the_models_line_once_without_markdown(self):
        box = toolbox()

        use(box, "log_acta", summary="**Propuse** un salón.", reason=R)
        use(box, "log_acta", summary="Propuse un salón.", reason=R)

        assert acta(box) == ["Propuse un salón."]
        assert len(steps(box)) == 2

    def test_refuses_a_line_that_fails_the_word_gates(self):
        box = toolbox()

        assert use(box, "log_acta", summary="Llueve 🌧", reason=R)["status"] == "refused"
        assert acta(box) == ["Quiso anotar algo que no pasó los controles: tiene un emoji (🌧)."]


class TestMeeting:
    def test_a_ronda_without_a_place_names_none(self):
        assert toolbox(place=None).meeting.place is None
        assert toolbox().meeting.place == gates.Place("frente al quiosco")


class TestOutbox:
    def draft(self, db, uid="demo-104", kind=gates.CHANGE, **fields):
        return outbox.prepare(
            db,
            outbox.Recipient(uid, "Facu"),
            title="Jueves",
            text="Por la lluvia, nos vemos en el salón.",
            kind=kind,
            week=WEEK,
            now=WED_18,
            **fields,
        )

    def deliver(self, db, draft, sender):
        trace = Trace(db, "run-1", ronda_id=RONDA, week=WEEK, now=WED_18, clock=lambda: 0.0)
        return outbox.deliver(
            db, trace, draft, send=sender, data={"type": "agent"}, link=APP, now=WED_18
        )

    def test_a_phone_fcm_no_longer_knows_is_forgotten(self):
        db = FakeFirestore(documents())
        sender = Sender({"tok-demo-104": "unregistered"})

        assert self.deliver(db, self.draft(db), sender) == "unreachable"
        assert "users/demo-104/tokens/tok-demo-104" not in db.documents
        assert "users/demo-104/private/agent" not in db.documents

    def test_someone_without_a_phone_is_unreachable(self):
        db = FakeFirestore(documents())
        del db.documents["users/demo-104/tokens/tok-demo-104"]
        db.documents["users/demo-104/tokens/tok-i"] = {"platform": "ios"}

        assert self.deliver(db, self.draft(db), Sender()) == "unreachable"

    def test_the_emulator_skips_every_send(self):
        db = FakeFirestore(documents())
        sender = Sender({"tok-demo-104": "skipped"})

        assert self.deliver(db, self.draft(db), sender) == "skipped"

    def test_an_introduced_person_gets_a_change_with_nothing_to_remember(self):
        db = FakeFirestore(documents())
        db.documents["users/demo-104/private/agent"] = {"introducedAt": WED_18}

        draft = self.draft(db)

        assert draft.text == "Por la lluvia, nos vemos en el salón."
        assert self.deliver(db, draft, Sender()) == "sent"
        assert db.documents["users/demo-104/private/agent"] == {"introducedAt": WED_18}
