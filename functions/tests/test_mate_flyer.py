"""mate_flyer without the network: SAM 3.1 answers through a stand-in for the OpenAI SDK that
streams the Responses events `scripts/smoke/s5_sam.py` reads, with masks encoded the way the
API sends them, and Muse Image through httpx's MockTransport with `s6_image.py`'s JSON. The
pipeline itself runs on in-memory Firestore and Storage and on fake models."""

import asyncio
import base64
import io
from datetime import UTC, datetime
from types import SimpleNamespace

import httpx
import pytest
import segno
from meta_sam_parser._mask_codec import _encode_raster
from PIL import Image

import mate_flyer as m
from tests.fake_firestore import FakeFirestore
from tests.fake_storage import FakeBucket, StoredObject

UID = "demo-host"
PHOTO = f"flyer_photos/{UID}/photo-1.jpg"
NOW = datetime(2026, 11, 1, 15, 0, tzinfo=UTC)
RONDA = {
    "pretext": "mate",
    "barrio": "solymar-norte",
    "slot": {"day": "thu", "time": "afternoon"},
    "hosts": {"anfitrion": UID, "cola": "demo-cola"},
}


def jpeg(size=(400, 300), colour=(200, 180, 150)) -> bytes:
    """An invented photo: a plain table with a dark thermos-shaped block on it."""
    image = Image.new("RGB", size, colour)
    image.paste((40, 40, 40), (150, 80, 230, 260))
    out = io.BytesIO()
    image.save(out, format="JPEG")
    return out.getvalue()


def png(size=(1024, 1536), colour=(120, 170, 200)) -> bytes:
    out = io.BytesIO()
    Image.new("RGB", size, colour).save(out, format="PNG")
    return out.getvalue()


def mask(left=150, top=80, right=230, bottom=260, *, confidence=None) -> m.Mask:
    return m.Mask(left, top, right, bottom, 2, 2, bytes([1, 1, 0, 1]), confidence)


# --- SAM 3.1 over the Responses stream ------------------------------------------------------


def sam_line(object_id: int, box: tuple[int, int, int, int], raster: list[int], w: int, h: int):
    """One record as SAM 3.1 streams it: a box and a base85 one-bit mask (height first)."""
    x1, y1, x2, y2 = box
    payload = _encode_raster(raster, w, h)
    return (
        f"{object_id}<|box;x1={x1};y1={y1};x2={x2};y2={y2};w=640;h=480;c=0.8|>"
        f"<|mask;x=0;y=0;data={h},{w},{payload}|>"
    )


def sam_events(text: str):
    lane = {"item_id": "msg-1", "output_index": 0, "content_index": 0}

    async def events():
        yield {"type": "response.output_text.delta", "delta": text, **lane}
        yield {"type": "response.output_text.done", "text": text, **lane}
        yield {"type": "response.completed"}

    return events()


class FakeAsyncOpenAI:
    """The slice of `openai.AsyncOpenAI` MetaSam uses: `responses.create(stream=True)`."""

    def __init__(self, text: str = "", error: Exception | None = None):
        self.calls: list[dict] = []
        self.closed = False
        self._text, self._error = text, error
        self.responses = SimpleNamespace(create=self._create)

    async def _create(self, **kwargs):
        self.calls.append(kwargs)
        if self._error:
            raise self._error
        return sam_events(self._text)

    async def close(self):
        self.closed = True


