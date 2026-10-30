"""The organiser's parts on their own: the word checks, the gates, the forecast, the model
client and the loop. Nothing reaches a network: the model and Open-Meteo are fakes."""

import json
from datetime import UTC, date, datetime
from typing import ClassVar

import httpx
import openai
import pytest

from organiser import gates, model, text, weather
from organiser.agent import CAPPED, DONE, FAILED, STOPPED, run_agent
from organiser.model import ChatModel, FallbackModel, ModelUnavailable, ToolCall, Turn
from organiser.trace import Trace
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import (
    RONDA,
    WED_18,
    WED_22,
    WEEK,
    FakeOpenAI,
    ScriptedModel,
    at,
    call,
    chunk,
    fragment,
    turn,
)


class TestStripMarkdown:
    @pytest.mark.parametrize(
        ("written", "plain"),
        [
            ("**Listo**: le propuse opciones.", "Listo: le propuse opciones."),
            ("__Listo__ y _ya_ está, *che*.", "Listo y ya está, che."),
            ("## Resumen\n- uno\n- dos\n1. tres", "Resumen uno dos tres"),
            ("> cita\n\n---\nfin", "cita fin"),
            (
                "Usá `get_forecast` y [Open-Meteo](https://open-meteo.com).",
                "Usá get_forecast y Open-Meteo.",
            ),
            ("![foto](x.png) ```py\ncódigo\n```", "foto código"),
            ("mate_flyer y 3 * 4", "mate_flyer y 3 * 4"),
        ],
    )
    def test_leaves_plain_words_on_one_line(self, written, plain):
        assert text.strip_markdown(written) == plain


class TestEmoji:
    @pytest.mark.parametrize("found", ["🧉", "☔", "✔", "⭐", "🇺🇾", "⌛", "️"])
    def test_finds_emoji(self, found):
        assert text.emoji(f"Nos vemos {found} mañana") == found[0]

    def test_leaves_typography_alone(self):
        assert text.emoji("Jueves 16:00 · lluvia 80%. ¿Venís? 20° \u2013 sí… ñandú ©") == ""


class TestVoseo:
    @pytest.mark.parametrize(
        ("written", "found"),
        [
            ("¿Tú vienes?", "Tú"),
            ("¿Tienes el termo?", "Tienes"),
            ("Es para ti", "para ti"),
            ("Vamos contigo", "contigo"),
            ("Si puedes, avisá", "puedes"),
        ],
    )
    def test_finds_tu_forms(self, written, found):
        assert text.tu_forms(written) == found

    def test_lets_voseo_and_shared_forms_pass(self):
        assert (
            text.tu_forms("¿Venís? Si podés, llevá el termo. Estás invitado, vas a tu ronda.") == ""
        )


class TestPrivatePlace:
    @pytest.mark.parametrize(
        ("written", "found"),
        [
            ("Nos vemos en lo de Mirta", "en lo de"),
            ("Nos vemos en casa de Jorge", "en casa de"),
            ("Es en Av. Central 1234", "Av. Central 1234"),
            ("Es en calle Los Pinos 55", "calle Los Pinos 55"),
            ("Es en Gral. Flores 2345", "Gral. Flores 2345"),
        ],
    )
    def test_finds_homes_and_addresses(self, written, found):
        assert text.private_place(written) == found

    def test_lets_public_places_and_times_pass(self):
        assert (
            text.private_place("Nos vemos en el Salón Comunal a las 16:00, frente al quiosco.")
            == ""
        )


