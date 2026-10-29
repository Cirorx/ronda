"""Reads a spoken sign-up: the WAV check, Voice Transcribe, then Spark 1.3 into fields.

`read_voice_note` is the whole of the `extract` callable except Firebase: `main.py` passes the
Storage blob, the user document and the key, and the note is deleted here once it was read,
whatever happened while reading it. Logs carry ids, sizes and timings only: never a transcript,
a name or a field (`docs/STACK.md` § Security).
"""

import io
import json
import logging
import re
import time
import wave
from collections.abc import Callable
from enum import StrEnum
from typing import Any, Protocol

import httpx
from pydantic import BaseModel, ConfigDict

META_BASE = "https://api.meta.ai/v1"
TRANSCRIBE_MODEL = "muse-voice-transcribe-1.0"
FIELDS_MODEL = "muse-spark-1.3"

# The app stops recording at 60 s; a little slack for the header and the last buffer.
MAX_SECONDS = 65
MIN_SECONDS = 1
MAX_BYTES = 3_000_000

log = logging.getLogger(__name__)

# The ids the app and the solver store (packages/profile_repository/lib/src/models/).
BARRIOS = {
    "shangrila": "Shangrilá",
    "san-jose-de-carrasco": "San José de Carrasco",
    "lagomar-sur": "Lagomar Sur",
    "lagomar-norte": "Lagomar Norte",
    "solymar-sur": "Solymar Sur",
    "solymar-norte": "Solymar Norte",
    "lomas-de-solymar": "Lomas de Solymar",
    "el-pinar-sur": "El Pinar Sur",
    "el-pinar-norte": "El Pinar Norte",
}
AGE_BANDS = ["18-29", "30-39", "40-49", "50-59", "60-69", "70-79", "80+"]
PRETEXTS = {
    "mate": "mate en la rambla",
    "truco": "truco",
    "futbol5": "fútbol 5",
    "caminata": "caminata",
}
BRINGS = {
    "pan": "pan",
    "yerba": "yerba",
    "termo": "termo",
    "sillas": "sillas",
    "enseno-truco": "enseño truco",
    "tengo-ganas": "tengo ganas (no lleva nada, viene y listo)",
}
DAYS = ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
BANDS = ["morning", "afternoon", "evening"]
UNKNOWN = "unknown"

# Words Voice Transcribe should expect: barrios, pretexts and what people bring.
KEYWORDS = [
    *BARRIOS.values(),
    "Solymar",
    "Lagomar",
    "El Pinar",
    "rambla",
    "mate",
    "truco",
    "fútbol 5",
    "caminata",
    "termo",
    "yerba",
    "bizcochos",
]

NOTE_PATH = re.compile(r"^audio/(?P<uid>[A-Za-z0-9_-]{1,128})/(?P<id>[A-Za-z0-9_-]{1,64})\.wav$")


def _enum(name: str, values: list[str]) -> type[StrEnum]:
    return StrEnum(name, {value.replace("-", "_").replace("+", "_plus"): value for value in values})


AgeBand = _enum("AgeBand", [*AGE_BANDS, UNKNOWN])
Barrio = _enum("Barrio", [*BARRIOS, UNKNOWN])
Pretext = _enum("Pretext", list(PRETEXTS))
Bring = _enum("Bring", list(BRINGS))
SlotId = _enum("SlotId", [f"{day}-{band}" for day in DAYS for band in BANDS])


class Signup(BaseModel):
    """What Spark 1.3 fills. Strict: every key required, `unknown` or empty when not said."""

    model_config = ConfigDict(extra="forbid")
    first_name: str
    age_band: AgeBand
    barrio: Barrio
    pretexts: list[Pretext]
    slots: list[SlotId]
    brings: list[Bring]


INSTRUCTIONS = f"""Sos el lector de inscripciones de Ronda: grupos semanales de vecinos.
Te llega la transcripción de un audio en que una persona se presenta. Completá los campos solo
con lo que dijo. No inventes: si algo no lo dijo o no queda claro, dejá "unknown" o la lista
vacía.

- first_name: solo el nombre de pila, como lo dijo. Vacío si no lo dijo.
- age_band: la década. "sesenta y pico" o "tengo 64" es 60-69. Menos de 18 es unknown.
- barrio: uno de estos: {", ".join(f"{k} ({v})" for k, v in BARRIOS.items())}.
  Si dice solo "Solymar", "Lagomar" o "El Pinar" sin Norte o Sur, unknown.
- pretexts: lo que le gustaría hacer: {", ".join(f"{k} ({v})" for k, v in PRETEXTS.items())}.
- slots: día y franja, como día-franja. Días: mon lun, tue mar, wed mié, thu jue, fri vie,
  sat sáb, sun dom. Franjas: morning (mañana, de 9 a 12), afternoon (tarde o tardecita, de 14
  a 18), evening (noche, de 19 a 21). "Los fines de semana" son sat y sun; "entre semana", de
  mon a fri. Sin franja dicha, las tres.
- brings: lo que puede llevar o enseñar: {", ".join(f"{k} ({v})" for k, v in BRINGS.items())}.
  Algo parecido cuenta ("un termo con agua" es termo). Si no puede llevar nada, tengo-ganas.
"""


class BadVoiceNote(ValueError):
    """The note can't be read: not the WAV the app records, too short, too long, or silent."""


class ModelUnavailable(RuntimeError):
    """A Meta model kept failing; the person can try again."""


class TermsMissing(PermissionError):
    """`users/{uid}.terms` is missing: no voice is read before the conditions are accepted."""