class TestMetaSam:
    def test_sends_the_phrase_and_the_photo_and_decodes_each_mask(self):
        text = "<0f>" + sam_line(1, (10, 20, 49, 59), [0, 1, 1, 1], 2, 2) + "\n"
        client = FakeAsyncOpenAI(text)

        masks = asyncio.run(m.MetaSam(client).segment(b"png-bytes", "thermos"))

        assert masks == [m.Mask(10, 20, 50, 60, 2, 2, bytes([0, 1, 1, 1]), 0.8)]
        call = client.calls[0]
        assert call["model"] == "sam-3.1"
        assert call["stream"] is True
        content = call["input"][0]["content"]
        assert content[0] == {"type": "input_text", "text": "thermos"}
        assert content[1]["image_url"] == "data:image/png;base64," + base64.b64encode(
            b"png-bytes"
        ).decode("ascii")

    def test_prefers_the_mask_confidence(self):
        text = "<0f>" + sam_line(1, (0, 0, 9, 9), [1], 1, 1).replace("x=0;y=0;", "x=0;y=0;c=0.3;")
        masks = asyncio.run(m.MetaSam(FakeAsyncOpenAI(text)).segment(b"", "thermos"))

        assert masks[0].confidence == 0.3

    def test_finds_nothing_in_plain_text(self):
        masks = asyncio.run(m.MetaSam(FakeAsyncOpenAI("No thermos here.")).segment(b"", "x"))

        assert masks == []

    def test_turns_any_failure_into_model_unavailable(self):
        client = FakeAsyncOpenAI(error=RuntimeError("503"))

        with pytest.raises(m.ModelUnavailable):
            asyncio.run(m.MetaSam(client).segment(b"", "thermos"))


# --- Muse Image -----------------------------------------------------------------------------


def muse(*responses: httpx.Response, seen: list | None = None) -> m.MuseImage:
    queue = list(responses)

    def handler(request: httpx.Request) -> httpx.Response:
        if seen is not None:
            seen.append(request)
        return queue.pop(0)

    http = httpx.AsyncClient(transport=httpx.MockTransport(handler))
    return m.MuseImage(http, "test-key", backoff=0)


def painted(image: bytes = b"PNG") -> httpx.Response:
    return httpx.Response(
        200, json={"data": [{"b64_json": base64.b64encode(image).decode()}], "usage": {}}
    )


class TestMuseImage:
    def test_paints_a_portrait_png_from_the_prompt(self):
        seen: list[httpx.Request] = []

        image = asyncio.run(muse(painted(b"picture"), seen=seen).paint("a promenade"))

        assert image == b"picture"
        request = seen[0]
        assert str(request.url) == "https://api.meta.ai/v1/images/generations"
        assert request.headers["Authorization"] == "Bearer test-key"
        assert request.read() and b'"size":"1024x1536"' in request.read().replace(b" ", b"")
        assert b'"model":"muse-image-1.0"' in request.read().replace(b" ", b"")

    def test_retries_rate_limits_and_server_errors(self):
        image = asyncio.run(
            muse(httpx.Response(429), httpx.Response(503), painted(b"ok")).paint("p")
        )

        assert image == b"ok"

    def test_gives_up_after_three_failures(self):
        failures = [httpx.Response(500)] * 3

        with pytest.raises(m.ModelUnavailable, match="HTTP 500"):
            asyncio.run(muse(*failures).paint("p"))

    def test_does_not_retry_a_bad_request(self):
        with pytest.raises(m.ModelUnavailable, match="HTTP 400"):
            asyncio.run(muse(httpx.Response(400), painted()).paint("p"))

    def test_turns_an_answer_without_an_image_into_model_unavailable(self):
        with pytest.raises(m.ModelUnavailable, match="no image"):
            asyncio.run(muse(httpx.Response(200, json={"data": []})).paint("p"))


# --- Who may make it ------------------------------------------------------------------------


class TestMayMakeFlyer:
    def test_the_hosts_once_there_are_any(self):
        db = FakeFirestore({f"rondas/r1/members/{UID}": {"state": "active"}})

        assert m.may_make_flyer(db, "r1", RONDA, UID)
        assert m.may_make_flyer(db, "r1", RONDA, "demo-cola")
        assert not m.may_make_flyer(db, "r1", RONDA, "demo-member")

    def test_any_active_member_while_it_has_no_hosts(self):
        db = FakeFirestore(
            {
                "rondas/r1/members/demo-a": {"state": "active"},
                "rondas/r1/members/demo-b": {"state": "paused"},
            }
        )

        assert m.may_make_flyer(db, "r1", {"hosts": {}}, "demo-a")
        assert not m.may_make_flyer(db, "r1", {}, "demo-b")
        assert not m.may_make_flyer(db, "r1", {}, "demo-stranger")


# --- The pieces -----------------------------------------------------------------------------


