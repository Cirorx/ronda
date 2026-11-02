"""Smoke test 10: the sign-up with all 71 barrios, through the functions' own code
(functions/voice_signup.py): Spark 1.3 fills the strict `Signup`, whose barrio enum has 72
values, from typed transcripts, and, given a WAV, Voice Transcribe takes the whole keyword list.

    functions/venv/bin/python scripts/smoke/s10_barrios.py [note.wav]

Make an invented note on a Mac with `say -v Paulina "Hola, soy Ana, vivo en Barrio Sur" -o
note.aiff && afconvert -f WAVE -d LEI16@16000 -c 1 note.aiff note.wav`. Reads MODEL_API_KEY from
the environment or the repo's `.env` and never prints it. Five Spark calls a run, plus one
transcription and one more Spark call with a WAV.
"""

import pathlib
import sys

import httpx

HERE = pathlib.Path(__file__).resolve()
sys.path.insert(0, str(HERE.parents[2] / "functions"))
sys.path.insert(0, str(HERE.parent))

import voice_signup as v  # noqa: E402
from _env import META_BASE, Timer, key  # noqa: E402
from openai import OpenAI  # noqa: E402

# Invented for the smoke test: no real people.
TRANSCRIPTS = {
    "Hola, soy Ana, tengo cuarenta y pico, vivo en Barrio Sur. Me gusta el truco.": "barrio-sur",
    "Soy Raúl, vivo en Bella Vista, cerca del Prado. Los sábados de tarde.": "capurro-bella-vista",
    "Me llamo Elsa, de Malvín Norte, setenta y dos años, caminata.": "malvin-norte",
    "Hola, Mirta, de Shangrilá, mate en la rambla los domingos.": "shangrila",
    "Soy Beto, vivo en Colón, juego al fútbol 5.": None,
}

api_key = key("MODEL_API_KEY")
client = OpenAI(base_url=META_BASE, api_key=api_key)
print(f"{len(v.BARRIOS)} barrios, {len(list(v.Barrio))} enum values, {len(v.KEYWORDS)} keywords")
failures = 0
for transcript, expected in TRANSCRIPTS.items():
    with Timer() as t:
        fields = v.read_fields(transcript, client=client)
    ok = fields["barrio"] == expected
    failures += not ok
    print(f"{t.s} s  {'ok ' if ok else 'BAD'} {fields['barrio']!r} (expected {expected!r})")

if len(sys.argv) > 1:
    audio = pathlib.Path(sys.argv[1]).read_bytes()
    print(f"{sys.argv[1]}: {v.check_wav(audio):.1f} s")
    with httpx.Client() as http, Timer() as t:
        transcript = v.transcribe(audio, api_key=api_key, http=http)
    print(f"transcribe {t.s} s: {transcript}")
    with Timer() as t:
        fields = v.read_fields(transcript, client=client)
    print(f"{t.s} s  barrio {fields['barrio']!r}")

sys.exit(1 if failures else 0)
