"""weekly_card.py: the organiser agent's weekly card, over the Firestore stand-in, a scripted
model and a fake forecast. The first tests are #62's "Done when"."""

from dataclasses import replace
from datetime import timedelta

import pytest

import jobs
import weekly_card
from organiser import gates
from organiser.model import ModelUnavailable
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import (
    DRY,
    HOST,
    RONDA,
    THURSDAY,
    WEEK,
    FakeWeather,
    ScriptedModel,
    at,
    call,
    documents,
    turn,
)
from tests.test_rsvp import Sender

MON_10 = at(2, 10)
"""Monday 2026-11-02 10:00 in Montevideo: three days before the Thursday meeting."""
MON_22 = at(2, 22)
RUN = f"{RONDA}_{WEEK}_card"
DAY = THURSDAY.isoformat()

RAIN_BLOCK = {
    "kind": "rain",
    "title": "Puede llover",
    "text": "El jueves a las 16 hay 80% de lluvia. Si llueve, nos vemos en el salón.",
}
HOST_BLOCK = {
    "kind": "host",
    "title": "Quién abre",
    "text": "Esta semana abre {anfitrion}: llega diez minutos antes y saluda.",
}


def compose(*blocks: dict, reason: str = "armar la tarjeta") -> list:
    return [
        turn(call("get_forecast", date=DAY, reason="ver si llueve")),
        turn(call("compose_card", blocks=list(blocks), reason=reason)),
        turn(call("log_acta", summary="Armó la tarjeta de la semana.", reason="anotar")),
        turn(content="**Listo**: la tarjeta quedó armada."),
    ]


def on(**fields) -> dict[str, dict]:
    return documents(agentCard=True, hosts={"anfitrion": HOST}, **fields)


def run(db, now=MON_10, *, script=None, force=False, model=None, weather=None):
    return weekly_card.run_weekly_card(
        db,
        now,
        send=Sender(),
        app_url="https://example.test/app/ronda",
        force=force,
        model=model or ScriptedModel(compose(RAIN_BLOCK, HOST_BLOCK) if script is None else script),
        weather=weather or FakeWeather(),
    )


def card(db, ronda=RONDA) -> dict:
    return db.documents[f"rondas/{ronda}/views/card"]


def steps(db, run_id=RUN) -> list[dict]:
    prefix = f"agent_runs/{run_id}/steps/"
    return [db.documents[p] for p in sorted(db.documents) if p.startswith(prefix)]


def notes(db) -> list[str]:
    return [s["note"] for s in steps(db) if s["kind"] == "note"]


def texts(messages: list[dict]) -> list[str]:
    components = messages[1]["updateComponents"]["components"]
    return [f"{c['title']}\n{c['text']}" for c in components if "text" in c]