class TestGates:
    def message(self, **fields) -> gates.Outgoing:
        values = {
            "title": "El jueves puede llover",
            "text": "Jueves 16:00 · lluvia 80%.",
            "kind": gates.HOST,
            "introduced": True,
        }
        return gates.Outgoing(**(values | fields))

    def test_lets_a_clean_message_through(self):
        assert gates.check(self.message(), WED_18) == gates.ALLOWED

    @pytest.mark.parametrize(
        ("now", "release"),
        [(WED_22, at(5, 9)), (at(5, 3), at(5, 9)), (at(4, 21), at(5, 9)), (at(4, 8, 59), at(4, 9))],
    )
    def test_holds_everything_from_21_to_9_until_the_next_9(self, now, release):
        verdict = gates.check(self.message(), now)

        assert verdict == gates.Verdict(False, "quiet_hours", "fuera de horario", release)

    def test_lets_9_and_20_59_through(self):
        assert gates.check(self.message(), at(4, 9)).allowed
        assert gates.check(self.message(), at(4, 20, 59)).allowed

    def test_a_first_message_must_say_it_is_a_program(self):
        verdict = gates.check(self.message(introduced=False), WED_18)
        assert verdict.gate == "disclosure"

        introduced = f"{gates.introduction('Mirta')} Jueves 16:00."
        assert gates.check(self.message(introduced=False, text=introduced), WED_18).allowed

    def test_the_introduction_greets_by_first_name(self):
        assert gates.introduction("Graciela") == (
            "Hola, Graciela. Soy un programa. Ronda me usa para avisar horarios, lugares y lluvia. "
            "Las decisiones las toman ustedes. Nunca escribo de noche."
        )
        assert gates.introduction("").startswith("Hola. Soy un programa.")

    @pytest.mark.parametrize(
        ("fields", "gate", "reason"),
        [
            ({"title": "Llueve ☔"}, "emoji", "tiene un emoji (☔)"),
            ({"text": "¿Puedes venir?"}, "voseo", "no está en voseo: «Puedes»"),
            (
                {"text": "En lo de Mirta"},
                "public_place",
                "parece una casa o una dirección: «En lo de»",
            ),
            (
                {"place": gates.Place("lo de Mirta", "home")},
                "public_place",
                "lo de Mirta no es un lugar público",
            ),
            (
                {"kind": gates.ROUTINE, "routine_used": True},
                "routine",
                "ya recibió el mensaje de rutina de esta semana",
            ),
        ],
    )
    def test_each_gate_holds_its_message_with_a_reason(self, fields, gate, reason):
        verdict = gates.check(self.message(**fields), WED_18)

        assert (verdict.allowed, verdict.gate, verdict.reason) == (False, gate, reason)
        assert verdict.release_at is None

    def test_a_change_or_a_proposal_is_never_routine(self):
        for kind in (gates.CHANGE, gates.HOST):
            assert gates.check(self.message(kind=kind, routine_used=True), WED_18).allowed

    def test_a_public_place_passes(self):
        assert gates.check(self.message(place=gates.Place("la plaza")), WED_18).allowed


class TestWeather:
    BODY: ClassVar[dict] = {
        "hourly": {
            "time": ["2026-11-05T15:00", "2026-11-05T16:00", "2026-11-05T17:00"],
            "precipitation_probability": [20, 80, None],
            "precipitation": [0.0, 2.44, 1.0],
            "wind_gusts_10m": [20.4, 49.6, 51.2],
        },
        "daily": {"time": ["2026-11-05"], "sunset": ["2026-11-05T19:52"]},
    }

    def client(self, handler) -> httpx.Client:
        return httpx.Client(transport=httpx.MockTransport(handler))

    def test_reads_one_day_once_and_keeps_it(self):
        requests = []

        def handler(request):
            requests.append(request)
            return httpx.Response(200, json=self.BODY)

        meteo = weather.OpenMeteo(self.client(handler))
        day = meteo.day(-34.8, -55.885, date(2026, 11, 5))
        again = meteo.day(-34.8, -55.885, date(2026, 11, 5))

        assert day is again
        assert len(requests) == 1
        params = dict(requests[0].url.params)
        assert params["hourly"] == weather.HOURLY
        assert params["daily"] == "sunset"
        assert params["timezone"] == "America/Montevideo"
        assert params["start_date"] == params["end_date"] == "2026-11-05"
        assert day.sunset == "19:52"
        assert day.forecast(date(2026, 11, 5), 16) == weather.Forecast(
            date(2026, 11, 5), 16, 80, 2.4, 51
        )

    @pytest.mark.parametrize(
        "response",
        [httpx.Response(500), httpx.Response(200, text="nope"), httpx.Response(200, json={})],
    )
    def test_a_failed_or_odd_answer_is_unavailable(self, response):
        meteo = weather.OpenMeteo(self.client(lambda _: response))

        with pytest.raises(weather.WeatherUnavailable):
            meteo.day(-34.8, -55.885, date(2026, 11, 5))

    def test_a_missing_hour_is_unavailable(self):
        with pytest.raises(weather.WeatherUnavailable):
            weather.parse(self.BODY).forecast(date(2026, 11, 5), 20)


ANSWER = Turn(
    content="",
    tool_calls=(
        ToolCall("call_1", "get_forecast", json.dumps({"date": "2026-11-05", "reason": "ver"})),
        ToolCall("call_2", "count_rsvps", json.dumps({"reason": "contar"})),
    ),
    model=model.SPARK_OPEN,
)


