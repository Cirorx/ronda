"""The two ways Ronda reads a note with Voice Transcribe, timed: realtime over the WebSocket
(as `relay/` does) and batch over `POST /v1/asr/transcribe` (as `extract` does).

Keys only through `scripts/smoke/_env.py` `key()`, which never prints them.
"""

import asyncio
import json
import sys
import time
import wave
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / "scripts" / "smoke"))

REALTIME = "wss://api.meta.ai/v1/asr/realtime"
BATCH = "https://api.meta.ai/v1/asr/transcribe"
MODEL = "muse-voice-transcribe-1.0"
FRAME_MS = 80
KEYWORDS = ["Solymar", "El Pinar", "Lagomar", "truco", "termo", "bizcochos", "rambla"]


def read_wav(path: Path) -> tuple[bytes, int]:
    with wave.open(str(path)) as w:
        assert w.getnchannels() == 1 and w.getsampwidth() == 2 and w.getframerate() == 16000
        return w.readframes(w.getnframes()), w.getframerate()


async def stream_realtime(path: Path) -> dict:
    """Streams the WAV at real time; returns the events with timings, as `s9_realtime.py`."""
    import websockets
    from _env import key

    pcm, rate = read_wav(path)
    frame = rate * 2 * FRAME_MS // 1000
    events: list[dict] = []
    t0 = time.perf_counter()

    def stamp() -> int:
        return round((time.perf_counter() - t0) * 1000)

    async with websockets.connect(REALTIME, open_timeout=30) as ws:
        await ws.send(
            json.dumps(
                {
                    "authorization": {"accessToken": f"Bearer {key('MODEL_API_KEY')}"},
                    "audioEncoding": "PCM_16KHZ",
                    "model": MODEL,
                    "mode": "PUSH_TO_TALK",
                    "partialMode": "CUMULATIVE",
                    "emitAudioProgress": False,
                    "languageBias": ["Spanish"],
                    "keywords": KEYWORDS,
                }
            )
        )
        ack = json.loads(await ws.recv())
        assert "sessionId" in ack, "handshake refused"

        async def receive() -> None:
            async for message in ws:
                if isinstance(message, bytes):
                    continue
                event = json.loads(message)
                event["atMs"] = stamp()
                events.append(event)

        receiver = asyncio.create_task(receive())
        audio_start = stamp()
        for start in range(0, len(pcm), frame):
            await ws.send(pcm[start : start + frame])
            await asyncio.sleep(FRAME_MS / 1000)
        await ws.send(json.dumps({"type": "endStream"}))
        end_stream = stamp()
        await receiver
    return {
        "note": {"seconds": len(pcm) / (rate * 2), "rate": rate, "frameMs": FRAME_MS},
        "audioStartMs": audio_start,
        "endStreamMs": end_stream,
        "events": events,
    }


def transcribe_batch(path: Path) -> dict:
    """Uploads the WAV as `extract` does; returns the transcript and the round trip in ms."""
    import httpx
    from _env import key

    request = {
        "model": MODEL,
        "audioEncoding": "WAV",
        "mode": "PUSH_TO_TALK",
        "languageBias": ["Spanish"],
        "keywords": KEYWORDS,
    }
    started = time.perf_counter()
    with open(path, "rb") as audio:
        response = httpx.post(
            BATCH,
            headers={"Authorization": f"Bearer {key('MODEL_API_KEY')}"},
            files={
                "request": (None, json.dumps(request), "application/json"),
                "audio": ("note.wav", audio, "audio/wav"),
            },
            timeout=120,
        )
    response.raise_for_status()
    return {
        "transcript": str(response.json().get("transcript") or ""),
        "latencyMs": round((time.perf_counter() - started) * 1000),
    }