class TestDoneWhen:
    def test_two_rondas_get_different_gate_passing_cards_for_the_same_week(self):
        docs = on()
        other = "ronda-truco"
        for path, fields in list(docs.items()):
            if path.startswith(f"rondas/{RONDA}"):
                docs[path.replace(RONDA, other)] = dict(fields)
        docs[f"rondas/{other}"]["pretext"] = "truco"
        db = FakeFirestore(docs)
        second = {
            "kind": "rain",
            "title": "Lluvia el jueves",
            "text": "Hay 80% de lluvia a las 16. Si llueve, el truco se juega bajo techo.",
        }
        model = ScriptedModel(compose(RAIN_BLOCK, HOST_BLOCK) + compose(second))

        counts = run(db, model=model)

        assert counts == {"rondas": 2, "off": 0, "held": 0, "already": 0, "agent": 2, "template": 0}
        first, other_card = card(db), card(db, other)
        assert first["status"] == other_card["status"] == "agent"
        assert first["week"] == other_card["week"] == WEEK
        assert first["messages"] != other_card["messages"]
        for words in texts(first["messages"]) + texts(other_card["messages"]):
            assert gates.check_words(words).allowed, words
        assert first["blocks"] == ["rain", "host"]
        assert other_card["blocks"] == ["rain"]

    def test_the_switch_off_leaves_the_template_and_runs_no_model(self):
        db = FakeFirestore(documents(hosts={"anfitrion": HOST}))
        model = ScriptedModel([])

        counts = run(db, model=model)

        assert counts["off"] == 1
        assert counts["agent"] == 0
        assert model.requests == []
        assert f"rondas/{RONDA}/views/card" not in db.documents

    @pytest.mark.parametrize(
        ("script", "reason"),
        [
            ([ModelUnavailable("down")], "el modelo no respondió"),
            ([turn(content="No hace falta tarjeta.")], "no armó la tarjeta"),
            (compose({**HOST_BLOCK, "text": "Abre tú, {anfitrion}."}), "no quedó ningún aviso"),
            ([RuntimeError("boom")], "falló"),
        ],
    )
    def test_any_failure_stores_the_template_with_its_reason(self, script, reason):
        db = FakeFirestore(on())

        counts = run(db, script=script)

        assert counts["template"] == 1
        assert card(db)["status"] == "template"
        assert card(db)["reason"] == reason
        assert "messages" not in card(db)
        assert notes(db)[-1] == f"Muestra la tarjeta fija: {reason}."

    def test_no_model_keys_store_the_template(self):
        db = FakeFirestore(on())

        counts = weekly_card.run_weekly_card(db, MON_10, send=Sender(), weather=FakeWeather())

        assert counts["template"] == 1
        assert card(db)["reason"] == "no hay modelo (model keys missing)"
        assert db.documents[f"agent_runs/{RUN}"]["status"] == "failed"

    def test_the_trace_shows_the_cards_generation(self):
        db = FakeFirestore(on())

        run(db)

        kinds = [(s["kind"], s.get("tool", s.get("note", ""))) for s in steps(db)]
        assert ("tool", "get_forecast") in kinds
        assert ("tool", "compose_card") in kinds
        assert ("tool", "log_acta") in kinds
        assert kinds[-1] == ("note", "Tarjeta armada por el programa: 2 avisos y ¿Venís?.")
        compose_step = next(s for s in steps(db) if s.get("tool") == "compose_card")
        assert compose_step["status"] == "ok"
        assert compose_step["resultSummary"] == (
            "Armó la tarjeta de la semana con 2 avisos: la lluvia, quién abre."
        )
        run_doc = db.documents[f"agent_runs/{RUN}"]
        assert run_doc["job"] == "weekly_card"
        assert run_doc["status"] == "done"
        assert run_doc["note"] == "Listo: la tarjeta quedó armada."
        assert card(db)["runId"] == RUN
        assert card(db)["model"] == "scripted"
        assert card(db)["latencyMs"] >= 0
        assert card(db)["tokens"] == [{"model": "scripted", "in": 0, "out": 0}]

    def test_the_card_keeps_what_each_model_billed(self):
        db = FakeFirestore(on())
        # Spark Open answers the first turn, then Spark 1.3 takes over (the fallback).
        script = compose(RAIN_BLOCK)
        script[0] = replace(script[0], model="open", tokens_in=900, tokens_out=40)
        script[1] = replace(script[1], model="spark", tokens_in=1100, tokens_out=120)

        run(db, script=script)

        assert card(db)["tokens"] == [
            {"model": "open", "in": 900, "out": 40},
            {"model": "spark", "in": 1100, "out": 120},
            {"model": "scripted", "in": 0, "out": 0},
        ]


