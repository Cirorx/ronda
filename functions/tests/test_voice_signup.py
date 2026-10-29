"""voice_signup without the network: httpx's MockTransport for Voice Transcribe, a stub client
for Spark 1.3 and an in-memory blob for Storage."""

import io
import json
import wave
from types import SimpleNamespace

import httpx
import pytest

import voice_signup as v

UID = "uid-123"
PATH = f"audio/{UID}/note-1.wav"
USER = {"terms": {"version": "2026-10-27"}}


def wav(seconds: float = 2.0, *, rate: int = 16000, channels: int = 1, width: int = 2) -> bytes:
    out = io.BytesIO()
    with wave.open(out, "wb") as note:
        note.setnchannels(channels)
        note.setsampwidth(width)
        note.setframerate(rate)
        note.writeframes(b"\0" * int(seconds * rate) * channels * width)
    return out.getvalue()


class FakeBlob:
    def __init__(self, audio: bytes | Exception, *, delete_error: Exception | None = None):
        self.audio, self.delete_error, self.deleted = audio, delete_error, False

    def download_as_bytes(self) -> bytes:
        if isinstance(self.audio, Exception):
            raise self.audio
        return self.audio

    def delete(self) -> None:
        self.deleted = True
        if self.delete_error:
            raise self.delete_error


def http_answering(*responses: httpx.Response, seen: list | None = None) -> httpx.Client:
    queue = list(responses)

    def handler(request: httpx.Request) -> httpx.Response:
        if seen is not None:
            seen.append(request)
        return queue.pop(0)

    return httpx.Client(transport=httpx.MockTransport(handler))


def transcript(text: str) -> httpx.Response:
    return httpx.Response(200, json={"sessionId": "s", "transcript": text, "turns": []})


def spark_returning(signup: v.Signup | None = None, *, error: Exception | None = None):
    calls = []

    def parse(**kwargs):
        calls.append(kwargs)
        if error:
            raise error
        message = SimpleNamespace(parsed=signup)
        return SimpleNamespace(choices=[SimpleNamespace(message=message)])

    completions = SimpleNamespace(parse=parse)
    return SimpleNamespace(chat=SimpleNamespace(completions=completions)), calls


GRACIELA = v.Signup(
    first_name=" Graciela ",
    age_band=v.AgeBand("60-69"),
    barrio=v.Barrio("solymar-norte"),
    pretexts=[v.Pretext("mate"), v.Pretext("truco"), v.Pretext("mate")],
    slots=[v.SlotId("tue-afternoon")],
    brings=[v.Bring("termo")],
)


@pytest.fixture(autouse=True)
def no_sleep(monkeypatch):
    monkeypatch.setattr(v.time, "sleep", lambda _: None)


class TestCheckWav:
    def test_returns_the_length_of_a_16_khz_mono_note(self):
        assert v.check_wav(wav(2.5)) == pytest.approx(2.5)

    def test_takes_24_khz(self):
        assert v.check_wav(wav(2, rate=24000)) == pytest.approx(2)

    @pytest.mark.parametrize(
        "audio",
        [
            wav(rate=44100),
            wav(channels=2),
            wav(width=1),
            wav(0.5),
            wav(66),
            b"not a wav at all",
            b"",
        ],
        ids=["44.1 kHz", "stereo", "8-bit", "too short", "too long", "garbage", "empty"],
    )
    def test_refuses_what_voice_transcribe_cannot_take(self, audio):
        with pytest.raises(v.BadVoiceNote):
            v.check_wav(audio)

    def test_refuses_anything_over_three_megabytes(self):
        with pytest.raises(v.BadVoiceNote, match="too large"):
            v.check_wav(b"\0" * (v.MAX_BYTES + 1))


class TestTranscribe:
    def test_sends_the_proven_multipart_request(self):
        seen: list[httpx.Request] = []
        http = http_answering(transcript(" Hola, soy Graciela. "), seen=seen)

        assert v.transcribe(wav(), api_key="k", http=http) == "Hola, soy Graciela."
        request = seen[0]
        assert request.url == "https://api.meta.ai/v1/asr/transcribe"
        assert request.headers["Authorization"] == "Bearer k"
        body = request.read()
        assert b'"languageBias": ["Spanish"]' in body
        assert b'"model": "muse-voice-transcribe-1.0"' in body
        assert b"Solymar Norte" in body
        assert b'name="audio"; filename="note.wav"' in body

    def test_retries_429_and_5xx(self):
        http = http_answering(httpx.Response(429), httpx.Response(503), transcript("hola"))

        assert v.transcribe(wav(), api_key="k", http=http) == "hola"

    def test_gives_up_after_the_last_attempt(self):
        http = http_answering(*(httpx.Response(500) for _ in range(3)))

        with pytest.raises(v.ModelUnavailable, match="500"):
            v.transcribe(wav(), api_key="k", http=http)

    def test_does_not_retry_a_client_error(self):
        seen: list[httpx.Request] = []
        http = http_answering(httpx.Response(400), seen=seen)

        with pytest.raises(v.ModelUnavailable, match="400"):
            v.transcribe(wav(), api_key="k", http=http)
        assert len(seen) == 1

    def test_reads_a_missing_transcript_as_empty(self):
        http = http_answering(httpx.Response(200, json={"turns": []}))

        assert v.transcribe(wav(), api_key="k", http=http) == ""