class TestReadPhoto:
    def test_reads_rgb_pixels(self):
        assert m.read_photo(jpeg()).size == (400, 300)

    @pytest.mark.parametrize(
        "data", [b"x" * (m.MAX_PHOTO_BYTES + 1), b"not an image", jpeg((4001, 10))]
    )
    def test_refuses_what_is_not_a_reasonable_photo(self, data):
        with pytest.raises(m.FlyerError) as excinfo:
            m.read_photo(data)
        assert excinfo.value.code == "invalid-argument"

    def test_refuses_a_header_that_claims_a_huge_image(self, monkeypatch):
        monkeypatch.setattr(Image, "MAX_IMAGE_PIXELS", 1000)

        with pytest.raises(m.FlyerError) as excinfo:
            m.read_photo(jpeg())
        assert excinfo.value.code == "invalid-argument"

    def test_scales_only_down(self):
        image = Image.new("RGB", (2560, 1000))

        assert m.scaled(image, 1280).size == (1280, 500)
        assert m.scaled(image, 4000) is image


class TestFindObjects:
    class Sam:
        def __init__(self, answers: dict[str, list[m.Mask]]):
            self.answers, self.asked = answers, []

        async def segment(self, png: bytes, concept: str) -> list[m.Mask]:
            self.asked.append(concept)
            return self.answers.get(concept, [])

    def test_tries_each_phrase_until_one_finds_something_usable(self):
        sam = self.Sam(
            {
                "thermos": [mask(0, 0, 2, 2)],  # a speck
                "vacuum flask": [mask()],
                "gourd": [
                    mask(confidence=0.2),
                    mask(confidence=0.9),
                    mask(0, 0, 100, 100),
                    mask(),
                ],
            }
        )

        found = asyncio.run(m.find_objects(b"", 400 * 300, sam))

        assert sam.asked.count("thermos") == 1
        assert "playing cards" in sam.asked
        assert found[0] == mask()
        assert [f.confidence for f in found[1:]] == [0.9, 0.2, None]

    def test_skips_empty_and_huge_masks(self):
        empty = m.Mask(0, 0, 100, 100, 1, 1, bytes([0]))

        assert not m.usable(empty, 400 * 300)
        assert not m.usable(mask(0, 0, 400, 300), 400 * 300)
        assert m.usable(mask(), 400 * 300)


class TestCutout:
    def test_masks_the_box_onto_a_transparent_ground(self):
        photo = Image.open(io.BytesIO(jpeg())).convert("RGB")

        piece = m.cutout(photo, mask())

        assert piece.size == (80, 180)
        assert piece.mode == "RGBA"
        assert piece.getpixel((2, 177))[3] < 30  # the mask's empty quarter, bottom left
        assert piece.getpixel((2, 2))[3] > 225

    def test_keeps_a_box_that_spills_over_inside_the_photo(self):
        photo = Image.new("RGB", (100, 100))

        assert m.cutout(photo, mask(-10, 50, 120, 130)).size == (100, 50)


class TestWords:
    def test_names_the_ronda_in_one_line(self):
        assert m.ronda_line(RONDA) == "Mate en la rambla · los jueves de tarde · Solymar Norte"

    def test_leaves_out_what_the_ronda_does_not_hold(self):
        assert m.ronda_line({"pretext": "truco", "slot": {"day": "sun"}}) == "Truco · los domingos"
        assert m.ronda_line({}) == ""

    def test_paints_the_pretexts_place_with_no_people_and_no_text(self):
        assert "coastal promenade" in m.background_prompt("mate")
        assert "pitch" in m.background_prompt("futbol5")
        assert m.background_prompt(None) == m.background_prompt("mate")
        assert "No people, no text" in m.background_prompt("truco")

    def test_draws_the_qr_module_by_module(self):
        url = "https://ronda-uy.firebaseapp.com/f/flyer-1"
        qr = segno.make(url, error="m")
        modules = qr.symbol_size(scale=1, border=2)[0]

        image = m.qr_image(url, modules * 10)

        for row, line in enumerate(qr.matrix):
            for column, dark in enumerate(line):
                pixel = image.getpixel(((column + 2) * 10 + 5, (row + 2) * 10 + 5))
                assert (pixel == m.INK) == bool(dark)