class TestTheMessages:
    def test_the_card_is_a_create_surface_and_an_update_components_for_our_catalog(self):
        db = FakeFirestore(on())

        run(db)

        create, update = card(db)["messages"]
        assert create == {
            "version": "v0.9",
            "createSurface": {"surfaceId": f"card-{WEEK}", "catalogId": "uy.ronda.card"},
        }
        assert update["version"] == "v0.9"
        assert update["updateComponents"]["surfaceId"] == f"card-{WEEK}"
        components = update["updateComponents"]["components"]
        assert components[0] == {
            "id": "root",
            "component": "RondaCard",
            "children": ["rain", "host", "rsvp"],
        }
        assert components[1] == {
            "id": "rain",
            "component": "RainNotice",
            "title": "Puede llover",
            "text": "El jueves a las 16 hay 80% de lluvia. Si llueve, nos vemos en el salón.",
        }
        assert components[2]["component"] == "HostOfWeek"
        assert components[-1] == {"id": "rsvp", "component": "Rsvp"}

    def test_code_fills_the_placeholders_so_the_model_never_sees_a_name(self):
        db = FakeFirestore(on())
        model = ScriptedModel(compose(HOST_BLOCK))

        run(db, model=model)

        components = card(db)["messages"][1]["updateComponents"]["components"]
        assert components[1]["text"] == "Esta semana abre Mirta: llega diez minutos antes y saluda."
        task = model.requests[0][0][1]["content"]
        assert "Mirta" not in task
        assert "Anfitrión esta semana: sí." in task
        assert "Se suma alguien nuevo: no." in task


class TestWhoOpens:
    def test_the_weeks_opener_is_who_the_card_names(self):
        db = FakeFirestore(on(opener={"week": WEEK, "uid": "demo-102", "firstName": "Jorge"}))

        run(db, model=ScriptedModel(compose(HOST_BLOCK)))

        assert texts(card(db)["messages"]) == [
            "Quién abre\nEsta semana abre Jorge: llega diez minutos antes y saluda."
        ]

    def test_last_weeks_opener_is_not(self):
        db = FakeFirestore(on(opener={"week": "2026-W44", "uid": "demo-102", "firstName": "Jorge"}))

        run(db, model=ScriptedModel(compose(HOST_BLOCK)))

        assert "abre Mirta" in texts(card(db)["messages"])[0]

    def test_a_handoff_writes_the_new_opener_into_the_card(self):
        db = FakeFirestore(on())
        run(db)

        assert weekly_card.refill_host(db, RONDA, WEEK, "Jorge")

        assert texts(card(db)["messages"]) == [
            "Puede llover\nEl jueves a las 16 hay 80% de lluvia. Si llueve, nos vemos en el salón.",
            "Quién abre\nEsta semana abre Jorge: llega diez minutos antes y saluda.",
        ]
        assert weekly_card.refill_host(db, RONDA, WEEK, "Ana")
        assert "abre Ana" in texts(card(db)["messages"])[1]

    def test_a_card_without_who_opens_is_left_alone(self):
        db = FakeFirestore(on())
        run(db, model=ScriptedModel(compose(RAIN_BLOCK)))
        before = card(db)["messages"]

        assert not weekly_card.refill_host(db, RONDA, WEEK, "Jorge")
        assert not weekly_card.refill_host(db, RONDA, "2026-W46", "Jorge")
        assert not weekly_card.refill_host(db, "otra", WEEK, "Jorge")
        assert card(db)["messages"] == before
        assert "hostWords" not in card(db)


