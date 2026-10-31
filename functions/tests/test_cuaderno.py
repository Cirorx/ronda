"""cuaderno without the network: httpx's MockTransport for Voice Transcribe and Muse Image, a
stub client for Spark 1.3, an in-memory blob for Storage. The privacy claim is tested at the
end: `make_postcard` is handed no database and no bucket, and a database and a bucket that fail
on any use see nothing of a whole `read_line` and `make_postcard` round trip."""

import asyncio
import base64
import io

import httpx
import pytest
from PIL import Image

import cuaderno as c
from tests.fake_firestore import FakeFirestore
from tests.fake_storage import FakeBucket, StoredObject
from tests.test_voice_signup import FakeBlob, http_answering, spark_returning, transcript, wav

UID = "uid-123"
PATH = f"audio/{UID}/note-1.wav"
USER = {"terms": {"version": "2026-10-27"}}
LINES = ["El jacarandá de la esquina floreció.", "Hoy se vio el río clarito."]


def png(size=(1024, 1536)) -> bytes:
    out = io.BytesIO()
    Image.new("RGB", size, (120, 170, 200)).save(out, format="PNG")
    return out.getvalue()


class Painter:
    def __init__(self, painted: bytes | Exception = b""):
        self.painted, self.prompts = painted or png(), []

    async def paint(self, prompt: str) -> bytes:
        self.prompts.append(prompt)
        if isinstance(self.painted, Exception):
            raise self.painted
        return self.painted


def things(*words: str) -> c.Things:
    return c.Things(things=list(words))


def code_of(excinfo) -> str:
    return excinfo.value.code


class TestCleanLines:
    def test_strips_each_line(self):
        assert c.clean_lines({"lines": ["  uno  ", "dos"]}) == ["uno", "dos"]

    @pytest.mark.parametrize(
        "data",
        [
            None,
            "lines",
            {},
            {"lines": "uno"},
            {"lines": []},
            {"lines": ["x"] * (c.MAX_LINES + 1)},
            {"lines": ["   "]},
            {"lines": [3]},
            {"lines": ["x" * (c.MAX_LINE_CHARS + 1)]},
        ],
    )
    def test_refuses_anything_that_is_not_a_few_short_lines(self, data):
        with pytest.raises(c.PostcardError) as excinfo:
            c.clean_lines(data)
        assert code_of(excinfo) == "invalid-argument"


class TestReadThings:
    def test_keeps_objects_and_places(self):
        client, calls = spark_returning(things("Jacaranda tree  in bloom", "grey sky over river"))

        assert c.read_things(LINES, client=client) == [
            "jacaranda tree in bloom",
            "grey sky over river",
        ]
        sent = calls[0]
        assert sent["response_format"] is c.Things
        assert sent["messages"][1]["content"] == "- " + "\n- ".join(LINES)

    @pytest.mark.parametrize(
        "phrase",
        [
            "old woman on a bench",
            "Graciela's house",
            "street 1234",
            "grandmother waving",
            "smiling face",
            "árbol en flor",
            "a very long phrase with too many words in it",
            "",
            "someone walking",
            "the neighbours' dog",
        ],
    )
    def test_drops_anything_personal_numeric_or_off_the_alphabet(self, phrase):
        client, _ = spark_returning(things(phrase, "park bench"))

        assert c.read_things(LINES, client=client) == ["park bench"]

    def test_keeps_each_thing_once_and_at_most_five(self):
        client, _ = spark_returning(
            things("tree", "Tree", "bench", "wall", "river", "sky", "street", "dog")
        )

        assert c.read_things(LINES, client=client) == ["tree", "bench", "wall", "river", "sky"]

    def test_says_when_spark_fails(self):
        client, _ = spark_returning(error=RuntimeError("boom"))

        with pytest.raises(c.ModelUnavailable, match="RuntimeError"):
            c.read_things(LINES, client=client)

    def test_says_when_spark_parsed_nothing(self):
        client, _ = spark_returning(None)

        with pytest.raises(c.ModelUnavailable, match="no parsed"):
            c.read_things(LINES, client=client)


class TestPromptAndImage:
    def test_the_prompt_is_built_from_the_words_alone(self):
        prompt = c.postcard_prompt(["jacaranda tree", "river"])

        assert "jacaranda tree; river" in prompt
        assert "No people" in prompt

    def test_the_postcard_is_a_modest_jpeg(self):
        jpeg = c.to_jpeg(png())

        with Image.open(io.BytesIO(jpeg)) as image:
            assert image.format == "JPEG"
            assert max(image.size) == c.POSTCARD_SIDE

    def test_a_small_painting_is_not_scaled_up(self):
        with Image.open(io.BytesIO(c.to_jpeg(png((300, 200))))) as image:
            assert image.size == (300, 200)

    def test_something_that_is_not_an_image_is_a_model_failure(self):
        with pytest.raises(c.ModelUnavailable):
            c.to_jpeg(b"not an image")


