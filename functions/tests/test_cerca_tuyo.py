"""Cerca tuyo's per-barrio counts and the flyer landing, over the Firestore stand-in, and the two
functions main.py registers for them. Every uid and name is invented."""

import inspect
import json
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
from firebase_functions import scheduler_fn
from google.cloud.firestore import Increment

import cerca_tuyo
import main
from proposals import BARRIOS
from tests.fake_firestore import FakeDocument, FakeFirestore

NOW = datetime(2026, 11, 1, 15, 0, tzinfo=UTC)


class ScanFirestore(FakeFirestore):
    """The stand-in, plus `update` with `Increment`, which a scan uses."""

    def document(self, path: str) -> "_UpdatableDocument":
        return _UpdatableDocument(self, path)


class _UpdatableDocument(FakeDocument):
    def update(self, fields: dict) -> None:
        current = self._db.documents[self.path]  # like Firestore, a missing document fails
        for key, value in fields.items():
            if isinstance(value, Increment):
                value = current.get(key, 0) + value.value
            current[key] = value


def user(barrio, age_band="60-69", pretexts=("mate",), slots=("sat-afternoon",), name="Vecina"):
    return {
        "firstName": name,
        "ageBand": age_band,
        "barrio": barrio,
        "pretexts": list(pretexts),
        "slots": list(slots),
    }


def ronda(barrio, pretext="mate", day="sat", time="afternoon", status="active"):
    return {
        "seatId": f"{barrio}_{pretext}_{day}-{time}",
        "barrio": barrio,
        "pretext": pretext,
        "slot": {"day": day, "time": time},
        "size": 4,
        "status": status,
    }


def six(pretext: str) -> int:
    return 10 if pretext == "futbol5" else 6