class TestChatModel:
    def test_streams_one_answer_at_low_effort_with_the_tools(self):
        client = FakeOpenAI([ANSWER])

        answer = ChatModel(client, model.SPARK_OPEN).complete([{"role": "user"}], [{"t": 1}])

        assert answer == ANSWER
        assert client.requests == [
            {
                "model": model.SPARK_OPEN,
                "messages": [{"role": "user"}],
                "tools": [{"t": 1}],
                "stream": True,
                "extra_body": {"reasoning_effort": "low"},
            }
        ]

    def test_gathers_words_and_calls_without_ids(self):
        chunks = [
            chunk("**Hola**"),
            chunk(None, [fragment(0, None, "count_rsvps", '{"reason"')]),
            chunk(None, [fragment(0, None, None, ': "x"}')]),
            chunk(None, [fragment(1, "c2", "log_acta", None)]),
        ]

        answer = model.collect(chunks, "m")

        assert answer.content == "**Hola**"
        assert answer.tool_calls == (
            ToolCall("call_0", "count_rsvps", '{"reason": "x"}'),
            ToolCall("c2", "log_acta", ""),
        )

    @pytest.mark.parametrize(
        "error",
        [
            openai.APIConnectionError(request=httpx.Request("POST", "https://x")),
            httpx.ReadTimeout("slow"),
        ],
    )
    def test_any_sdk_or_connection_error_is_unavailable(self, error):
        with pytest.raises(ModelUnavailable):
            ChatModel(FakeOpenAI([error]), model.SPARK_OPEN).complete([], [])

    def test_raw_atem_text_is_unavailable(self):
        leaked = Turn(content='<atem:call name="get_forecast">', model=model.SPARK_OPEN)

        with pytest.raises(ModelUnavailable, match="ATEM"):
            ChatModel(FakeOpenAI([leaked]), model.SPARK_OPEN).complete([], [])

    def test_a_turn_carries_its_calls_into_the_next_request(self):
        assert ANSWER.message() == {
            "role": "assistant",
            "content": "",
            "tool_calls": [
                {
                    "id": "call_1",
                    "type": "function",
                    "function": {
                        "name": "get_forecast",
                        "arguments": ANSWER.tool_calls[0].arguments,
                    },
                },
                {
                    "id": "call_2",
                    "type": "function",
                    "function": {
                        "name": "count_rsvps",
                        "arguments": ANSWER.tool_calls[1].arguments,
                    },
                },
            ],
        }
        assert Turn(content="Listo").message() == {"role": "assistant", "content": "Listo"}


class TestFallbackModel:
    def test_moves_to_spark_for_the_rest_of_the_run_when_spark_open_fails(self):
        primary = ScriptedModel([ModelUnavailable("down")], name=model.SPARK_OPEN)
        fallback = ScriptedModel([turn(content="a"), turn(content="b")], name=model.SPARK)
        chain = FallbackModel(primary, fallback)

        assert chain.name == model.SPARK_OPEN
        assert chain.complete([], []).content == "a"
        assert chain.name == model.SPARK
        assert chain.complete([], []).content == "b"
        assert len(primary.requests) == 1

    def test_stays_on_spark_open_while_it_answers(self):
        primary = ScriptedModel([turn(content="a")], name=model.SPARK_OPEN)
        chain = FallbackModel(primary, ScriptedModel([], name=model.SPARK))

        assert chain.complete([], []).content == "a"
        assert chain.name == model.SPARK_OPEN

    def test_builds_both_from_the_functions_secrets(self, monkeypatch):
        monkeypatch.setenv("BASETEN_API_KEY", "test-baseten")
        monkeypatch.setenv("MODEL_API_KEY", "test-meta")
        built = []

        class Client:
            def __init__(self, **options):
                built.append(options)

        monkeypatch.setattr(openai, "OpenAI", Client)

        chain = model.from_environment()

        assert chain.name == model.SPARK_OPEN
        assert [(b["base_url"], b["api_key"]) for b in built] == [
            (model.BASETEN_BASE, "test-baseten"),
            (model.META_BASE, "test-meta"),
        ]

    @pytest.mark.parametrize("missing", ["BASETEN_API_KEY", "MODEL_API_KEY"])
    def test_needs_both_keys(self, monkeypatch, missing):
        monkeypatch.setenv("BASETEN_API_KEY", "test-baseten")
        monkeypatch.setenv("MODEL_API_KEY", "test-meta")
        monkeypatch.delenv(missing)

        with pytest.raises(ModelUnavailable):
            model.from_environment()