class TestTheBlocks:
    @pytest.mark.parametrize(
        ("block", "why"),
        [
            ({**RAIN_BLOCK, "text": "Llueve: traes paraguas."}, "no está en voseo: «traes»"),
            ({**RAIN_BLOCK, "title": "Lluvia ☔"}, "tiene un emoji (☔)"),
            ({**RAIN_BLOCK, "text": "Poné 100 pesos para el salón."}, "menciona plata («pesos»)"),
            (
                {**RAIN_BLOCK, "text": "Nos vemos en Av. Central 1234."},
                "parece una casa o una dirección: «Av. Central 1234»",
            ),
            ({**RAIN_BLOCK, "text": "---"}, "quedó vacío sin el Markdown"),
            (
                {"kind": "newcomer", "title": "Alguien nuevo", "text": "Se suma {nuevo}."},
                "no se suma nadie nuevo esta semana",
            ),
            (
                {"kind": "despues", "title": "Después", "text": "Hay {despues}."},
                "no hay después esta semana",
            ),
            (
                {"kind": "bench", "title": "Lista de espera", "text": "Avisá si no venís."},
                "no hay nadie en la lista de espera",
            ),
        ],
    )
    def test_a_block_that_fails_a_gate_or_has_no_fact_is_dropped_and_noted(self, block, why):
        db = FakeFirestore(on())

        run(db, script=compose(block, HOST_BLOCK))

        assert card(db)["status"] == "agent"
        assert card(db)["blocks"] == ["host"]
        assert card(db)["dropped"] == 1
        assert f"Bloque {block['kind']} descartado: {why}." in notes(db)
        compose_step = next(s for s in steps(db) if s.get("tool") == "compose_card")
        assert compose_step["resultSummary"].endswith("Descartó 1.")

    def test_a_block_without_a_host_is_dropped(self):
        db = FakeFirestore(documents(agentCard=True))

        run(db, script=compose(RAIN_BLOCK, HOST_BLOCK))

        assert card(db)["blocks"] == ["rain"]
        assert "Bloque host descartado: no hay anfitrión esta semana." in notes(db)

    def test_a_repeated_kind_keeps_the_first_and_markdown_is_stripped(self):
        db = FakeFirestore(on())
        bold = {**RAIN_BLOCK, "title": "# Puede **llover**", "text": "- Nos vemos *igual*."}

        run(db, script=compose(bold, RAIN_BLOCK))

        components = card(db)["messages"][1]["updateComponents"]["components"]
        assert components[1]["title"] == "Puede llover"
        assert components[1]["text"] == "Nos vemos igual."
        assert "Bloque rain descartado: repetido." in notes(db)

    def test_a_newcomer_a_despues_and_a_bench_are_facts_code_fills(self):
        docs = on()
        docs[f"rondas/{RONDA}/members/demo-104"]["joinedAt"] = at(1, 12)
        docs[f"rondas/{RONDA}/despues/{WEEK}"] = {
            "status": "set",
            "kind": "home",
            "what": "bizcochos",
            "homeName": "Mirta",
            "address": "Av. Central 1234",
        }
        docs[f"rondas/{RONDA}/bench/{WEEK}"] = {"offers": [{"offerId": "o1", "status": "pending"}]}
        db = FakeFirestore(docs)
        blocks = [
            {"kind": "newcomer", "title": "Alguien nuevo", "text": "Esta semana se suma {nuevo}."},
            {"kind": "despues", "title": "Después", "text": "Si querés, {despues} (20 min)."},
            {
                "kind": "bench",
                "title": "Lista de espera",
                "text": "Si no venís, avisá: hay alguien esperando.",
            },
        ]
        model = ScriptedModel(compose(*blocks))

        run(db, model=model)

        components = card(db)["messages"][1]["updateComponents"]["components"]
        assert [c["text"] for c in components[1:-1]] == [
            "Esta semana se suma Facu.",
            "Si querés, bizcochos en lo de Mirta (20 min).",
            "Si no venís, avisá: hay alguien esperando.",
        ]
        assert "1234" not in str(card(db)["messages"])
        task = model.requests[0][0][1]["content"]
        assert "Se suma alguien nuevo: sí." in task
        assert "Hay después: sí." in task
        assert "Alguien en la lista de espera: sí." in task
        assert "Facu" not in task and "Mirta" not in task

    def test_a_despues_in_a_public_place_reads_what_and_where(self):
        docs = on()
        docs[f"rondas/{RONDA}/despues/{WEEK}"] = {
            "status": "set",
            "kind": "place",
            "what": "bizcochos",
            "where": "la Plaza",
        }
        db = FakeFirestore(docs)
        block = {"kind": "despues", "title": "Después", "text": "Si querés, {despues}."}

        run(db, script=compose(block))

        components = card(db)["messages"][1]["updateComponents"]["components"]
        assert components[1]["text"] == "Si querés, bizcochos en la Plaza."

    def test_a_despues_without_a_place_or_a_home_is_no_despues(self):
        docs = on()
        docs[f"rondas/{RONDA}/despues/{WEEK}"] = {"status": "set", "kind": "none", "what": "x"}
        db = FakeFirestore(docs)
        model = ScriptedModel(compose(HOST_BLOCK))

        run(db, model=model)

        assert "Hay después: no." in model.requests[0][0][1]["content"]

    def test_composing_twice_is_refused(self):
        db = FakeFirestore(on())
        script = [
            turn(call("compose_card", blocks=[RAIN_BLOCK], reason="armar")),
            turn(call("compose_card", blocks=[HOST_BLOCK], reason="otra vez")),
            turn(content="Listo."),
        ]

        run(db, script=script)

        assert card(db)["blocks"] == ["rain"]
        second = [s for s in steps(db) if s.get("tool") == "compose_card"][1]
        assert second["status"] == "refused"
        assert second["resultSummary"] == "Ya armó la tarjeta de esta semana."

    def test_a_call_that_does_not_fit_the_catalog_is_invalid(self):
        db = FakeFirestore(on())
        script = [
            turn(
                call(
                    "compose_card", blocks=[{"kind": "map", "title": "x", "text": "y"}], reason="a"
                )
            ),
            turn(call("compose_card", blocks=[RAIN_BLOCK], reason="armar")),
            turn(content="Listo."),
        ]

        run(db, script=script)

        first = next(s for s in steps(db) if s.get("tool") == "compose_card")
        assert first["status"] == "invalid"
        assert "blocks.0.kind" in first["resultSummary"]
        assert card(db)["blocks"] == ["rain"]