class TestCercaDocuments:
    def test_writes_every_barrio_even_one_with_nothing_in_it(self):
        documents = cerca_tuyo.cerca_documents(["el-pinar-sur", "shangrila"], [], {}, six, NOW)

        assert documents == {
            "cerca/el-pinar-sur": {
                "barrio": "el-pinar-sur",
                "rondas": [],
                "waiting": [],
                "updatedAt": NOW,
            },
            "cerca/shangrila": {
                "barrio": "shangrila",
                "rondas": [],
                "waiting": [],
                "updatedAt": NOW,
            },
        }

    def test_a_ronda_row_holds_its_age_range_seats_and_who_waits_for_it(self):
        users = {
            "demo-a": user("solymar-norte", "30-39"),
            "demo-b": user("solymar-norte", "70-79"),
            "demo-c": user("solymar-norte", "60-69"),
            "demo-wait": user("solymar-norte", pretexts=("mate", "truco")),
            "demo-other-slot": user("solymar-norte", slots=("sun-afternoon",)),
            "demo-other-barrio": user("solymar-sur"),
        }
        rondas = [(ronda("solymar-norte"), ["demo-a", "demo-b", "demo-c"])]

        documents = cerca_tuyo.cerca_documents(["solymar-norte"], rondas, users, six, NOW)

        assert documents["cerca/solymar-norte"]["rondas"] == [
            {
                "pretext": "mate",
                "slot": "sat-afternoon",
                "ageFrom": 30,
                "ageTo": 79,
                "members": 3,
                "cap": 6,
                "waiting": 1,
            }
        ]

    def test_an_eighty_and_over_member_leaves_the_range_open_above(self):
        users = {"demo-a": user("lagomar-sur", "50-59"), "demo-b": user("lagomar-sur", "80+")}
        rondas = [(ronda("lagomar-sur"), ["demo-a", "demo-b"])]

        [row] = cerca_tuyo.cerca_documents(["lagomar-sur"], rondas, users, six, NOW)[
            "cerca/lagomar-sur"
        ]["rondas"]

        assert (row["ageFrom"], row["ageTo"]) == (50, None)

    def test_a_ronda_whose_members_have_no_age_band_shows_no_range(self):
        rondas = [(ronda("lagomar-sur", pretext="futbol5"), ["demo-gone"])]

        [row] = cerca_tuyo.cerca_documents(["lagomar-sur"], rondas, {}, six, NOW)[
            "cerca/lagomar-sur"
        ]["rondas"]

        assert (row["ageFrom"], row["ageTo"], row["members"], row["cap"]) == (None, None, 1, 10)

    def test_rows_go_by_pretext_then_day_then_band_and_unknown_ones_last(self):
        rondas = [
            (ronda("shangrila", "caminata", "mon", "morning"), []),
            (ronda("shangrila", "mate", "sun", "evening"), []),
            (ronda("shangrila", "mate", "sat", "evening"), []),
            (ronda("shangrila", "mate", "sat", "morning"), []),
            (ronda("shangrila", "petanca", "mon", "morning"), []),
            (ronda("shangrila", "mate", "someday", "morning"), []),
            (ronda("shangrila", "truco", "tue", "late"), []),
        ]

        rows = cerca_tuyo.cerca_documents(["shangrila"], rondas, {}, six, NOW)["cerca/shangrila"][
            "rondas"
        ]

        assert [(row["pretext"], row["slot"]) for row in rows] == [
            ("mate", "sat-morning"),
            ("mate", "sat-evening"),
            ("mate", "sun-evening"),
            ("mate", "someday-morning"),
            ("truco", "tue-late"),
            ("caminata", "mon-morning"),
            ("petanca", "mon-morning"),
        ]

    def test_a_barrio_counts_who_waits_by_pretext_leaving_out_the_seated_and_the_unknown(self):
        users = {
            "demo-seated": user("el-pinar-norte", pretexts=("caminata",)),
            "demo-1": user("el-pinar-norte", pretexts=("caminata", "mate")),
            "demo-2": user("el-pinar-norte", pretexts=("caminata",)),
            "demo-terms-only": {"terms": {"version": "2026-10-27"}, "barrio": "el-pinar-norte"},
            "demo-unknown-barrio": user("atlantida", pretexts=("caminata",)),
            "demo-no-pretexts": {"firstName": "Vecina", "barrio": "el-pinar-norte"},
        }
        rondas = [(ronda("el-pinar-sur", "caminata"), ["demo-seated"])]

        documents = cerca_tuyo.cerca_documents(
            ["el-pinar-norte", "el-pinar-sur"], rondas, users, six, NOW
        )

        assert documents["cerca/el-pinar-norte"]["waiting"] == [
            {"pretext": "mate", "count": 1},
            {"pretext": "caminata", "count": 2},
        ]
        assert documents["cerca/el-pinar-sur"]["waiting"] == []

    def test_no_uid_name_or_place_reaches_a_document(self):
        users = {"demo-a": user("solymar-sur", name="Graciela"), "demo-b": user("solymar-sur")}
        rondas = [(ronda("solymar-sur") | {"place": {"name": "Quiosco"}}, ["demo-a"])]

        text = json.dumps(
            cerca_tuyo.cerca_documents(["solymar-sur"], rondas, users, six, NOW), default=str
        )

        for secret in ("demo-a", "demo-b", "Graciela", "Vecina", "Quiosco", "seatId"):
            assert secret not in text