class Blob(Protocol):
    """The part of `google.cloud.storage.Blob` this module uses."""

    def download_as_bytes(self) -> bytes: ...

    def delete(self) -> None: ...


def check_wav(audio: bytes) -> float:
    """Returns the note's length in seconds, or raises `BadVoiceNote` when Voice Transcribe
    can't take it: RIFF/WAVE, mono, 16-bit PCM, 16 or 24 kHz, one to sixty-odd seconds."""
    if len(audio) > MAX_BYTES:
        raise BadVoiceNote("too large")
    try:
        with wave.open(io.BytesIO(audio)) as note:
            channels, width, rate = note.getnchannels(), note.getsampwidth(), note.getframerate()
            frames = note.getnframes()
    except (wave.Error, EOFError) as error:
        raise BadVoiceNote("not a PCM WAV") from error
    if channels != 1 or width != 2 or rate not in (16000, 24000):
        raise BadVoiceNote(
            f"needs mono 16-bit 16 or 24 kHz, got {channels} ch {width * 8} bit {rate} Hz"
        )
    seconds = frames / rate
    if not MIN_SECONDS <= seconds <= MAX_SECONDS:
        raise BadVoiceNote(f"{seconds:.1f} s is outside {MIN_SECONDS}-{MAX_SECONDS} s")
    return seconds


def transcribe(audio: bytes, *, api_key: str, http: httpx.Client, attempts: int = 3) -> str:
    """The note's words from Voice Transcribe, biased to Spanish and Ronda's place names.

    Retries 429 and 5xx with a short backoff; raises `ModelUnavailable` when they keep coming.
    """
    request = {
        "model": TRANSCRIBE_MODEL,
        "audioEncoding": "WAV",
        "mode": "PUSH_TO_TALK",
        "languageBias": ["Spanish"],
        "keywords": KEYWORDS,
    }
    for attempt in range(attempts):
        response = http.post(
            f"{META_BASE}/asr/transcribe",
            headers={"Authorization": f"Bearer {api_key}"},
            files={
                "request": (None, json.dumps(request), "application/json"),
                "audio": ("note.wav", audio, "audio/wav"),
            },
            timeout=60,
        )
        if response.status_code == 200:
            return str(response.json().get("transcript") or "").strip()
        log.warning("transcribe HTTP %s (attempt %s)", response.status_code, attempt + 1)
        if response.status_code != 429 and response.status_code < 500:
            break
        time.sleep(0.5 * 2**attempt)
    raise ModelUnavailable(f"transcribe HTTP {response.status_code}")


def read_fields(transcript: str, *, client: Any) -> dict[str, Any]:
    """The sign-up fields in the app's wire shape, from Spark 1.3's strict `Signup`.

    `client` is an `openai.OpenAI` on the Meta base URL. Unknown becomes `None`, lists keep the
    order the person said them in, without repeats.
    """
    try:
        response = client.chat.completions.parse(
            model=FIELDS_MODEL,
            response_format=Signup,
            reasoning_effort="low",
            messages=[
                {"role": "system", "content": INSTRUCTIONS},
                {"role": "user", "content": transcript},
            ],
        )
    except Exception as error:  # the SDK's errors share no useful base with httpx's
        raise ModelUnavailable(type(error).__name__) from error
    signup = response.choices[0].message.parsed
    if signup is None:
        raise ModelUnavailable("no parsed signup")
    return {
        "firstName": signup.first_name.strip()[:30] or None,
        "ageBand": None if signup.age_band == UNKNOWN else str(signup.age_band),
        "barrio": None if signup.barrio == UNKNOWN else str(signup.barrio),
        "pretexts": list(dict.fromkeys(str(p) for p in signup.pretexts)),
        "slots": list(dict.fromkeys(str(s) for s in signup.slots)),
        "brings": list(dict.fromkeys(str(b) for b in signup.brings)),
    }


def note_uid(path: object) -> str:
    """The uid in `audio/{uid}/{id}.wav`, or `BadVoiceNote` for any other path."""
    if not isinstance(path, str) or not (match := NOTE_PATH.match(path)):
        raise BadVoiceNote("not a voice note path")
    return match["uid"]


def read_voice_note(
    *,
    uid: str,
    path: object,
    user: dict[str, Any] | None,
    blob: Callable[[str], Blob],
    api_key: str,
    http: httpx.Client,
    client: Any,
) -> dict[str, Any]:
    """The `extract` callable: checks, reads and deletes the note at `path`.

    `user` is `users/{uid}` (or `None`); `blob(path)` opens the Storage object. The note is
    deleted in every case once it was found, so it never outlives the call.
    """
    if note_uid(path) != uid:
        raise PermissionError("not your voice note")
    if not (user or {}).get("terms"):
        raise TermsMissing(uid)
    note = blob(str(path))
    started = time.perf_counter()
    try:
        audio = note.download_as_bytes()
        seconds = check_wav(audio)
        transcript = transcribe(audio, api_key=api_key, http=http)
        heard = time.perf_counter()
        if not transcript:
            raise BadVoiceNote("nothing heard")
        fields = read_fields(transcript, client=client)
        log.info(
            "extract %s: %d bytes, %.1f s of audio, transcribe %d ms, fields %d ms",
            path,
            len(audio),
            seconds,
            (heard - started) * 1000,
            (time.perf_counter() - heard) * 1000,
        )
        return fields
    finally:
        try:
            note.delete()
        except Exception as error:  # a missing note; the 1-day lifecycle rule is the backstop
            log.warning("extract %s: delete failed (%s)", path, type(error).__name__)