class TestTheJob:
    def test_runs_once_a_week_and_again_only_when_forced(self):
        db = FakeFirestore(on())

        first = run(db)
        again = run(db, MON_10 + timedelta(hours=1))
        forced = run(db, MON_10 + timedelta(hours=2), force=True)

        assert first["agent"] == 1
        assert again == {"rondas": 1, "off": 0, "held": 0, "already": 1, "agent": 0, "template": 0}
        assert forced["agent"] == 1
        assert f"agent_runs/{RUN}_20261102T1200" in db.documents

    def test_a_failed_run_may_be_claimed_again(self):
        db = FakeFirestore(on())
        run(db, script=[RuntimeError("boom")])

        counts = run(db, MON_10 + timedelta(hours=1))

        assert counts["agent"] == 1
        assert card(db)["status"] == "agent"

    def test_holds_at_night_even_when_forced(self):
        db = FakeFirestore(on())

        counts = run(db, MON_22, force=True)

        assert counts["held"] == 1
        assert f"rondas/{RONDA}/views/card" not in db.documents

    def test_waits_until_three_days_before_the_meeting(self):
        db = FakeFirestore(on())

        early = run(db, at(1, 10))
        forced = run(db, at(1, 10), force=True)

        assert early["agent"] == 0
        assert forced["agent"] == 1

    def test_skips_rondas_that_no_longer_meet(self):
        db = FakeFirestore(on(status="ended"))

        counts = run(db)

        assert counts == {"rondas": 0, "off": 0, "held": 0, "already": 0, "agent": 0, "template": 0}

    def test_runs_by_name_from_the_registry(self):
        db = FakeFirestore(on())

        counts = jobs.run("weekly_card", db, MON_10, jobs.Context(send=Sender()))

        assert counts["template"] == 1
        assert card(db)["reason"] == "no hay modelo (model keys missing)"

    def test_a_fallback_host_is_no_host_for_the_card(self):
        db = FakeFirestore(documents(agentCard=True, hosts={"anfitrion": "demo-999"}))
        model = ScriptedModel(compose(HOST_BLOCK))

        run(db, model=model)

        assert card(db)["status"] == "template"
        assert "Anfitrión esta semana: no." in model.requests[0][0][1]["content"]

    def test_a_dry_forecast_still_composes_what_the_model_sends(self):
        db = FakeFirestore(on())

        run(db, script=compose(HOST_BLOCK), weather=FakeWeather(DRY))

        assert card(db)["blocks"] == ["host"]