class TestRunRefreshCerca:
    @pytest.fixture
    def db(self) -> FakeFirestore:
        return FakeFirestore(
            {
                "users/demo-a": user("solymar-norte", "18-29"),
                "users/demo-b": user("solymar-norte", "60-69"),
                "users/demo-c": user("solymar-norte", "70-79"),
                "users/demo-d": user("solymar-norte", "40-49"),
                "users/demo-e": user("solymar-norte", "50-59", pretexts=("futbol5",)),
                "rondas/r1": ronda("solymar-norte", status="forming"),
                "rondas/r1/members/demo-a": {"state": "active"},
                "rondas/r1/members/demo-b": {"state": "paused"},
                "rondas/r1/members/demo-c": {"state": "left"},
                "rondas/r2": ronda("solymar-norte", "futbol5", status="ended"),
                "rondas/r2/members/demo-d": {"state": "active"},
                "rondas/r3": ronda("lomas-de-solymar", "futbol5"),
            }
        )

    def test_writes_one_document_per_barrio_and_returns_how_many(self, db):
        assert cerca_tuyo.run_refresh_cerca(db, NOW) == len(BARRIOS)
        assert {p for p in db.documents if p.startswith("cerca/")} == {
            f"cerca/{barrio}" for barrio in BARRIOS
        }

    def test_counts_active_and_paused_members_of_open_rondas_against_the_pretexts_cap(self, db):
        cerca_tuyo.run_refresh_cerca(db, NOW)

        norte = db.documents["cerca/solymar-norte"]
        assert norte["rondas"] == [
            {
                "pretext": "mate",
                "slot": "sat-afternoon",
                "ageFrom": 18,
                "ageTo": 69,
                "members": 2,
                "cap": 6,
                "waiting": 2,
            }
        ]
        assert norte["waiting"] == [
            {"pretext": "mate", "count": 2},
            {"pretext": "futbol5", "count": 1},
        ]
        assert db.documents["cerca/lomas-de-solymar"]["rondas"][0]["cap"] == 10


FLYER = {
    "label": "Almacén de la esquina",
    "pretext": "mate",
    "slot": "sat-afternoon",
    "barrio": "solymar-norte",
    "nearBarrios": ["solymar-sur", "solymar-norte"],
    "stop": {"id": "16152", "name": "Transversal y Horacio G. Lagos"},
    "lastBus": {
        "weekday": {
            "time": "23:06",
            "estimated": True,
            "route": "7E7R",
            "published": {"time": "22:40", "stop": "Terminal"},
            "tripId": "x",
        },
        "saturday": {"time": "21:02", "estimated": False, "route": "7E7R"},
        "sunday": None,
    },
    "scans": 0,
    "createdAt": NOW,
}
MATE_FLYER = {
    "kind": "mate",
    "rondaId": "ronda-secret-1",
    "barrio": "solymar-norte",
    "createdBy": "demo-host-uid",
    "imagePath": "flyers/demo-host-uid/m4t3m4t3.jpg",
    "scans": 0,
    "createdAt": NOW,
}
ROW = {
    "pretext": "mate",
    "slot": "sat-afternoon",
    "ageFrom": 30,
    "ageTo": 79,
    "members": 4,
    "cap": 6,
    "waiting": 0,
}


@pytest.fixture
def scan_db() -> ScanFirestore:
    return ScanFirestore(
        {
            "flyers/k3m9x2pq": dict(FLYER),
            "flyers/m4t3m4t3": dict(MATE_FLYER),
            "cerca/solymar-norte": {
                "barrio": "solymar-norte",
                "rondas": [ROW],
                "waiting": [{"pretext": "caminata", "count": 3}],
                "updatedAt": NOW,
            },
            "cerca/solymar-sur": {
                "barrio": "solymar-sur",
                "rondas": [ROW | {"pretext": "truco"}],
                "waiting": [],
                "updatedAt": NOW - timedelta(minutes=30),
            },
        }
    )