class EchoToolbox:
    """Two tools, `ok` and `count_rsvps`, that echo what they got: enough to drive the loop."""

    def __init__(self):
        self.ran: list[tuple[str, dict]] = []

    def specs(self):
        return [{"type": "function", "function": {"name": "count_rsvps"}}]

    def parse(self, tool_call):
        from organiser.tools import ToolError

        args = json.loads(tool_call.arguments or "{}")
        if tool_call.name != "count_rsvps" or "reason" not in args:
            raise ToolError(f"mal: {tool_call.name}")
        return args

    def run(self, name, args):
        self.ran.append((name, args))
        return {"status": "ok", "going": 3}


def loop(script, max_steps=8):
    db = FakeFirestore()
    trace = Trace(db, "run-1", ronda_id=RONDA, week=WEEK, now=WED_18, clock=lambda: 0.0)
    scripted = ScriptedModel(script)
    toolbox = EchoToolbox()
    outcome = run_agent(
        model=scripted,
        toolbox=toolbox,
        system="sistema",
        task="tarea",
        trace=trace,
        max_steps=max_steps,
        clock=lambda: 0.0,
    )
    steps = [
        db.documents[p] for p in sorted(db.documents) if p.startswith("agent_runs/run-1/steps/")
    ]
    return outcome, steps, scripted, toolbox


class TestLoop:
    def test_runs_the_calls_hands_the_results_back_and_keeps_the_last_words_plain(self):
        outcome, steps, scripted, toolbox = loop(
            [turn(call("count_rsvps", reason="contar")), turn(content="**Van 3**.")]
        )

        assert outcome.status == DONE
        assert outcome.note == "Van 3."
        assert toolbox.ran == [("count_rsvps", {"reason": "contar"})]
        second = scripted.requests[1][0]
        assert [m["role"] for m in second] == ["system", "user", "assistant", "tool"]
        assert json.loads(second[3]["content"]) == {"status": "ok", "going": 3}
        assert second[3]["tool_call_id"] == "call_count_rsvps"
        assert [s["kind"] for s in steps] == ["model", "model"]
        assert steps[0]["toolCalls"] == ["count_rsvps"]

    def test_retries_once_with_the_validation_error(self):
        outcome, steps, scripted, _ = loop(
            [
                turn(call("count_rsvps", nope=1)),
                turn(call("count_rsvps", reason="contar")),
                turn(content="Listo."),
            ]
        )

        assert outcome.status == DONE
        error = json.loads(scripted.requests[1][0][-1]["content"])
        assert error == {"status": "invalid", "error": "mal: count_rsvps"}
        invalid = [s for s in steps if s["kind"] == "tool"]
        assert invalid[0]["status"] == "invalid"
        assert invalid[0]["resultSummary"] == "mal: count_rsvps"

    def test_stops_when_the_retry_comes_back_wrong_too(self):
        outcome, steps, _, toolbox = loop(
            [turn(call("count_rsvps", nope=1)), turn(call("propose_move", nope=2))]
        )

        assert outcome.status == STOPPED
        assert steps[-1] == steps[-1] | {
            "kind": "stop",
            "why": "la llamada volvió a venir mal después de un reintento",
        }
        assert toolbox.ran == []

    def test_stops_at_the_step_cap(self):
        outcome, steps, _, _ = loop([turn(call("count_rsvps", reason="x"))] * 3, max_steps=3)

        assert outcome.status == CAPPED
        assert steps[-1]["why"] == "llegó al tope de 3 pasos"

    def test_a_model_that_fails_ends_the_run(self):
        outcome, steps, _, _ = loop([ModelUnavailable("APIConnectionError")])

        assert outcome.status == FAILED
        assert steps[-1]["why"] == "el modelo no respondió (APIConnectionError)"


def test_the_trace_counts_on_from_a_run_that_already_has_steps():
    db = FakeFirestore({"agent_runs/r": {"stepCount": 4, "actaCount": 2}})
    trace = Trace(db, "r", ronda_id=RONDA, week=WEEK, now=datetime(2026, 11, 4, 21, tzinfo=UTC))

    assert trace.step("note", note="x") == 5
    trace.acta("note", "y")

    assert "agent_runs/r/steps/005" in db.documents
    assert f"acta/{RONDA}/entries/r-003" in db.documents
    assert trace.steps == 5