class TestReadFields:
    def test_returns_the_wire_shape_without_repeats(self):
        client, calls = spark_returning(GRACIELA)

        assert v.read_fields("Hola", client=client) == {
            "firstName": "Graciela",
            "ageBand": "60-69",
            "barrio": "solymar-norte",
            "pretexts": ["mate", "truco"],
            "slots": ["tue-afternoon"],
            "brings": ["termo"],
        }
        assert calls[0]["model"] == "muse-spark-1.3"
        assert calls[0]["response_format"] is v.Signup
        assert calls[0]["messages"][1] == {"role": "user", "content": "Hola"}

    def test_turns_unknown_and_empty_into_none(self):
        client, _ = spark_returning(
            v.Signup(
                first_name="  ",
                age_band=v.AgeBand(v.UNKNOWN),
                barrio=v.Barrio(v.UNKNOWN),
                pretexts=[],
                slots=[],
                brings=[],
            )
        )

        fields = v.read_fields("Hola", client=client)

        assert fields["firstName"] is None
        assert fields["ageBand"] is None
        assert fields["barrio"] is None

    def test_keeps_a_first_name_within_thirty_characters(self):
        client, _ = spark_returning(GRACIELA.model_copy(update={"first_name": "x" * 40}))

        assert v.read_fields("Hola", client=client)["firstName"] == "x" * 30

    def test_reports_a_failing_model(self):
        client, _ = spark_returning(error=TimeoutError())

        with pytest.raises(v.ModelUnavailable, match="TimeoutError"):
            v.read_fields("Hola", client=client)

    def test_reports_a_refusal(self):
        client, _ = spark_returning(None)

        with pytest.raises(v.ModelUnavailable):
            v.read_fields("Hola", client=client)


class TestSchema:
    def test_is_the_strict_subset_meta_enforces(self):
        schema = v.Signup.model_json_schema()

        assert schema["additionalProperties"] is False
        assert set(schema["required"]) == set(schema["properties"])
        assert "oneOf" not in json.dumps(schema)

    def test_lists_every_id_the_app_stores(self):
        assert {s.value for s in v.SlotId} == {f"{d}-{b}" for d in v.DAYS for b in v.BANDS}
        assert len(v.SlotId) == 21
        assert {a.value for a in v.AgeBand} == {*v.AGE_BANDS, v.UNKNOWN}


class TestNoteUid:
    def test_reads_the_uid_of_a_note_path(self):
        assert v.note_uid(PATH) == UID

    @pytest.mark.parametrize(
        "path",
        [None, 3, "audio/uid/../x.wav", "audio/uid/x.mp3", "photos/uid/x.wav", f"/{PATH}"],
    )
    def test_refuses_any_other_path(self, path):
        with pytest.raises(v.BadVoiceNote):
            v.note_uid(path)


class TestReadVoiceNote:
    def read(self, blob: FakeBlob, *, user=USER, path=PATH, http=None, client=None):
        return v.read_voice_note(
            uid=UID,
            path=path,
            user=user,
            blob=lambda _: blob,
            api_key="k",
            http=http or http_answering(transcript("Hola, soy Graciela")),
            client=client or spark_returning(GRACIELA)[0],
        )

    def test_returns_the_fields_and_deletes_the_note(self):
        blob = FakeBlob(wav())

        fields = self.read(blob)

        assert fields["firstName"] == "Graciela"
        assert blob.deleted

    def test_refuses_before_the_terms_and_leaves_the_note_alone(self):
        blob = FakeBlob(wav())

        with pytest.raises(v.TermsMissing):
            self.read(blob, user={"firstName": "Graciela"})
        with pytest.raises(v.TermsMissing):
            self.read(blob, user=None)
        assert not blob.deleted

    def test_refuses_someone_elses_note(self):
        blob = FakeBlob(wav())

        with pytest.raises(PermissionError):
            self.read(blob, path="audio/other-uid/note-1.wav")
        assert not blob.deleted

    def test_deletes_a_note_it_cannot_read(self):
        blob = FakeBlob(wav(channels=2))

        with pytest.raises(v.BadVoiceNote):
            self.read(blob)
        assert blob.deleted

    def test_deletes_a_silent_note(self):
        blob = FakeBlob(wav())

        with pytest.raises(v.BadVoiceNote, match="nothing heard"):
            self.read(blob, http=http_answering(transcript("")))
        assert blob.deleted

    def test_deletes_the_note_when_a_model_fails(self):
        blob = FakeBlob(wav())

        with pytest.raises(v.ModelUnavailable):
            self.read(blob, client=spark_returning(error=RuntimeError())[0])
        assert blob.deleted

    def test_passes_on_a_missing_note_after_trying_to_delete_it(self):
        blob = FakeBlob(FileNotFoundError(), delete_error=FileNotFoundError())

        with pytest.raises(FileNotFoundError):
            self.read(blob)
        assert blob.deleted