class TestLanding:
    def test_a_post_counts_one_scan_and_answers_the_page(self, scan_db):
        status, body = cerca_tuyo.landing(scan_db, "POST", "/api/f/k3m9x2pq", NOW)
        cerca_tuyo.landing(scan_db, "POST", "/api/f/k3m9x2pq/", NOW)

        assert status == 200
        assert scan_db.documents["flyers/k3m9x2pq"]["scans"] == 2
        assert scan_db.documents["flyers/k3m9x2pq"]["lastScanAt"] == NOW
        assert json.loads(body)["barrio"] == "solymar-norte"

    def test_a_get_answers_without_counting(self, scan_db):
        status, _ = cerca_tuyo.landing(scan_db, "GET", "/api/f/k3m9x2pq", NOW)

        assert status == 200
        assert scan_db.documents["flyers/k3m9x2pq"]["scans"] == 0

    def test_shows_the_flyers_own_barrio_first_then_the_others_in_walking_distance(self, scan_db):
        _, body = cerca_tuyo.landing(scan_db, "GET", "/api/f/k3m9x2pq", NOW)

        page = json.loads(body)
        assert [(row["barrio"], row["pretext"]) for row in page["rondas"]] == [
            ("solymar-norte", "mate"),
            ("solymar-sur", "truco"),
        ]
        assert page["waiting"] == [{"barrio": "solymar-norte", "pretext": "caminata", "count": 3}]
        assert page["updatedAt"] == (NOW - timedelta(minutes=30)).isoformat()

    def test_answers_the_last_bus_with_only_its_public_fields(self, scan_db):
        _, body = cerca_tuyo.landing(scan_db, "GET", "/api/f/k3m9x2pq", NOW)

        assert json.loads(body)["lastBus"] == {
            "stop": "Transversal y Horacio G. Lagos",
            "weekday": {
                "time": "23:06",
                "estimated": True,
                "route": "7E7R",
                "published": {"time": "22:40", "stop": "Terminal"},
            },
            "saturday": {"time": "21:02", "estimated": False, "route": "7E7R"},
            "sunday": None,
        }

    def test_never_answers_the_label_the_stop_id_or_the_scans(self, scan_db):
        _, body = cerca_tuyo.landing(scan_db, "POST", "/api/f/k3m9x2pq", NOW)

        for secret in ("Almacén", "16152", "scans", "label", "tripId", "lastScanAt"):
            assert secret not in body

    def test_a_flyer_without_near_barrios_shows_its_own(self, scan_db):
        flyer = scan_db.documents["flyers/k3m9x2pq"]
        del flyer["nearBarrios"], flyer["stop"], flyer["lastBus"]

        _, body = cerca_tuyo.landing(scan_db, "GET", "/api/f/k3m9x2pq", NOW)

        page = json.loads(body)
        assert {row["barrio"] for row in page["rondas"]} == {"solymar-norte"}
        assert page["lastBus"] == {"stop": None, "weekday": None, "saturday": None, "sunday": None}

    def test_a_barrio_without_counts_yet_shows_nothing(self, scan_db):
        scan_db.documents["flyers/k3m9x2pq"]["nearBarrios"] = ["el-pinar-sur"]

        _, body = cerca_tuyo.landing(scan_db, "GET", "/api/f/k3m9x2pq", NOW)

        page = json.loads(body)
        assert (page["rondas"], page["waiting"], page["updatedAt"]) == ([], [], None)

    @pytest.mark.parametrize(
        "path", ["/api/f/nope0000", "/api/f/K3M9X2PQ", "/api/f/k3m9", "/api/f/../users", "/"]
    )
    def test_answers_not_found_for_an_unknown_or_malformed_id(self, scan_db, path):
        status, body = cerca_tuyo.landing(scan_db, "POST", path, NOW)

        assert (status, json.loads(body)) == (404, {"error": "not-found"})
        assert scan_db.documents["flyers/k3m9x2pq"]["scans"] == 0

    def test_reads_a_flyer_marked_tear_off_like_one_without_a_kind(self, scan_db):
        scan_db.documents["flyers/k3m9x2pq"]["kind"] = "tearOff"

        _, marked = cerca_tuyo.landing(scan_db, "GET", "/api/f/k3m9x2pq", NOW)
        del scan_db.documents["flyers/k3m9x2pq"]["kind"]
        _, unmarked = cerca_tuyo.landing(scan_db, "GET", "/api/f/k3m9x2pq", NOW)

        assert marked == unmarked
        assert json.loads(marked)["kind"] == "tearOff"

    def test_answers_not_found_for_a_kind_it_does_not_know_and_counts_nothing(self, scan_db):
        scan_db.documents["flyers/k3m9x2pq"]["kind"] = "poster"

        status, body = cerca_tuyo.landing(scan_db, "POST", "/api/f/k3m9x2pq", NOW)

        assert (status, json.loads(body)) == (404, {"error": "not-found"})
        assert scan_db.documents["flyers/k3m9x2pq"]["scans"] == 0

    def test_a_mate_flyer_counts_its_scan_and_shows_its_rondas_barrio_with_no_bus(self, scan_db):
        status, body = cerca_tuyo.landing(scan_db, "POST", "/api/f/m4t3m4t3", NOW)

        assert status == 200
        assert scan_db.documents["flyers/m4t3m4t3"]["scans"] == 1
        assert scan_db.documents["flyers/m4t3m4t3"]["lastScanAt"] == NOW
        page = json.loads(body)
        assert page["kind"] == "mate"
        assert page["barrio"] == "solymar-norte"
        assert {row["barrio"] for row in page["rondas"]} == {"solymar-norte"}
        assert page["waiting"] == [{"barrio": "solymar-norte", "pretext": "caminata", "count": 3}]
        assert page["lastBus"] == {"stop": None, "weekday": None, "saturday": None, "sunday": None}

    def test_never_answers_a_mate_flyers_ronda_host_or_image(self, scan_db):
        _, body = cerca_tuyo.landing(scan_db, "POST", "/api/f/m4t3m4t3", NOW)

        for secret in ("ronda-secret-1", "demo-host-uid", "flyers/", "rondaId", "createdBy"):
            assert secret not in body
        assert set(json.loads(body)) == {
            "kind",
            "barrio",
            "rondas",
            "waiting",
            "lastBus",
            "updatedAt",
        }

    def test_a_mate_flyer_whose_ronda_had_no_barrio_shows_nothing(self, scan_db):
        del scan_db.documents["flyers/m4t3m4t3"]["barrio"]

        status, body = cerca_tuyo.landing(scan_db, "GET", "/api/f/m4t3m4t3", NOW)

        page = json.loads(body)
        assert status == 200
        assert (page["barrio"], page["rondas"], page["waiting"]) == (None, [], [])

    def test_refuses_any_other_method(self, scan_db):
        status, _ = cerca_tuyo.landing(scan_db, "DELETE", "/api/f/k3m9x2pq", NOW)

        assert status == 405
        assert "flyers/k3m9x2pq" in scan_db.documents


