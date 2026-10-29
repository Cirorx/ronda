import re
from datetime import UTC, datetime

import pytest
from google.api_core.exceptions import AlreadyExists

import flyer
import seed
from tests.invented_gtfs import write_invented_gtfs

NOW = datetime(2026, 11, 1, 15, 0, tzinfo=UTC)
NEAR_B = ["--lat", "-34.8101", "--lng", "-55.9401"]
"""An invented spot next to the invented stop B: Lomas de Solymar by the demo centroids."""


class FakeClient:
    """The slice of a Firestore client `flyer.create` uses: create-only documents."""

    def __init__(self, taken: tuple[str, ...] = ()) -> None:
        self.documents: dict[str, dict] = {f"flyers/{i}": {} for i in taken}

    def collection(self, name):
        return self._Collection(self, name)

    class _Collection:
        def __init__(self, client, name):
            self._client, self._name = client, name

        def document(self, document_id):
            return FakeClient._Document(self._client, f"{self._name}/{document_id}")

    class _Document:
        def __init__(self, client, path):
            self._client, self._path = client, path

        def create(self, fields):
            if self._path in self._client.documents:
                raise AlreadyExists(self._path)
            self._client.documents[self._path] = fields


class TestFlyerText:
    def test_says_the_day_band_and_barrio_never_a_spot(self):
        text = flyer.flyer_text("mate", "sat-afternoon", "solymar-norte")

        assert text.headline == "¿Te sumás a un mate?"
        assert text.facts == (
            "Los sábados de 14 a 18, en Solymar Norte",
            "5 o 6 vecinos de todas las edades",
            "No hace falta traer nada",
        )
        assert text.tear == "Arrancá una tira y escaneala."
        assert text.money == "Ronda nunca pide plata."

    def test_without_a_slot_says_once_a_week(self):
        assert flyer.flyer_text("caminata", None, "el-pinar-sur").facts[0] == (
            "Una vez por semana, en El Pinar Sur"
        )

    def test_a_football_flyer_counts_ten(self):
        text = flyer.flyer_text("futbol5", "thu-evening", "lagomar-sur")

        assert text.headline == "¿Te sumás a un fútbol 5?"
        assert text.facts[:2] == (
            "Los jueves de 19 a 21, en Lagomar Sur",
            "10 vecinos de todas las edades",
        )
        assert text.what.startswith("Grupos de 10 vecinos")

    def test_every_barrio_and_pretext_has_its_words(self):
        assert set(flyer.BARRIO_NAMES) == set(flyer.DEMO_BARRIOS)
        assert set(flyer.HEADLINES) == {"mate", "truco", "futbol5", "caminata"}


class TestWhere:
    def test_the_barrio_is_the_nearest_centroid(self):
        assert flyer.barrio_at(flyer.DEMO_BARRIOS["lagomar-sur"]) == "lagomar-sur"

    def test_near_barrios_start_with_its_own_then_those_within_ten_blocks(self):
        spot = flyer.DEMO_BARRIOS["solymar-norte"]

        near = flyer.near_barrios(spot, "solymar-norte")

        assert near == ["solymar-norte", "solymar-sur"]

    def test_a_chosen_barrio_comes_first_even_when_another_is_nearer(self):
        spot = flyer.DEMO_BARRIOS["solymar-norte"]

        assert flyer.near_barrios(spot, "el-pinar-sur") == [
            "el-pinar-sur",
            "solymar-norte",
            "solymar-sur",
        ]


class TestIds:
    def test_an_id_is_what_the_landing_function_accepts(self):
        for _ in range(50):
            assert re.fullmatch(r"[a-z0-9]{8}", flyer.new_id())

    def test_the_alphabet_leaves_out_characters_read_alike(self):
        assert not set("01ilo") & set(flyer.ID_ALPHABET)

    def test_create_never_writes_over_a_flyer(self, monkeypatch):
        ids = iter(["taken000", "fresh000"])
        monkeypatch.setattr(flyer, "new_id", lambda: next(ids))
        client = FakeClient(taken=("taken000",))

        assert flyer.create(client, {"scans": 0}) == "fresh000"
        assert client.documents["flyers/taken000"] == {}

    def test_create_gives_up_after_a_few_tries(self, monkeypatch):
        monkeypatch.setattr(flyer, "new_id", lambda: "taken000")

        with pytest.raises(RuntimeError):
            flyer.create(FakeClient(taken=("taken000",)), {}, attempts=2)


