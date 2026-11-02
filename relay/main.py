"""Ronda's live transcription relay: the phone's samples go through here to Voice Transcribe's
realtime mode, so the Meta key never leaves the server (`docs/MODELS.md` § Realtime).

One WebSocket from the phone per voice note (`packages/live_transcript`):

1. The first text frame, within 10 s, is `{"idToken", "surface"}`: the member's Firebase ID
   token and where the note is recorded (`signup`, `line`, `plan`, which picks the words Voice
   Transcribe expects). The token is verified and `users/{uid}.terms` must exist, as `extract`
   requires: no voice leaves before the terms are accepted.
2. The relay opens `wss://api.meta.ai/v1/asr/realtime`, sends the handshake with the key, and
   once Meta acknowledges answers the phone `{"type": "ready", "sessionId"}`.
3. Binary frames (raw 16 kHz mono 16-bit PCM) go to Meta as they come, at most a minute and a
   bit of audio; `{"type": "endStream"}` is passed on and ends the input.
4. Meta's `transcript` events come back as `{"type": "transcript", "transcript", "final"}`;
   the final one closes the note with 1000. Anything else is `{"type": "error", "code"}` and
   a close with 1008 (the phone's fault: a bad frame, no terms) or 1011 (Meta's or ours).

Nothing is stored and nothing of what was said is logged: only session ids, byte counts and
timings. Runs on Cloud Run in `southamerica-east1` (`scripts/deploy_relay.sh`); locally,
`uv run relay/main.py` against the emulators with `FIREBASE_AUTH_EMULATOR_HOST` and
`FIRESTORE_EMULATOR_HOST` set.
"""

import asyncio
import contextlib
import json
import logging
import os
import time
from collections.abc import AsyncIterator, Awaitable, Callable
from typing import Any, Protocol

UPSTREAM = "wss://api.meta.ai/v1/asr/realtime"
MODEL = "muse-voice-transcribe-1.0"
HANDSHAKE_SECONDS = 10
# Meta answered the smoke test's final transcript 0.2 s after endStream (docs/MODELS.md).
FINAL_SECONDS = 15
# The app stops at 60 s; 16 kHz mono 16-bit is 32,000 bytes a second, plus a little slack.
MAX_AUDIO_BYTES = 65 * 32_000
# Words Voice Transcribe should expect on each surface (as `functions/voice_signup.KEYWORDS`).
PLACES = ["Solymar", "Lagomar", "El Pinar", "Shangrilá", "San José de Carrasco", "rambla"]
KEYWORDS = {
    "signup": [*PLACES, "mate", "truco", "fútbol 5", "caminata", "termo", "yerba", "bizcochos"],
    "line": [*PLACES, "vecina", "vecino", "feria", "plaza"],
    "plan": [*PLACES, "mate", "caminata", "feria", "plaza", "bizcochos"],
}
SURFACES = frozenset(KEYWORDS)

log = logging.getLogger("relay")


class Socket(Protocol):
    """What this module needs of a WebSocket, the phone's or Meta's (`websockets` has it)."""

    async def send(self, message: str | bytes) -> None: ...

    async def recv(self) -> str | bytes: ...

    def __aiter__(self) -> AsyncIterator[str | bytes]: ...

    async def close(self, code: int = 1000, reason: str = "") -> None: ...


class Refused(Exception):
    """The phone's note can't be taken; `code` goes back in the error frame."""

    def __init__(self, code: str, close: int = 1008):
        super().__init__(code)
        self.code, self.close = code, close


def handshake(surface: str, api_key: str) -> dict[str, Any]:
    """Meta's first frame: the key travels here, never in a header."""
    return {
        "authorization": {"accessToken": f"Bearer {api_key}"},
        "audioEncoding": "PCM_16KHZ",
        "model": MODEL,
        "mode": "PUSH_TO_TALK",
        "partialMode": "CUMULATIVE",
        "emitAudioProgress": False,
        "languageBias": ["Spanish"],
        "keywords": KEYWORDS[surface],
    }


def parse_opening(message: str | bytes) -> tuple[str, str]:
    """`(idToken, surface)` from the phone's first frame, or `Refused("bad_request")`."""
    try:
        opening = json.loads(message) if isinstance(message, str) else None
    except ValueError:
        opening = None
    if not isinstance(opening, dict):
        raise Refused("bad_request")
    token, surface = opening.get("idToken"), opening.get("surface")
    if not isinstance(token, str) or not token or surface not in SURFACES:
        raise Refused("bad_request")
    return token, surface


async def pump_audio(phone: Socket, upstream: Socket) -> int:
    """Phone → Meta until `endStream` or the phone leaves. Returns the bytes of audio sent."""
    sent = 0
    async for message in phone:
        if isinstance(message, bytes):
            sent += len(message)
            if sent > MAX_AUDIO_BYTES:
                raise Refused("too_long")
            await upstream.send(message)
            continue
        try:
            control = json.loads(message)
        except ValueError:
            raise Refused("bad_request") from None
        if isinstance(control, dict) and control.get("type") == "endStream":
            await upstream.send(json.dumps({"type": "endStream"}))
            return sent
        raise Refused("bad_request")
    # The phone left without ending the note: let Meta flush what it has.
    await upstream.send(json.dumps({"type": "endStream"}))
    return sent


