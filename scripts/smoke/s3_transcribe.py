# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["httpx>=0.28"]
# ///
"""Smoke test 3: Voice Transcribe on a 16 kHz mono WAV, with and without `languageBias`.

    uv run scripts/smoke/s3_transcribe.py note.wav

Make a WAV with `ffmpeg -i note.m4a -ac 1 -ar 16000 -sample_fmt s16 note.wav`. Voice notes of
real people never go in git; keep them outside the repo.
"""

import json
import sys
import wave

import httpx
from _env import META_BASE, Timer, key

KEYWORDS = ["Solymar", "El Pinar", "truco", "termo", "bizcochos"]
path = sys.argv[1]
with wave.open(path) as w:
    seconds = w.getnframes() / w.getframerate()
    assert w.getnchannels() == 1 and w.getsampwidth() == 2, "needs mono 16-bit PCM"
    assert w.getframerate() in (16000, 24000), "needs 16 or 24 kHz"
print(f"{path}: {seconds:.1f} s")

for bias in (["Spanish"], None):
    request = {
        "model": "muse-voice-transcribe-1.0",
        "audioEncoding": "WAV",
        "mode": "PUSH_TO_TALK",
        "keywords": KEYWORDS,
        **({"languageBias": bias} if bias else {}),
    }
    with open(path, "rb") as audio, Timer() as t:
        r = httpx.post(
            f"{META_BASE}/asr/transcribe",
            headers={"Authorization": f"Bearer {key('MODEL_API_KEY')}"},
            files={
                "request": (None, json.dumps(request), "application/json"),
                "audio": ("note.wav", audio, "audio/wav"),
            },
            timeout=120,
        )
    label = "bias Spanish" if bias else "auto-detect "
    print(f"{label} HTTP {r.status_code} {t.s} s: {r.text[:400]}")
