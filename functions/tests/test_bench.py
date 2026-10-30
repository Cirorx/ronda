"""The bench (bench.py) over the Firestore stand-in: who is on it, the model's decision and code's
default, the offer through the gates, the answers, expiry, the host's summary, and the trace's
labels. The ronda is `organiser_fakes`' Thursday mate at 16:00, where Ana (demo-103) said "esta
no"; everyone is invented."""

from datetime import UTC, datetime, timedelta

import pytest

import attendance
import bench
import jobs
import rsvp
from organiser import model as organiser_model
from organiser.model import ModelUnavailable
from tests.fake_firestore import FakeFirestore
from tests.organiser_fakes import (
    DRY,
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

APP = "https://example.test/app/ronda"
SEAT = "el-pinar-sur_mate_thu-afternoon"
HOSTS = {"anfitrion": "demo-101", "cola": "demo-102", "anfitrionName": "Mirta", "colaName": "Jorge"}
WED_10 = at(4, 10)
RUN = f"agent_runs/{RONDA}_{WEEK}_bench"
BENCH = f"rondas/{RONDA}/bench/{WEEK}"


def waiting(uid, name, *, barrio="el-pinar-sur", slots=("thu-afternoon",), seats=(SEAT,), day=21):
    """A sign-up waiting for a ronda: their profile, eligible seats and one Android phone."""
    profile = {
        "firstName": name,
        "ageBand": "30-39",
        "barrio": barrio,
        "pretexts": ["mate"],
        "slots": list(slots),
        "brings": ["bizcochos"],
    }
    if day:
        profile["createdAt"] = datetime(2026, 10, day, 12, 0, tzinfo=UTC)
    return {
        f"users/{uid}": profile,
        f"users/{uid}/private/eligible": {"seatIds": list(seats)},
        f"users/{uid}/tokens/tok-{uid}": {"platform": "android"},
    }


def bench_db(**ronda_fields) -> FakeFirestore:
    """The Thursday ronda with its hosts, and a bench: Eva (waiting since 21/10, same barrio),
    Nico (22/10, El Pinar Norte, nine blocks) and Pablo (no date); and people who are not on
    it: Rosa (the seat fails her needs filter), Leo (Lagomar, too far), Juan (Saturdays), a
    sign-up without a profile, and Sofi (sits in another ronda)."""
    docs = documents(hosts=HOSTS, **ronda_fields)
    docs |= waiting("demo-201", "Eva")
    docs |= waiting("demo-202", "Nico", barrio="el-pinar-norte", day=22)
    docs |= waiting("demo-208", "Pablo", day=0)
    docs |= waiting("demo-203", "Rosa", seats=("el-pinar-sur_mate_sat-afternoon",), day=1)
    docs |= waiting("demo-204", "Leo", barrio="lagomar-sur", day=1)
    docs |= waiting("demo-205", "Juan", slots=("sat-afternoon",), day=1)
    docs["users/demo-206"] = {"terms": {"version": "1"}}
    docs |= waiting("demo-207", "Sofi", day=1)
    docs["rondas/ronda-other"] = {"status": "active", "slot": {"day": "mon", "time": "morning"}}
    docs["rondas/ronda-other/members/demo-207"] = {"state": "active", "brings": []}
    docs["rondas/ronda-other/members/demo-202"] = {"state": "left", "brings": []}
    docs["rondas/ronda-ended"] = {"status": "ended", "slot": {"day": "mon", "time": "morning"}}
    docs["rondas/ronda-ended/members/demo-201"] = {"state": "active", "brings": []}
    return FakeFirestore(docs)


R = "porque sí"


def offers(deadline="2026-11-04T17:00", *, then=()):
    """The model reads the forecast and the last bus, then offers with `deadline`; `then` adds
    more calls before its last words."""
    day = THURSDAY.isoformat()
    return [
        turn(
            call("get_forecast", date=day, reason="ver si llueve"),
            call("get_last_bus", date=day, reason="ver cómo vuelve"),
        ),
        turn(call("offer_bench_seat", deadline=deadline, reason="faltan 30 horas, no llueve")),
        *[turn(extra) for extra in then],
        turn(content="**Listo**, ofrecido."),
    ]


def run(db, now=WED_10, *, script=(), sender=None, **options) -> dict:
    return bench.run_bench(
        db,
        now,
        send=sender or Sender(),
        app_url=APP,
        model=options.pop("model", None) or ScriptedModel(list(script)),
        weather=FakeWeather(DRY),
        **options,
    )


def offer_docs(db) -> dict[str, dict]:
    return {
        path: doc
        for path, doc in db.documents.items()
        if "/offers/" in path and path.startswith("users/")
    }


def steps(db) -> list[dict]:
    prefix = f"{RUN}/steps/"
    return [db.documents[p] for p in sorted(db.documents) if p.startswith(prefix)]


def notes(db) -> list[str]:
    return [s["note"] for s in steps(db) if s["kind"] == "note"]


def acta(db) -> list[str]:
    prefix = f"acta/{RONDA}/entries/"
    return [db.documents[p]["summary"] for p in sorted(db.documents) if p.startswith(prefix)]


WED_11 = at(4, 11)


def answer(db, uid, take, now=WED_11, n=1):
    return bench.answer(db, uid, f"{RONDA}_{WEEK}_{n:02d}", take, now)


class TestTime:
    def test_the_meeting_starts_at_its_hour_or_its_bands_start(self):
        ronda = documents()[f"rondas/{RONDA}"]
        assert bench.meeting_start(ronda, THURSDAY) == at(5, 16)
        ronda["slot"] = {"day": "thu", "time": "evening"}
        assert bench.meeting_start(ronda, THURSDAY) == at(5, 19)
        ronda["slot"] = {"day": "thu", "time": "unknown"}
        assert bench.meeting_start(ronda, THURSDAY) == at(5, 14)

    def test_deadlines_fall_on_the_hour_inside_the_day_and_before_the_meeting(self):
        window = bench.deadline_window(at(4, 10, 30), at(5, 16))

        assert window[0] == at(4, 12)
        assert window[-1] == at(5, 15)
        assert at(4, 21) not in window
        assert at(5, 8) not in window
        assert at(5, 9) in window
        assert bench.deadline_window(at(4, 10), at(5, 16))[0] == at(4, 11)

    def test_it_is_too_late_less_than_two_hours_before(self):
        assert bench.deadline_window(at(5, 14, 1), at(5, 16)) == []

    def test_the_default_gives_three_hours_or_the_last_allowed(self):
        assert bench.default_deadline(bench.deadline_window(WED_10, at(5, 16)), WED_10) == at(4, 13)
        late = bench.deadline_window(at(5, 12), at(5, 16))
        assert bench.default_deadline(late, at(5, 12)) == at(5, 15)

    def test_days_and_deadlines_read_as_spoken(self):
        assert bench.spoken_day(THURSDAY, THURSDAY) == "hoy"
        assert bench.spoken_day(THURSDAY, THURSDAY - timedelta(days=1)) == "mañana"
        assert bench.spoken_day(THURSDAY, THURSDAY - timedelta(days=3)) == "el jueves 5/11"
        assert bench.spoken_deadline(at(4, 17), WED_10) == "las 17:00"
        assert bench.spoken_deadline(at(5, 12), WED_10) == "mañana a las 12:00"
        assert bench.spoken_deadline(at(5, 12), at(2, 10)) == "el jueves 5/11 a las 12:00"


class TestTheBench:
    def test_orders_who_waited_longest_then_the_nearest_and_filters_the_rest(self):
        db = bench_db()
        ronda = db.documents[f"rondas/{RONDA}"]

        queue = bench.bench_order(db, ronda, THURSDAY, set())

        assert [c.first_name for c in queue] == ["Eva", "Nico", "Pablo"]
        assert queue[0].brings == ("bizcochos",)
        assert round(queue[1].blocks) == 9
        assert bench.bench_order(db, ronda, THURSDAY, {"demo-201"})[0].first_name == "Nico"

    def test_leaves_out_who_holds_an_offer_or_took_a_seat_that_day(self):
        db = bench_db()
        db.documents["users/demo-201/offers/x"] = {"status": "pending"}
        db.documents["users/demo-202/offers/y"] = {"status": "taken", "date": "2026-11-05"}
        db.documents["users/demo-208/offers/z"] = {"status": "taken", "date": "2026-10-29"}
        ronda = db.documents[f"rondas/{RONDA}"]

        assert [c.first_name for c in bench.bench_order(db, ronda, THURSDAY, set())] == ["Pablo"]

    def test_a_ronda_in_an_unknown_barrio_has_no_bench(self):
        assert bench.bench_order(bench_db(), {"barrio": "atlantida"}, THURSDAY, set()) == []

    def test_the_seat_id_is_the_rondas_or_its_key(self):
        assert bench.seat_id({"seatId": "a_b_c"}) == "a_b_c"
        ronda = {
            "barrio": "el-pinar-sur",
            "pretext": "mate",
            "slot": {"day": "thu", "time": "afternoon"},
        }
        assert bench.seat_id(ronda) == SEAT

    def test_on_the_real_project_invented_sign_ups_are_never_on_it(self, monkeypatch):
        monkeypatch.setenv("GCLOUD_PROJECT", "ronda-uy")
        db = bench_db()
        db.documents |= waiting("u-301", "Marta")
        ronda = db.documents[f"rondas/{RONDA}"]

        assert [c.uid for c in bench.bench_order(db, ronda, THURSDAY, set())] == ["u-301"]

    def test_counts_every_no_and_every_pause_as_a_freed_seat(self):
        members = {
            "a": {"state": "active"},
            "b": {"state": "paused", "pausedUntil": "2026-11-12"},
            "c": {"state": "left"},
            "d": {"state": "active"},
        }
        answers = {"a": "no", "c": "no", "d": "yes"}
        assert bench.freed_seats(members, answers, THURSDAY) == 2


class TestTheModelsOffer:
    def test_offers_the_seat_to_the_first_on_the_bench_with_the_models_deadline(self):
        db, sender = bench_db(), Sender()

        counts = run(db, script=offers(), sender=sender)

        assert counts["offered"] == 1 and counts["rondas"] == 2
        offer = db.documents[f"users/demo-201/offers/{RONDA}_{WEEK}_01"]
        assert offer | {"createdAt": None} == {
            "rondaId": RONDA,
            "week": WEEK,
            "date": "2026-11-05",
            "pretext": "mate",
            "slot": {"day": "thu", "time": "afternoon"},
            "hour": "16:00",
            "placeName": "frente al quiosco",
            "placeLandmark": None,
            "deadline": at(4, 17),
            "status": "pending",
            "createdAt": None,
        }
        [message] = sender.messages
        assert message["token"] == "tok-demo-201"
        assert message["data"]["type"] == "benchOffer"
        assert message["data"]["offerId"] == f"{RONDA}_{WEEK}_01"
        assert message["data"]["title"] == "Se liberó un lugar para mañana"
        assert message["data"]["body"] == (
            "Hola, Eva. Soy un programa. Ronda me usa para avisar horarios, lugares y lluvia. "
            "Las decisiones las toman ustedes. Nunca escribo de noche. Jueves 16:00 · mate en la "
            "rambla · frente al quiosco. Estabas en la lista de espera. ¿Lo tomás? Tenés hasta "
            "las 17:00."
        )

    def test_the_trace_says_which_steps_are_codes_and_which_the_models(self):
        db = bench_db()

        run(db, script=offers())

        labelled = [(s["kind"], s["by"]) for s in steps(db)]
        assert labelled == [
            ("note", "code"),
            ("model", "model"),
            ("tool", "model"),
            ("tool", "model"),
            ("model", "model"),
            ("tool", "model"),
            ("model", "model"),
            ("message", "code"),
        ]
        assert notes(db)[0] == (
            "Lugar libre para el jueves. En la lista de espera hay 3 personas para este lugar: "
            "mismo día y actividad, a menos de diez cuadras, y el lugar pasa el filtro de lo que "
            "le complica ir a cada una. Le toca a Eva, que espera desde el 21/10."
        )
        run_doc = db.documents[RUN]
        assert run_doc["job"] == "bench" and run_doc["status"] == "done"
        assert run_doc["model"] == "scripted"
        assert acta(db)[-1] == (
            "Ofreció el lugar libre del jueves a alguien de la lista de espera, con plazo hasta "
            "las 17:00."
        )
        assert db.documents[BENCH]["offers"] == [
            {
                "offerId": f"{RONDA}_{WEEK}_01",
                "uid": "demo-201",
                "firstName": "Eva",
                "status": "pending",
            }
        ]
        assert db.documents[BENCH]["lockedUntil"] is None

    def test_the_model_learns_counts_and_times_never_a_name(self):
        db, model = bench_db(), ScriptedModel(offers())

        run(db, model=model)

        task = model.requests[0][0][1]["content"]
        assert "Eva" not in task and "Ana" not in task
        assert "faltan 30 horas" in task
        assert "Lugares liberados por «esta no»: 1." in task
        assert "Personas en la lista de espera que pueden tomar este lugar: 3." in task
        assert "de 2026-11-04T11:00 a 2026-11-05T15:00" in task
        assert "Ronda usa 2026-11-04T13:00" in task
        assert [t["function"]["name"] for t in model.requests[0][1]] == list(bench.BENCH_TOOLS)

    def test_a_deadline_outside_the_window_is_refused_and_the_model_tries_again(self):
        db, model = (
            bench_db(),
            ScriptedModel(
                [
                    turn(call("offer_bench_seat", deadline="2026-11-04T22:00", reason=R)),
                    *offers("2026-11-04T18:00")[1:],
                ]
            ),
        )

        run(db, model=model)

        refused = [s for s in steps(db) if s["kind"] == "tool" and s["status"] == "refused"]
        assert "no es un plazo permitido" in refused[0]["resultSummary"]
        assert db.documents[f"users/demo-201/offers/{RONDA}_{WEEK}_01"]["deadline"] == at(4, 18)

    def test_only_one_decision_per_seat(self):
        db = bench_db()
        script = [
            turn(call("offer_bench_seat", deadline="2026-11-04T17:00", reason=R)),
            turn(
                call("skip_offer", reason=R),
                call("offer_bench_seat", deadline="2026-11-04T18:00", reason=R),
            ),
            turn(content="Listo."),
        ]

        run(db, script=script)

        refused = [s["resultSummary"] for s in steps(db) if s.get("status") == "refused"]
        assert refused == ["Ya decidió qué hacer con este lugar."] * 2
        assert db.documents[f"users/demo-201/offers/{RONDA}_{WEEK}_01"]["deadline"] == at(4, 17)

    def test_a_skip_leaves_the_seat_unoffered_this_week(self):
        db, sender = bench_db(), Sender()

        counts = run(
            db,
            script=[
                turn(call("skip_offer", reason="llueve y no hay ómnibus")),
                turn(content="No."),
            ],
            sender=sender,
        )

        assert counts["skipped"] == 1 and counts["offered"] == 0
        assert offer_docs(db) == {}
        assert db.documents[BENCH]["skipped"] == 1
        assert "El lugar queda sin ofrecer esta semana: a Eva no le llega nada." in notes(db)
        assert acta(db) == [
            "Decidió no ofrecer el lugar libre del jueves esta semana.",
            "Le contó a Mirta cómo va el banco del jueves.",
        ]
        # Settled: nobody chose a time for the host, so code tells them now.
        assert sender.messages[0]["token"] == "tok-demo-101"

        assert run(db, at(4, 12), script=[]) == dict.fromkeys(bench.COUNTS, 0) | {"rondas": 2}


class TestCodesDefault:
    @pytest.mark.parametrize(
        ("script", "why"),
        [
            ([ModelUnavailable("down")], "El modelo no respondió a tiempo"),
            ([turn(content="No sé.")], "El modelo terminó sin decidir"),
            (
                [turn(call("nope", reason=R)), turn(call("nope", reason=R))],
                "La llamada del modelo vino mal dos veces",
            ),
            (
                [turn(call("count_rsvps", reason=R))] * bench.MAX_STEPS,
                "El modelo llegó al tope de pasos sin decidir",
            ),
        ],
    )
    def test_sends_with_the_default_deadline_and_says_why(self, script, why):
        db = bench_db()

        counts = run(db, script=script)

        assert counts["offered"] == 1
        assert db.documents[f"users/demo-201/offers/{RONDA}_{WEEK}_01"]["deadline"] == at(4, 13)
        assert (
            f"{why}: Ronda hace lo de siempre y ofrece el lugar con plazo hasta las 13:00."
            in notes(db)
        )

    def test_without_a_model_it_still_offers(self, monkeypatch):
        monkeypatch.delenv("BASETEN_API_KEY", raising=False)
        db = bench_db()

        counts = bench.run_bench(db, WED_10, send=Sender(), weather=FakeWeather(DRY))

        assert counts["offered"] == 1
        assert notes(db)[1] == (
            "No hay modelo (model keys missing): Ronda hace lo de siempre y ofrece el lugar con "
            "plazo hasta las 13:00."
        )

    def test_the_benchs_model_gives_up_sooner(self, monkeypatch):
        asked = []

        def from_environment(**limits):
            asked.append(limits)
            raise ModelUnavailable("model keys missing")

        monkeypatch.setattr(bench, "from_environment", from_environment)

        bench.run_bench(bench_db(), WED_10, send=Sender(), weather=FakeWeather(DRY))

        assert asked == [{"timeout": bench.MODEL_TIMEOUT}]

    def test_the_model_client_takes_its_limits(self, monkeypatch):
        import openai

        monkeypatch.setenv("BASETEN_API_KEY", "test-baseten")
        monkeypatch.setenv("MODEL_API_KEY", "test-meta")
        built = []
        monkeypatch.setattr(openai, "OpenAI", lambda **options: built.append(options))

        organiser_model.from_environment(timeout=bench.MODEL_TIMEOUT, max_retries=0)

        assert [(b["timeout"], b["max_retries"]) for b in built] == [(20, 0), (20, 0)]


class TestAnswers:
    def offered(self, **options):
        db = bench_db(**options)
        run(db, script=offers())
        return db

    def test_lo_tomo_makes_a_guest_who_shows_as_going_and_on_the_roll(self):
        db = self.offered()

        result = answer(db, "demo-201", True)

        assert result == {
            "status": "taken",
            "rondaId": RONDA,
            "week": WEEK,
            "date": "2026-11-05",
            "hour": "16:00",
        }
        offer = db.documents[f"users/demo-201/offers/{RONDA}_{WEEK}_01"]
        assert offer["status"] == "taken" and offer["answeredAt"] == at(4, 11)
        week = db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]
        assert week["guests"]["demo-201"]["firstName"] == "Eva"
        assert "demo-201" not in week["rsvp"]
        view = db.documents[f"rondas/{RONDA}/views/week"]
        assert [(p["firstName"], p.get("guest", False)) for p in view["going"]] == [
            ("Eva", True),
            ("Jorge", False),
            ("Mirta", False),
        ]
        assert view["noCount"] == 1
        names = [p["firstName"] for p in attendance.people(db, RONDA, THURSDAY, week["guests"])]
        assert names == ["Ana", "Eva", "Facu", "Jorge", "Mirta"]

    def test_the_next_run_records_the_answer_and_tells_the_host(self):
        db, sender = self.offered(), Sender()
        answer(db, "demo-201", True)

        counts = run(db, at(4, 11, 5), sender=sender)

        assert counts["summaries"] == 1
        answers = [s for s in steps(db) if s["kind"] == "answer"]
        assert answers == [answers[0] | {"resultSummary": "Eva tomó el lugar.", "by": "person"}]
        [message] = sender.messages
        assert message["token"] == "tok-demo-101"
        assert message["data"]["title"] == "Lugares libres del jueves"
        assert message["data"]["body"].endswith(
            "Para mañana se liberó un lugar. Eva viene de la lista de espera."
        )
        assert "El modelo no eligió cuándo avisarle a quien abre" in notes(db)[-1]
        assert acta(db)[-1] == "Le contó a Mirta cómo va el banco del jueves."
        assert run(db, at(4, 12), sender=sender)["summaries"] == 0

    def test_answering_again_the_same_changes_nothing(self):
        db = self.offered()
        answer(db, "demo-201", True)

        assert answer(db, "demo-201", True, at(4, 12))["status"] == "taken"
        assert db.documents[f"users/demo-201/offers/{RONDA}_{WEEK}_01"]["answeredAt"] == at(4, 11)

    def test_esta_vez_no_moves_to_the_next_person_with_nothing_against_anyone(self):
        db, sender = self.offered(), Sender()

        answer(db, "demo-201", False)
        run(db, at(4, 11, 5), script=offers("2026-11-04T19:00"), sender=sender)

        assert db.documents[f"users/demo-201/offers/{RONDA}_{WEEK}_01"]["status"] == "declined"
        nico = db.documents[f"users/demo-202/offers/{RONDA}_{WEEK}_02"]
        assert nico["status"] == "pending" and nico["deadline"] == at(4, 19)
        assert sender.messages[0]["token"] == "tok-demo-202"
        assert [s["resultSummary"] for s in steps(db) if s["kind"] == "answer"] == [
            "Eva contestó «Esta vez no». Nada cambia para esa persona: sigue en la lista de espera."
        ]
        assert set(db.documents["users/demo-201"]) == {
            "firstName",
            "ageBand",
            "barrio",
            "pretexts",
            "slots",
            "brings",
            "createdAt",
        }

    def test_refuses_what_it_cannot_record(self):
        db = self.offered()
        offer_id = f"{RONDA}_{WEEK}_01"
        cases = [
            ("demo-201", None, True, at(4, 11), "invalid-argument"),
            ("demo-201", "a/b", True, at(4, 11), "invalid-argument"),
            ("demo-201", offer_id, "yes", at(4, 11), "invalid-argument"),
            ("demo-202", offer_id, True, at(4, 11), "not-found"),
            ("demo-201", offer_id, True, at(4, 17), "failed-precondition"),
        ]
        for uid, offer, take, now, code in cases:
            with pytest.raises(bench.BenchError) as excinfo:
                bench.answer(db, uid, offer, take, now)
            assert excinfo.value.code == code
        answer(db, "demo-201", False)
        with pytest.raises(bench.BenchError):
            answer(db, "demo-201", True)

    def test_an_offer_closed_while_answering_is_refused(self, monkeypatch):
        db = self.offered()
        real = rsvp._in_transaction

        def closed_first(db_, function):
            db.documents[f"users/demo-201/offers/{RONDA}_{WEEK}_01"]["status"] = "expired"
            return real(db_, function)

        monkeypatch.setattr(rsvp, "_in_transaction", closed_first)
        with pytest.raises(bench.BenchError):
            answer(db, "demo-201", True)