async def pump_transcripts(upstream: Socket, phone: Socket) -> bool:
    """Meta → phone, only transcripts. Returns whether the final transcript was delivered."""
    async for message in upstream:
        if isinstance(message, bytes):
            continue
        try:
            event = json.loads(message)
        except ValueError:
            continue
        if not isinstance(event, dict):
            continue
        if event.get("type") == "transcript":
            final = bool(event.get("final"))
            await phone.send(
                json.dumps(
                    {
                        "type": "transcript",
                        "transcript": str(event.get("transcript") or ""),
                        "final": final,
                    },
                    ensure_ascii=False,
                )
            )
            if final:
                return True
        elif event.get("type") == "error":
            log.warning("upstream error: %s", event.get("errorCode") or event.get("errorType"))
            return False
    return False


async def serve_note(
    phone: Socket,
    *,
    uid_of: Callable[[str], Awaitable[str]],
    has_terms: Callable[[str], Awaitable[bool]],
    connect_upstream: Callable[[], Awaitable[Socket]],
    api_key: str,
) -> None:
    """One phone connection, start to finish (`docs/ARCHITECTURE.md` § Live transcription).

    `uid_of(idToken)` raises for a bad token; `has_terms(uid)` reads `users/{uid}.terms`;
    `connect_upstream()` opens the socket to Meta.
    """
    started = time.perf_counter()
    upstream: Socket | None = None
    session = ""
    try:
        try:
            opening = await asyncio.wait_for(phone.recv(), HANDSHAKE_SECONDS)
        except TimeoutError:
            raise Refused("bad_request") from None
        token, surface = parse_opening(opening)
        try:
            uid = await uid_of(token)
        except Exception:
            raise Refused("unauthenticated") from None
        if not await has_terms(uid):
            raise Refused("terms")
        try:
            upstream = await connect_upstream()
            await upstream.send(json.dumps(handshake(surface, api_key)))
            ack = json.loads(await asyncio.wait_for(upstream.recv(), HANDSHAKE_SECONDS))
            session = str(ack["sessionId"])
        except Exception:
            raise Refused("upstream", close=1011) from None
        await phone.send(json.dumps({"type": "ready", "sessionId": session}))
        ready = time.perf_counter()

        audio = asyncio.create_task(pump_audio(phone, upstream))
        transcripts = asyncio.create_task(pump_transcripts(upstream, phone))
        done, _ = await asyncio.wait({audio, transcripts}, return_when=asyncio.FIRST_COMPLETED)
        if audio in done:
            if error := audio.exception():
                transcripts.cancel()
                raise error
            # The note ended: the final transcript is the next thing Meta sends.
            try:
                final = await asyncio.wait_for(transcripts, FINAL_SECONDS)
            except TimeoutError:
                raise Refused("upstream", close=1011) from None
            sent = audio.result()
        else:
            # Meta is done (an error, or it closed) while the phone was still talking.
            audio.cancel()
            final, sent = transcripts.result(), 0
        if not final:
            raise Refused("upstream", close=1011)
        log.info(
            "note %s: %s, %d bytes, ready %d ms, final %d ms",
            session,
            surface,
            sent,
            (ready - started) * 1000,
            (time.perf_counter() - ready) * 1000,
        )
        await phone.close(1000)
    except Refused as refused:
        log.info("note %s refused: %s", session or "-", refused.code)
        with contextlib.suppress(Exception):  # the phone may be gone already
            await phone.send(json.dumps({"type": "error", "code": refused.code}))
        await phone.close(refused.close, refused.code)
    finally:
        if upstream is not None:
            await upstream.close()


def firebase_app() -> Any:
    """The Admin app, on the Cloud Run service account or the emulators' project."""
    import firebase_admin

    project = os.environ.get("GOOGLE_CLOUD_PROJECT") or os.environ.get("GCLOUD_PROJECT")
    return firebase_admin.initialize_app(options={"projectId": project} if project else None)


async def uid_of_token(token: str) -> str:
    """The uid of a Firebase ID token (`FIREBASE_AUTH_EMULATOR_HOST` makes it the emulator's)."""
    from firebase_admin import auth

    claims = await asyncio.to_thread(auth.verify_id_token, token)
    return str(claims["uid"])


async def user_has_terms(uid: str) -> bool:
    """Whether `users/{uid}.terms` exists: the terms were accepted."""
    from firebase_admin import firestore

    document = await asyncio.to_thread(firestore.client().collection("users").document(uid).get)
    return bool((document.to_dict() or {}).get("terms"))


async def connect_meta() -> Socket:
    from websockets.asyncio.client import connect

    return await connect(UPSTREAM, open_timeout=HANDSHAKE_SECONDS)


async def main() -> None:
    from websockets.asyncio.server import serve

    logging.basicConfig(level=logging.INFO, format="%(message)s")
    api_key = os.environ["MODEL_API_KEY"]
    firebase_app()

    async def handler(phone: Any) -> None:
        if phone.request is not None and phone.request.path != "/v1/live":
            await phone.close(1008, "not_found")
            return
        await serve_note(
            phone,
            uid_of=uid_of_token,
            has_terms=user_has_terms,
            connect_upstream=connect_meta,
            api_key=api_key,
        )

    port = int(os.environ.get("PORT", "8090"))
    async with serve(handler, "0.0.0.0", port, max_size=1 << 20) as server:
        log.info("relay listening on %d", port)
        await server.serve_forever()


if __name__ == "__main__":  # pragma: no cover
    asyncio.run(main())