class TestRefreshCercaFunction:
    def test_runs_every_hour_in_the_region_on_one_instance(self):
        endpoint = main.refresh_cerca.__firebase_endpoint__

        assert endpoint.scheduleTrigger["schedule"] == "every 1 hours"
        assert endpoint.region == [main.REGION]
        assert endpoint.maxInstances == 1

    def test_refreshes_at_the_scheduled_time(self, monkeypatch):
        db = FakeFirestore()
        monkeypatch.setattr(main, "_firestore", lambda: db)

        event = scheduler_fn.ScheduledEvent(job_name="cerca", schedule_time=NOW)
        inspect.unwrap(main.refresh_cerca)(event)

        assert db.documents["cerca/shangrila"]["updatedAt"] == NOW


class TestFlyerLandingFunction:
    def test_anyone_may_call_it_in_the_region(self):
        endpoint = main.flyer_landing.__firebase_endpoint__

        assert endpoint.httpsTrigger["invoker"] == ["public"]
        assert endpoint.region == [main.REGION]

    def test_answers_json_that_no_cache_keeps(self, monkeypatch, scan_db):
        monkeypatch.setattr(main, "_firestore", lambda: scan_db)

        response = inspect.unwrap(main.flyer_landing)(
            SimpleNamespace(method="POST", path="/api/f/k3m9x2pq")
        )

        assert response.status_code == 200
        assert response.headers["Cache-Control"] == "no-store"
        assert response.mimetype == "application/json"
        assert json.loads(response.get_data())["barrio"] == "solymar-norte"
        assert scan_db.documents["flyers/k3m9x2pq"]["scans"] == 1

    def test_answers_not_found_for_an_unknown_flyer(self, monkeypatch, scan_db):
        monkeypatch.setattr(main, "_firestore", lambda: scan_db)

        response = inspect.unwrap(main.flyer_landing)(
            SimpleNamespace(method="GET", path="/api/f/zzzzzzzz")
        )

        assert response.status_code == 404