class TestCodesRules:
    def test_an_offer_expires_at_its_deadline_and_the_next_person_gets_it(self):
        db = bench_db()
        run(db, script=offers())

        counts = run(db, at(4, 17), script=offers("2026-11-04T20:00"))

        assert counts["expired"] == 1 and counts["offered"] == 1
        assert db.documents[f"users/demo-201/offers/{RONDA}_{WEEK}_01"]["status"] == "expired"
        assert db.documents[f"users/demo-202/offers/{RONDA}_{WEEK}_02"]["status"] == "pending"
        assert notes(db)[1] == (
            "Venció el plazo de Eva sin respuesta: el lugar pasa a la persona que sigue. Nada "
            "cambia para quien no contestó."
        )

    def test_an_answer_that_beats_the_expiry_stands(self, monkeypatch):
        db = bench_db()
        run(db, script=offers())
        real = rsvp._in_transaction
        path = f"users/demo-201/offers/{RONDA}_{WEEK}_01"

        def answered_first(db_, function):
            if db.documents[path]["status"] == "pending" and db.documents[BENCH]["lockedUntil"]:
                db.documents[path]["status"] = "taken"
            return real(db_, function)

        monkeypatch.setattr(rsvp, "_in_transaction", answered_first)
        counts = run(db, at(4, 17), script=[])

        assert counts["expired"] == 0
        assert db.documents[path]["status"] == "taken"

    def test_one_offer_per_freed_seat(self):
        db = bench_db()
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"]["demo-104"] = "no"

        counts = run(db, script=offers() + offers("2026-11-04T18:00"))

        assert counts["offered"] == 2
        assert {p.split("/")[1] for p in offer_docs(db)} == {"demo-201", "demo-202"}
        assert run(db, at(4, 11), script=[])["offered"] == 0

    def test_a_member_who_comes_after_all_takes_back_the_pending_offer(self):
        db = bench_db()
        run(db, script=offers())
        rsvp.answer(db, "demo-103", RONDA, "yes", at(4, 10, 30))

        counts = run(db, at(4, 10, 35))

        assert counts["withdrawn"] == 1
        assert db.documents[f"users/demo-201/offers/{RONDA}_{WEEK}_01"]["status"] == "withdrawn"
        assert "volvió a decir «voy»" in notes(db)[-1]

    def test_nothing_goes_out_at_night(self):
        db, sender = bench_db(), Sender()

        counts = run(db, at(4, 22), sender=sender)

        assert counts["offered"] == 0 and sender.messages == []
        assert steps(db) == []

    def test_it_stops_offering_when_the_meeting_is_too_close(self):
        db, sender = bench_db(), Sender()

        run(db, at(5, 14, 30), sender=sender)
        run(db, at(5, 14, 45), sender=sender)

        assert notes(db) == [
            "La reunión está demasiado cerca: ya no da el tiempo para ofrecer el lugar."
        ]
        assert offer_docs(db) == {}
        assert sender.messages == []  # nothing was offered: nothing to tell the host

    def test_once_the_meeting_began_the_bench_is_over(self):
        db = bench_db()
        assert run(db, at(5, 16, 30)) == dict.fromkeys(bench.COUNTS, 0) | {"rondas": 2}
        assert BENCH not in db.documents

    def test_an_empty_bench_tells_the_host_by_default(self):
        db, sender = bench_db(), Sender()
        run(db, script=offers())
        answer(db, "demo-201", False)
        run(db, at(4, 11, 5), script=offers("2026-11-04T18:00"))
        answer(db, "demo-202", False, at(4, 12), n=2)
        run(db, at(4, 12, 5), script=offers("2026-11-04T18:00"))
        answer(db, "demo-208", False, at(4, 13), n=3)

        run(db, at(4, 13, 5), sender=sender)

        assert "No queda nadie en la lista de espera para este lugar." in notes(db)
        [message] = sender.messages
        assert message["data"]["body"].endswith(
            "Para mañana se liberó un lugar. Queda un lugar libre."
        )

    def test_a_held_offer_leaves_nothing_and_the_person_first_in_line(self):
        db = bench_db()
        db.documents["users/demo-201"]["firstName"] = "Eva 🧉"

        counts = run(db, script=offers())

        assert counts["offered"] == 0 and offer_docs(db) == {}
        [held] = [s for s in steps(db) if s["kind"] == "message"]
        assert held["outcome"] == "held" and held["gateName"] == "emoji"

    def test_a_failed_send_takes_the_offer_back_and_the_run_says_it_failed(self):
        db = bench_db()

        counts = run(db, script=offers(), sender=Sender(error=RuntimeError("fcm")))

        assert counts["failed"] == 1
        assert offer_docs(db) == {}
        assert db.documents[BENCH]["offers"] == []
        assert db.documents[BENCH]["lockedUntil"] is None
        assert db.documents[RUN]["status"] == "failed"
        assert steps(db)[-1]["why"] == "falló (RuntimeError)"

    def test_a_run_finds_another_holding_the_bench_and_leaves_it(self):
        db = bench_db()
        db.documents[BENCH] = {"lockedUntil": WED_10 + timedelta(minutes=2)}

        assert run(db)["busy"] == 1
        assert run(db, WED_10 + timedelta(minutes=6), script=offers())["offered"] == 1

    def test_a_ronda_with_no_seat_free_costs_nothing(self):
        db = bench_db()
        db.documents[f"rondas/{RONDA}/weeks/{WEEK}"]["rsvp"]["demo-103"] = "yes"

        assert run(db)["offered"] == 0
        assert BENCH not in db.documents

    def test_runs_one_ronda_or_every_open_one(self):
        db = bench_db()
        db.documents["rondas/ronda-gone"] = {"status": "ended"}

        assert run(db, ronda_id="ronda-missing")["rondas"] == 0
        assert run(db, ronda_id="ronda-gone")["rondas"] == 0
        assert run(db, ronda_id=RONDA, script=offers())["offered"] == 1

    def test_the_dispatcher_runs_it(self):
        assert "bench" in jobs.JOBS