class TestCompose:
    def test_draws_a_print_sized_jpeg(self):
        background = Image.open(io.BytesIO(png()))
        pieces = [Image.new("RGBA", (300, 600), (40, 40, 40, 255)) for _ in range(2)]

        flyer = Image.open(io.BytesIO(m.compose(background, pieces, "Truco", "https://x/f/1")))

        assert flyer.format == "JPEG"
        assert flyer.size == m.FLYER_SIZE
        assert not flyer.getexif()
        assert flyer.getpixel((600, 30))[0] > 240  # the paper band at the top

    def test_fits_many_wide_things_in_the_band(self):
        background = Image.open(io.BytesIO(png((100, 100))))
        pieces = [Image.new("RGBA", (900, 300), (40, 40, 40, 255)) for _ in range(5)]

        assert m.compose(background, pieces, "", "https://x/f/1")[:2] == b"\xff\xd8"


# --- The callable's work --------------------------------------------------------------------


class FakeSam:
    def __init__(self, masks: list[m.Mask] | None = None, error: Exception | None = None):
        self.masks, self.error = masks if masks is not None else [mask()], error

    async def segment(self, png: bytes, concept: str) -> list[m.Mask]:
        if self.error:
            raise self.error
        return self.masks if concept == "thermos" else []


class FakePainter:
    def __init__(self):
        self.prompts: list[str] = []

    async def paint(self, prompt: str) -> bytes:
        self.prompts.append(prompt)
        return png()


@pytest.fixture
def world():
    db = FakeFirestore({"rondas/r1": dict(RONDA), "rondas/r2": {"pretext": "truco"}})
    bucket = FakeBucket({PHOTO: StoredObject(jpeg(), NOW)})
    return SimpleNamespace(db=db, bucket=bucket, sam=FakeSam(), painter=FakePainter())


def make(world, data=None, *, uid=UID, **models):
    return m.make_mate_flyer(
        uid=uid,
        data={"rondaId": "r1", "photoPath": PHOTO} if data is None else data,
        db=world.db,
        bucket=world.bucket,
        api_key="test-key",
        now=NOW,
        segmenter=models.get("segmenter", world.sam),
        painter=models.get("painter", world.painter),
    )