class TestMakePostcard:
    def make(self, *, user=USER, data=None, client=None, painter=None):
        return c.make_postcard(
            uid=UID,
            data={"lines": LINES} if data is None else data,
            user=user,
            client=client or spark_returning(things("jacaranda tree", "river"))[0],
            painter=painter or Painter(),
        )

    def test_answers_the_postcard_inline(self):
        painter = Painter()

        answer = self.make(painter=painter)

        assert answer["mimeType"] == "image/jpeg"
        assert base64.b64decode(answer["image"])[:2] == b"\xff\xd8"
        assert "jacaranda tree; river" in painter.prompts[0]

    def test_no_line_reaches_the_image_model(self):
        painter = Painter()

        self.make(painter=painter)

        assert not any(word in painter.prompts[0] for word in ("jacarandá", "esquina", "río"))

    @pytest.mark.parametrize("user", [None, {}, {"firstName": "Ana"}])
    def test_waits_for_the_terms(self, user):
        with pytest.raises(c.PostcardError) as excinfo:
            self.make(user=user)
        assert code_of(excinfo) == "permission-denied"

    def test_refuses_bad_lines(self):
        with pytest.raises(c.PostcardError) as excinfo:
            self.make(data={"lines": []})
        assert code_of(excinfo) == "invalid-argument"

    def test_says_when_there_is_nothing_to_draw(self):
        painter = Painter()
        with pytest.raises(c.PostcardError) as excinfo:
            self.make(client=spark_returning(things("old woman"))[0], painter=painter)
        assert code_of(excinfo) == "failed-precondition"
        assert painter.prompts == []

    @pytest.mark.parametrize(
        "kwargs",
        [
            {"client": spark_returning(error=RuntimeError("x"))[0]},
            {"painter": Painter(c.ModelUnavailable("down"))},
        ],
        ids=["spark down", "image down"],
    )
    def test_says_when_a_model_fails(self, kwargs):
        with pytest.raises(c.PostcardError) as excinfo:
            self.make(**kwargs)
        assert code_of(excinfo) == "unavailable"


class TestMetaPainter:
    def paint(self, handler):
        real = httpx.AsyncClient
        painter = c.MetaPainter("key")
        original = httpx.AsyncClient
        httpx.AsyncClient = lambda: real(transport=httpx.MockTransport(handler))
        try:
            return asyncio.run(painter.paint("a prompt"))
        finally:
            httpx.AsyncClient = original

    def test_paints_with_muse_image(self):
        seen = []

        def handler(request):
            seen.append(request)
            body = {"data": [{"b64_json": base64.b64encode(png()).decode()}]}
            return httpx.Response(200, json=body)

        assert self.paint(handler) == png()
        assert seen[0].headers["authorization"] == "Bearer key"

    def test_its_failure_is_this_modules(self):
        with pytest.raises(c.ModelUnavailable):
            self.paint(lambda _: httpx.Response(400))


class TestReadLine:
    def read(self, blob, *, user=USER, path=PATH, http=None):
        return c.read_line(
            uid=UID,
            path=path,
            user=user,
            blob=lambda _: blob,
            api_key="key",
            http=http or http_answering(transcript("  El jacarandá \n floreció. ")),
        )

    def test_answers_what_was_said_and_deletes_the_note(self):
        blob = FakeBlob(wav())

        assert self.read(blob) == {"text": "El jacarandá floreció."}
        assert blob.deleted

    def test_keeps_a_line_to_one_line(self):
        blob = FakeBlob(wav())

        answer = self.read(blob, http=http_answering(transcript("a" * 500)))

        assert len(answer["text"]) == c.MAX_LINE_CHARS

    def test_refuses_another_members_note(self):
        with pytest.raises(PermissionError):
            self.read(FakeBlob(wav()), path="audio/someone-else/note-1.wav")

    @pytest.mark.parametrize("user", [None, {}])
    def test_refuses_before_the_terms_and_leaves_the_note_alone(self, user):
        blob = FakeBlob(wav())
        with pytest.raises(c.TermsMissing):
            self.read(blob, user=user)
        assert not blob.deleted

    def test_deletes_the_note_when_nothing_was_heard(self):
        blob = FakeBlob(wav())
        with pytest.raises(c.BadVoiceNote, match="nothing heard"):
            self.read(blob, http=http_answering(transcript("  ")))
        assert blob.deleted

    def test_deletes_a_note_it_could_not_use(self):
        blob = FakeBlob(b"not a wav")
        with pytest.raises(c.BadVoiceNote):
            self.read(blob)
        assert blob.deleted

    def test_a_failed_delete_does_not_hide_the_answer(self):
        blob = FakeBlob(wav(), delete_error=RuntimeError("gone"))

        assert self.read(blob) == {"text": "El jacarandá floreció."}


class TestNothingIsStored:
    """The cuaderno's lines and its postcard reach neither Firestore nor Storage."""

    def test_make_postcard_takes_no_database_and_no_bucket(self):
        import inspect

        parameters = set(inspect.signature(c.make_postcard).parameters)

        assert parameters == {"uid", "data", "user", "client", "painter"}

    def test_a_whole_round_trip_leaves_firestore_and_storage_as_they_were(self):
        documents = {"users/uid-123": dict(USER)}
        db = FakeFirestore(dict(documents))
        bucket = FakeBucket({PATH: StoredObject(wav(), None)})

        text = c.read_line(
            uid=UID,
            path=PATH,
            user=db.collection("users").document(UID).get().to_dict(),
            blob=bucket.blob,
            api_key="key",
            http=http_answering(transcript("El jacarandá floreció.")),
        )["text"]
        c.make_postcard(
            uid=UID,
            data={"lines": [text]},
            user=USER,
            client=spark_returning(things("jacaranda tree"))[0],
            painter=Painter(),
        )

        assert db.documents == documents
        assert bucket.objects == {}  # the note is gone, and nothing replaced it