class TestTheHostsSummary:
    def test_the_model_tells_the_host_now(self):
        db, sender = bench_db(), Sender()

        run(db, script=offers(then=[call("tell_host", at="", reason="que sepa")]), sender=sender)

        assert [m["token"] for m in sender.messages] == ["tok-demo-201", "tok-demo-101"]
        assert sender.messages[1]["data"]["body"].endswith(
            "Para mañana se liberó un lugar. Se lo estamos ofreciendo a alguien más de la lista."
        )
        assert db.documents[BENCH]["summary"]["by"] == "model"

    def test_the_model_sets_a_time_and_code_sends_it_then(self):
        db = bench_db()
        run(db, script=offers(then=[call("tell_host", at="2026-11-05T10:00", reason="mañana")]))
        answer(db, "demo-201", True)

        early, late = Sender(), Sender()
        run(db, at(4, 12), sender=early)
        run(db, at(5, 10), sender=late)

        assert early.messages == []
        assert late.messages[0]["data"]["body"].endswith("Eva viene de la lista de espera.")
        assert late.messages[0]["data"]["title"] == "Lugares libres del jueves"

    def test_refuses_a_bad_time_and_a_second_choice(self):
        db = bench_db()
        script = offers(
            then=[
                call("tell_host", at="2026-11-05T16:00", reason=R),
                call("tell_host", at="2026-11-04T09:00", reason=R),
                call("tell_host", at="2026-13-45T10:00", reason=R),
                call("tell_host", at="2026-11-04T15:00", reason=R),
                call("tell_host", at="", reason=R),
            ]
        )

        run(db, script=script)

        refused = [s["resultSummary"] for s in steps(db) if s.get("status") == "refused"]
        assert refused[0].startswith('2026-11-05T16:00 no sirve: "" para ahora')
        assert refused[1].startswith("2026-11-04T09:00 no sirve")
        assert refused[2].startswith("2026-13-45T10:00 no sirve")
        assert refused[3] == "Ya está decidido cuándo se le avisa esta semana."
        assert db.documents[BENCH]["summary"]["at"] == at(4, 15)

    def test_a_ronda_without_hosts_tells_nobody(self):
        db, sender = bench_db(), Sender()
        db.documents[f"rondas/{RONDA}"].pop("hosts")

        run(db, script=offers(then=[call("tell_host", at="", reason=R)]), sender=sender)

        assert "La ronda no tiene quien abra ni quien cierre." in [
            s["resultSummary"] for s in steps(db) if s.get("status") == "refused"
        ]
        answer(db, "demo-201", True)
        run(db, at(4, 12), sender=sender)
        assert "el resumen no va a nadie" in notes(db)[-1]
        assert [m["token"] for m in sender.messages] == ["tok-demo-201"]

    def test_the_cola_hears_it_when_the_anfitrion_is_paused(self):
        db, sender = bench_db(), Sender()
        db.documents[f"rondas/{RONDA}/members/demo-101"] |= {
            "state": "paused",
            "pausedUntil": "2026-11-12",
        }

        run(db, script=offers(then=[call("tell_host", at="", reason=R)]), sender=sender)

        assert "tok-demo-102" in sender.tokens

    def test_the_summary_counts_without_naming_who_said_no(self):
        title, body = bench.summary_message(THURSDAY, THURSDAY, 3, ["Eva", "Nico"], 0, 1)
        assert title == "Lugares libres del jueves"
        assert body == (
            "Para hoy se liberaron 3 lugares. Eva y Nico vienen de la lista de espera. Queda un "
            "lugar libre."
        )
        assert bench.summary_message(THURSDAY, THURSDAY, 3, [], 0, 2)[1].endswith(
            "Quedan 2 lugares libres."
        )


class TestTheOffersWords:
    def test_a_ronda_without_place_or_hour_says_so(self):
        ronda = documents()[f"rondas/{RONDA}"]
        ronda.pop("place")
        ronda["slot"].pop("hour")

        title, body = bench.offer_message(ronda, THURSDAY, at(5, 12), at(5, 9))

        assert title == "Se liberó un lugar para hoy"
        assert body == (
            "Jueves a la tarde · mate en la rambla. Lugar y hora a confirmar. Estabas en la "
            "lista de espera. ¿Lo tomás? Tenés hasta las 12:00."
        )