class TestMakeMateFlyer:
    def test_stores_the_flyer_and_its_document_and_deletes_the_photo(self, world):
        answer = make(world)

        flyer_id = answer["flyerId"]
        assert answer == {
            "flyerId": flyer_id,
            "imagePath": f"flyers/{UID}/{flyer_id}.jpg",
            "landingUrl": f"https://ronda-uy.firebaseapp.com/f/{flyer_id}",
        }
        assert world.db.documents[f"flyers/{flyer_id}"] == {
            "kind": "mate",
            "rondaId": "r1",
            "barrio": "solymar-norte",
            "createdBy": UID,
            "imagePath": f"flyers/{UID}/{flyer_id}.jpg",
            "scans": 0,
            "createdAt": NOW,
        }
        stored = world.bucket.objects[f"flyers/{UID}/{flyer_id}.jpg"].data
        assert Image.open(io.BytesIO(stored)).size == m.FLYER_SIZE
        assert PHOTO not in world.bucket.objects
        assert "coastal promenade" in world.painter.prompts[0]

    @pytest.mark.parametrize(
        "data",
        [
            None,
            "flyer",
            {"photoPath": PHOTO},
            {"rondaId": "a/b", "photoPath": PHOTO},
            {"rondaId": "r1", "photoPath": "audio/demo-host/x.wav"},
            {"rondaId": "r1"},
        ],
    )
    def test_refuses_bad_arguments_and_touches_nothing(self, world, data):
        with pytest.raises(m.FlyerError) as excinfo:
            m.make_mate_flyer(
                uid=UID,
                data=data,
                db=world.db,
                bucket=world.bucket,
                api_key="k",
                now=NOW,
                segmenter=world.sam,
                painter=world.painter,
            )
        assert excinfo.value.code == "invalid-argument"
        assert PHOTO in world.bucket.objects

    def test_refuses_someone_elses_photo_without_deleting_it(self, world):
        with pytest.raises(m.FlyerError) as excinfo:
            make(world, uid="demo-other")
        assert excinfo.value.code == "permission-denied"
        assert PHOTO in world.bucket.objects

    @pytest.mark.parametrize(
        ("data", "code"),
        [
            ({"rondaId": "nope", "photoPath": PHOTO}, "not-found"),
            ({"rondaId": "r2", "photoPath": PHOTO}, "permission-denied"),
        ],
    )
    def test_refuses_a_missing_ronda_or_a_non_host_and_deletes_the_photo(self, world, data, code):
        with pytest.raises(m.FlyerError) as excinfo:
            make(world, data)
        assert excinfo.value.code == code
        assert PHOTO not in world.bucket.objects
        assert not [p for p in world.db.documents if p.startswith("flyers/")]

    def test_takes_an_id_the_landing_reads_and_never_one_already_taken(self, world, monkeypatch):
        import cerca_tuyo

        world.db.documents["flyers/22222222"] = {"kind": "tearOff"}
        draws = iter("2" * m.ID_LENGTH + "abcdefgh")
        monkeypatch.setattr(m.secrets, "choice", lambda _: next(draws))

        flyer_id = make(world)["flyerId"]

        assert flyer_id == "abcdefgh"
        assert cerca_tuyo.FLYER_ID.fullmatch(flyer_id)
        assert world.db.documents["flyers/22222222"] == {"kind": "tearOff"}

    def test_its_qr_opens_a_landing_that_shows_the_rondas_barrio(self, world):
        import json

        import cerca_tuyo

        world.db.documents["cerca/solymar-norte"] = {"rondas": [], "waiting": [], "updatedAt": NOW}
        answer = make(world)

        status, body = cerca_tuyo.landing(world.db, "GET", f"/api/f/{answer['flyerId']}", NOW)

        assert answer["landingUrl"].endswith(f"/f/{answer['flyerId']}")
        assert status == 200
        assert json.loads(body)["kind"] == "mate"
        assert json.loads(body)["barrio"] == "solymar-norte"
        assert "r1" not in body and UID not in body

    def test_answers_unavailable_when_no_id_is_free(self, world, monkeypatch):
        world.db.documents["flyers/22222222"] = {"kind": "tearOff"}
        monkeypatch.setattr(m.secrets, "choice", lambda _: "2")

        with pytest.raises(m.FlyerError) as excinfo:
            make(world)
        assert excinfo.value.code == "unavailable"
        assert PHOTO not in world.bucket.objects

    def test_answers_failed_precondition_when_nothing_was_found(self, world):
        with pytest.raises(m.FlyerError) as excinfo:
            make(world, segmenter=FakeSam([]))
        assert excinfo.value.code == "failed-precondition"
        assert PHOTO not in world.bucket.objects

    def test_answers_unavailable_when_a_model_fails(self, world):
        with pytest.raises(m.FlyerError) as excinfo:
            make(world, segmenter=FakeSam(error=m.ModelUnavailable("sam")))
        assert excinfo.value.code == "unavailable"

    def test_answers_not_found_when_the_photo_is_gone(self, world):
        from google.api_core.exceptions import NotFound

        world.bucket.objects.clear()

        with pytest.raises(NotFound):
            make(world)

    def test_runs_on_the_meta_clients_by_default(self, world, monkeypatch):
        text = "<0f>" + sam_line(1, (150, 80, 229, 259), [1, 1, 1, 1], 2, 2) + "\n"
        client = FakeAsyncOpenAI(text)
        built: dict = {}

        def open_ai(**kwargs):
            built.update(kwargs)
            return client

        transport = httpx.MockTransport(lambda _: painted(png()))
        async_client = httpx.AsyncClient
        monkeypatch.setattr(m, "AsyncOpenAI", open_ai)
        monkeypatch.setattr(m.httpx, "AsyncClient", lambda: async_client(transport=transport))

        answer = m.make_mate_flyer(
            uid=UID,
            data={"rondaId": "r1", "photoPath": PHOTO},
            db=world.db,
            bucket=world.bucket,
            api_key="test-key",
            now=NOW,
        )

        assert answer["flyerId"]
        assert built["base_url"] == "https://api.meta.ai/v1"
        assert built["api_key"] == "test-key"
        assert client.closed
        assert {call["input"][0]["content"][0]["text"] for call in client.calls} >= {"thermos"}
