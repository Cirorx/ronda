# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["websockets>=14"]
# ///
"""Smoke test 9: Voice Transcribe in real time (`wss://api.meta.ai/v1/asr/realtime`).

    uv run scripts/smoke/s9_realtime.py note.wav [--record events.json]

Streams a 16 kHz mono 16-bit WAV as raw PCM frames paced at real time, the way the phone
will, and prints every event the server sends with the time it arrived: time to the first
words, time from `endStream` to the final transcript. `--record` writes the events to a JSON
file (timings and text) for the eval's offline fixtures; record only invented notes
(`evals/voice/make_note.sh`), never a real person's.

Voice notes of real people never go in git; keep them outside the repo.
"""

import asyncio
import json
import sys
import time
import wave

import websockets
from _env import Timer, key

URL = "wss://api.meta.ai/v1/asr/realtime"
MODEL = "muse-voice-transcribe-1.0"
FRAME_MS = 80
KEYWORDS = ["Solymar", "El Pinar", "Lagomar", "truco", "termo", "bizcochos", "rambla"]


def handshake() -> dict:
    """The first JSON frame; the key travels here, not in a header."""
    return {
        "authorization": {"accessToken": f"Bearer {key('MODEL_API_KEY')}"},
        "audioEncoding": "PCM_16KHZ",
        "model": MODEL,
        "mode": "PUSH_TO_TALK",
        "partialMode": "CUMULATIVE",
        "emitAudioProgress": False,
        "languageBias": ["Spanish"],
        "keywords": KEYWORDS,
    }


async def run(path: str, record: str | None) -> None:
    with wave.open(path) as w:
        rate, pcm = w.getframerate(), w.readframes(w.getnframes())
        assert w.getnchannels() == 1 and w.getsampwidth() == 2, "needs mono 16-bit PCM"
        assert rate == 16000, "needs 16 kHz (the phone records 16 kHz)"
    seconds = len(pcm) / (rate * 2)
    frame = rate * 2 * FRAME_MS // 1000
    print(f"{path}: {seconds:.1f} s, {len(pcm) // frame + 1} frames of {FRAME_MS} ms")

    events: list[dict] = []
    t0 = time.perf_counter()
    stamp = lambda: round((time.perf_counter() - t0) * 1000)  # noqa: E731

    with Timer() as connect:
        ws = await websockets.connect(URL, open_timeout=30)
    async with ws:
        await ws.send(json.dumps(handshake()))
        ack = json.loads(await ws.recv())
        print(f"connect {connect.s} s, handshake ack at {stamp()} ms: {ack}")
        if "sessionId" not in ack:
            sys.exit("handshake refused")

        async def receive() -> None:
            async for message in ws:
                if isinstance(message, bytes):
                    continue
                event = json.loads(message)
                event["atMs"] = stamp()
                events.append(event)
                text = event.get("transcript", event.get("message", ""))
                print(
                    f"  {event['atMs']:>6} ms {event.get('type')}"
                    f"{' FINAL' if event.get('final') else ''}: {text}"
                )

        receiver = asyncio.create_task(receive())
        sent_at = stamp()
        for start in range(0, len(pcm), frame):
            await ws.send(pcm[start : start + frame])
            # Pace at real time: the server refuses audio more than 5 s ahead.
            await asyncio.sleep(FRAME_MS / 1000)
        await ws.send(json.dumps({"type": "endStream"}))
        end_at = stamp()
        print(f"audio sent {sent_at}-{end_at} ms; endStream sent")
        await receiver
        print(f"server closed: code {ws.protocol.close_code}, at {stamp()} ms")

    partials = [e for e in events if e.get("type") == "transcript"]
    first = next((e for e in partials if e.get("transcript")), None)
    final = next((e for e in partials if e.get("final")), None)
    print(f"first words at {first['atMs'] - sent_at if first else '-'} ms after audio start")
    print(f"final at {final['atMs'] - end_at if final else '-'} ms after endStream")
    if record:
        with open(record, "w") as out:
            json.dump(
                {
                    "note": {"seconds": seconds, "rate": rate, "frameMs": FRAME_MS},
                    "handshake": {k: v for k, v in handshake().items() if k != "authorization"},
                    "ack": ack,
                    "audioStartMs": sent_at,
                    "endStreamMs": end_at,
                    "closeCode": ws.protocol.close_code,
                    "events": events,
                },
                out,
                indent=1,
                ensure_ascii=False,
            )
        print(f"recorded {len(events)} events to {record}")


path = sys.argv[1]
record = sys.argv[sys.argv.index("--record") + 1] if "--record" in sys.argv else None
asyncio.run(run(path, record))
