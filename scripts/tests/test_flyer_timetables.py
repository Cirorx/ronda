"""flyer.py's timetables (#65): a Montevideo barrio's last bus comes from the Intendencia's city
GTFS, downloaded with a token; the Costa's from the DNT's. Nothing here reaches a network."""

import io
import json

import pytest

import flyer
import seed
from tests.invented_gtfs import write_invented_city_gtfs
from tests.test_flyer import FakeClient


def test_a_montevideo_flyer_gets_its_last_bus_from_the_city_timetable(monkeypatch, tmp_path):
    client = FakeClient()
    monkeypatch.setenv(seed.FIRESTORE_HOST, "127.0.0.1:8088")
    monkeypatch.setenv("GCLOUD_PROJECT", "demo-ronda-flyer")
    monkeypatch.setattr(seed, "firestore_client", lambda project: client)
    monkeypatch.setattr(flyer, "new_id", lambda: "k3m9x2pq")
    city = write_invented_city_gtfs(tmp_path / "city.zip")
    asked = []

    def fake_timetable(source, folder):
        asked.append(source)
        return city

    monkeypatch.setattr(flyer, "timetable", fake_timetable)
    args = ["--lat", "-34.9111", "--lng", "-56.1506", "--label", "Invented corner"]

    assert flyer.main([*args, "--out", str(tmp_path / "flyer.pdf")]) == 0

    assert asked == [flyer.last_bus.CITY_GTFS]
    document = client.documents["flyers/k3m9x2pq"]
    assert document["barrio"] == "pocitos"
    assert document["stop"] == {"id": "M1", "name": "Calle Inventada Y Otra Calle"}
    assert document["lastBus"]["weekday"] == {
        "time": "00:16",
        "estimated": False,
        "route": "X100",
        "published": {"time": "00:16", "stop": "Calle Inventada Y Otra Calle"},
    }
    assert document["lastBus"]["saturday"]["time"] == "23:01"
    assert document["lastBus"]["sunday"] is None


def test_montevideo_barrios_read_the_city_timetable_and_the_costa_the_dnt():
    assert flyer.timetable_url("pocitos") == flyer.last_bus.CITY_GTFS
    assert flyer.timetable_url("ciudad-vieja") == flyer.last_bus.CITY_GTFS
    assert flyer.timetable_url("solymar-sur") == flyer.last_bus.DNT_GTFS


class TestDownload:
    @pytest.fixture
    def requests(self, monkeypatch):
        sent = []

        def urlopen(request, timeout):
            sent.append(request)
            if request.full_url == flyer.last_bus.CITY_TOKEN_URL:
                return io.BytesIO(json.dumps({"access_token": "fresh", "expires_in": 300}).encode())
            return io.BytesIO(b"zip bytes")

        monkeypatch.setattr(flyer.urllib.request, "urlopen", urlopen)
        return sent

    def test_the_city_timetable_downloads_with_a_bearer_token(
        self, monkeypatch, requests, tmp_path
    ):
        monkeypatch.setattr(flyer, "city_token", lambda: "invented-token")

        target = flyer.timetable(flyer.last_bus.CITY_GTFS, tmp_path)

        assert target.read_bytes() == b"zip bytes"
        assert requests[0].get_header("Authorization") == "Bearer invented-token"

    def test_the_dnt_timetable_downloads_without_a_token(self, monkeypatch, requests, tmp_path):
        monkeypatch.setattr(flyer, "city_token", lambda: pytest.fail("no token for the DNT"))

        flyer.timetable(flyer.last_bus.DNT_GTFS, tmp_path)

        assert requests[0].get_header("Authorization") is None

    def test_the_token_comes_from_the_client_credentials(self, monkeypatch, requests):
        monkeypatch.setenv("MVD_API_CLIENT_ID", "invented-id")
        monkeypatch.setenv("MVD_API_SECRET_ID", "invented-secret")

        assert flyer.city_token() == "fresh"
        form = dict(flyer.urllib.parse.parse_qsl(requests[0].data.decode()))
        assert form == {
            "grant_type": "client_credentials",
            "client_id": "invented-id",
            "client_secret": "invented-secret",
        }