class TestMain:
    @pytest.fixture
    def gtfs(self, tmp_path):
        return str(write_invented_gtfs(tmp_path / "gtfs.zip"))

    @pytest.fixture
    def client(self, monkeypatch):
        client = FakeClient()
        monkeypatch.setenv(seed.FIRESTORE_HOST, "127.0.0.1:8088")
        monkeypatch.setenv("GCLOUD_PROJECT", "demo-ronda-flyer")
        monkeypatch.setattr(seed, "firestore_client", lambda project: client)
        monkeypatch.setattr(flyer, "new_id", lambda: "k3m9x2pq")
        return client

    def test_refuses_without_the_emulator_or_a_project(self, monkeypatch, capsys):
        monkeypatch.delenv(seed.FIRESTORE_HOST, raising=False)

        assert flyer.main([*NEAR_B, "--label", "Invented"]) == 1
        assert "--project" in capsys.readouterr().out

    def test_writes_the_flyer_document_without_coordinates(self, client, gtfs, tmp_path):
        out = tmp_path / "flyer.pdf"
        args = [*NEAR_B, "--label", "Invented spot", "--slot", "sat-afternoon"]

        assert flyer.main([*args, "--gtfs", gtfs, "--out", str(out)]) == 0

        document = client.documents["flyers/k3m9x2pq"]
        assert set(document) == {
            "kind",
            "label",
            "pretext",
            "slot",
            "barrio",
            "nearBarrios",
            "stop",
            "lastBus",
            "scans",
            "createdAt",
        }
        assert document["kind"] == "tearOff"
        assert document["barrio"] == "lomas-de-solymar"
        assert document["nearBarrios"] == ["lomas-de-solymar"]
        assert document["stop"] == {"id": "B", "name": "Rambla y Calle Inventada"}
        assert document["lastBus"]["weekday"]["time"] == "00:00"
        assert document["scans"] == 0
        assert "-34.8101" not in repr(document)

    def test_prints_a_pdf_whose_seven_qr_strips_link_the_flyers_page(self, client, gtfs, tmp_path):
        out = tmp_path / "flyer.pdf"

        flyer.main([*NEAR_B, "--label", "Invented", "--gtfs", gtfs, "--out", str(out)])

        pdf = out.read_bytes()
        assert pdf.startswith(b"%PDF")
        assert pdf.count(b"(https://demo-ronda-flyer.firebaseapp.com/f/k3m9x2pq)") == 7

    def test_takes_another_stop_and_base_url(self, client, gtfs, tmp_path):
        out = tmp_path / "flyer.pdf"
        args = ["--stop", "D", "--base-url", "http://127.0.0.1:5002/", "--out", str(out)]

        flyer.main([*NEAR_B, "--label", "Invented", "--gtfs", gtfs, *args])

        assert client.documents["flyers/k3m9x2pq"]["stop"]["id"] == "D"
        assert out.read_bytes().count(b"(http://127.0.0.1:5002/f/k3m9x2pq)") == 7

    def test_refuses_a_stop_the_timetable_lacks(self, client, gtfs, capsys):
        args = ["--label", "Invented", "--gtfs", gtfs, "--stop", "nope"]

        assert flyer.main([*NEAR_B, *args]) == 1
        assert client.documents == {}

    def test_refuses_a_malformed_slot(self, client, gtfs):
        with pytest.raises(SystemExit):
            flyer.main([*NEAR_B, "--label", "Invented", "--gtfs", gtfs, "--slot", "saturday"])

    def test_a_local_timetable_is_read_where_it_is(self, tmp_path):
        assert flyer.timetable("feeds/gtfs.zip", tmp_path) == flyer.Path("feeds/gtfs.zip")


def test_the_document_holds_no_coordinates_or_person():
    stop = flyer.last_bus.Stop("B", "Rambla y Calle Inventada", -34.81, -55.94)

    document = flyer.flyer_document(
        label="Invented spot",
        pretext="mate",
        slot=None,
        barrio="solymar-norte",
        near=["solymar-norte"],
        stop=stop,
        buses={"weekday": None, "saturday": None, "sunday": None},
        now=NOW,
    )

    assert document["stop"] == {"id": "B", "name": "Rambla y Calle Inventada"}
    assert "-34.81" not in repr(document)
