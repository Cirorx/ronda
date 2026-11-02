"""The relay without the network: a scripted phone and a scripted Meta."""

import asyncio
import json

import pytest

import main

ID_TOKEN = "firebase-id-token"
OPENING = json.dumps({"idToken": ID_TOKEN, "surface": "signup"})
END = json.dumps({"type": "endStream"})


class FakeSocket:
    """Messages queued with `queue()` come out of `recv` and iteration; `sent` keeps what went
    in. `close` records the code and ends iteration."""

    def __init__(self, *messages: str | bytes):
        self.incoming: asyncio.Queue[str | bytes | None] = asyncio.Queue()
        for message in messages:
            self.queue(message)
        self.sent: list[str | bytes] = []
        self.closed: tuple[int, str] | None = None

    def queue(self, message: str | bytes | None) -> None:
        self.incoming.put_nowait(message)

    async def send(self, message: str | bytes) -> None:
        self.sent.append(message)

    async def recv(self) -> str | bytes:
        message = await self.incoming.get()
        if message is None:
            raise ConnectionError("closed")
        return message

    def __aiter__(self):
        return self

    async def __anext__(self) -> str | bytes:
        message = await self.incoming.get()
        if message is None:
            raise StopAsyncIteration
        return message

    async def close(self, code: int = 1000, reason: str = "") -> None:
        self.closed = (code, reason)
        self.queue(None)

    @property
    def events(self) -> list[dict]:
        return [json.loads(m) for m in self.sent if isinstance(m, str)]


def transcript(text: str, *, final: bool = False) -> str:
    return json.dumps({"type": "transcript", "transcript": text, "final": final})


class Relay:
    """`serve_note` with fakes: `phone`, `meta` (Meta's socket) and what it was asked."""

    def __init__(self, phone: FakeSocket, meta: FakeSocket | None = None, *, terms: bool = True):
        self.phone, self.meta, self.terms = phone, meta or FakeSocket(), terms
        self.verified: list[str] = []
        self.connected = 0

    async def uid_of(self, token: str) -> str:
        self.verified.append(token)
        if token != ID_TOKEN:
            raise ValueError("bad token")
        return "uid-1"

    async def has_terms(self, uid: str) -> bool:
        assert uid == "uid-1"
        return self.terms

    async def connect(self) -> FakeSocket:
        self.connected += 1
        if self.meta.closed:
            raise ConnectionError("refused")
        return self.meta

    async def run(self) -> None:
        await main.serve_note(
            self.phone,
            uid_of=self.uid_of,
            has_terms=self.has_terms,
            connect_upstream=self.connect,
            api_key="meta-key",
        )


def meta_acknowledging(*events: str) -> FakeSocket:
    return FakeSocket(json.dumps({"sessionId": "s-1"}), *events)


class TestANote:
    async def test_streams_the_audio_and_the_transcripts_and_closes_with_1000(self):
        phone = FakeSocket(OPENING, b"\x01\x02", b"\x03\x04", END)
        meta = meta_acknowledging(
            transcript("Hola"),
            json.dumps({"type": "speechStart", "turnId": 1}),
            b"binary nobody sends",
            "not json",
            json.dumps(["not", "an", "object"]),
            transcript("Hola, soy Marta.", final=True),
        )
        relay = Relay(phone, meta)

        await relay.run()

        assert relay.verified == [ID_TOKEN]
        assert json.loads(meta.sent[0])["authorization"] == {"accessToken": "Bearer meta-key"}
        assert json.loads(meta.sent[0])["audioEncoding"] == "PCM_16KHZ"
        assert json.loads(meta.sent[0])["languageBias"] == ["Spanish"]
        assert "Solymar" in json.loads(meta.sent[0])["keywords"]
        assert meta.sent[1:] == [b"\x01\x02", b"\x03\x04", END]
        assert phone.events == [
            {"type": "ready", "sessionId": "s-1"},
            {"type": "transcript", "transcript": "Hola", "final": False},
            {"type": "transcript", "transcript": "Hola, soy Marta.", "final": True},
        ]
        assert phone.closed == (1000, "")
        assert meta.closed is not None

    async def test_a_phone_that_leaves_lets_meta_flush_what_it_heard(self):
        phone = FakeSocket(OPENING, b"\x01\x02")
        phone.queue(None)  # the phone's socket closes
        meta = meta_acknowledging(transcript("Hola", final=True))
        relay = Relay(phone, meta)

        await relay.run()

        assert meta.sent[1:] == [b"\x01\x02", END]
        assert phone.closed == (1000, "")

    async def test_each_surface_has_its_own_words(self):
        for surface in main.SURFACES:
            assert main.handshake(surface, "k")["keywords"] == main.KEYWORDS[surface]
            assert "rambla" in main.handshake(surface, "k")["keywords"]


class TestRefusals:
    @staticmethod
    def refused(phone: FakeSocket, code: str, close: int = 1008) -> None:
        assert phone.events[-1] == {"type": "error", "code": code}
        assert phone.closed == (close, code)

    async def test_no_first_frame_in_ten_seconds(self, monkeypatch):
        monkeypatch.setattr(main, "HANDSHAKE_SECONDS", 0.01)
        phone = FakeSocket()
        relay = Relay(phone)

        await relay.run()

        self.refused(phone, "bad_request")
        assert relay.connected == 0

    @pytest.mark.parametrize(
        "opening",
        [
            b"\x00\x01",
            "not json",
            json.dumps(["list"]),
            json.dumps({"idToken": "", "surface": "signup"}),
            json.dumps({"idToken": 5, "surface": "signup"}),
            json.dumps({"idToken": "t", "surface": "chat"}),
            json.dumps({"idToken": "t"}),
        ],
    )
    async def test_a_first_frame_that_is_not_the_opening(self, opening):
        phone = FakeSocket(opening)
        relay = Relay(phone)

        await relay.run()

        self.refused(phone, "bad_request")
        assert relay.verified == []

    async def test_a_token_that_does_not_verify(self):
        phone = FakeSocket(json.dumps({"idToken": "forged", "surface": "line"}))
        relay = Relay(phone)

        await relay.run()

        self.refused(phone, "unauthenticated")
        assert relay.connected == 0

    async def test_a_member_who_has_not_accepted_the_terms(self):
        phone = FakeSocket(OPENING)
        relay = Relay(phone, terms=False)

        await relay.run()

        self.refused(phone, "terms")
        assert relay.connected == 0

    async def test_meta_that_cannot_be_reached(self):
        phone = FakeSocket(OPENING)
        meta = FakeSocket()
        meta.closed = (1011, "")  # connect() refuses
        relay = Relay(phone, meta)

        await relay.run()

        self.refused(phone, "upstream", 1011)
        assert relay.connected == 1

    async def test_meta_that_refuses_the_handshake(self):
        phone = FakeSocket(OPENING)
        meta = FakeSocket(json.dumps({"type": "error", "message": "bad key"}))
        relay = Relay(phone, meta)

        await relay.run()

        self.refused(phone, "upstream", 1011)
        assert meta.closed is not None

    async def test_meta_that_never_acknowledges(self, monkeypatch):
        monkeypatch.setattr(main, "HANDSHAKE_SECONDS", 0.01)
        phone = FakeSocket(OPENING)
        relay = Relay(phone, FakeSocket())

        await relay.run()

        self.refused(phone, "upstream", 1011)

    async def test_meta_that_fails_mid_note(self):
        phone = FakeSocket(OPENING, b"\x01", END)
        meta = meta_acknowledging(
            transcript("Hola"), json.dumps({"type": "error", "errorCode": "E1"})
        )
        relay = Relay(phone, meta)

        await relay.run()

        assert phone.events[1] == {"type": "transcript", "transcript": "Hola", "final": False}
        self.refused(phone, "upstream", 1011)

    async def test_meta_that_fails_while_the_phone_is_still_talking(self):
        phone = FakeSocket(OPENING, b"\x01")  # no endStream yet
        meta = meta_acknowledging(json.dumps({"type": "error", "errorType": "internal"}))
        relay = Relay(phone, meta)

        await relay.run()

        self.refused(phone, "upstream", 1011)

    async def test_meta_that_never_sends_the_final_transcript(self, monkeypatch):
        monkeypatch.setattr(main, "FINAL_SECONDS", 0.01)
        phone = FakeSocket(OPENING, END)
        meta = meta_acknowledging(transcript("Hola"))
        relay = Relay(phone, meta)

        await relay.run()

        self.refused(phone, "upstream", 1011)

    async def test_meta_that_closes_without_a_final_transcript(self):
        phone = FakeSocket(OPENING, END)
        meta = meta_acknowledging()
        meta.queue(None)
        relay = Relay(phone, meta)

        await relay.run()

        self.refused(phone, "upstream", 1011)

    async def test_more_than_a_minute_of_audio(self, monkeypatch):
        monkeypatch.setattr(main, "MAX_AUDIO_BYTES", 3)
        phone = FakeSocket(OPENING, b"\x01\x02", b"\x03\x04")
        meta = meta_acknowledging()
        relay = Relay(phone, meta)

        await relay.run()

        self.refused(phone, "too_long")
        assert meta.sent[1:] == [b"\x01\x02"]

    @pytest.mark.parametrize("control", ["not json", json.dumps({"type": "pause"})])
    async def test_a_text_frame_that_is_not_end_stream(self, control):
        phone = FakeSocket(OPENING, control)
        relay = Relay(phone, meta_acknowledging())

        await relay.run()

        self.refused(phone, "bad_request")

    async def test_a_phone_gone_before_the_error_frame(self):
        class GonePhone(FakeSocket):
            async def send(self, message):
                raise ConnectionError("gone")

        phone = GonePhone("not json")

        await Relay(phone).run()

        assert phone.sent == []
        assert phone.closed == (1008, "bad_request")


class TestWiring:
    def test_firebase_app_takes_the_project_from_the_environment(self, monkeypatch):
        import firebase_admin

        seen = {}
        monkeypatch.setattr(
            firebase_admin, "initialize_app", lambda options=None: seen.setdefault("o", options)
        )
        monkeypatch.setenv("GOOGLE_CLOUD_PROJECT", "ronda-uy")
        main.firebase_app()
        assert seen["o"] == {"projectId": "ronda-uy"}

        seen.clear()
        monkeypatch.delenv("GOOGLE_CLOUD_PROJECT")
        monkeypatch.delenv("GCLOUD_PROJECT", raising=False)
        main.firebase_app()
        assert seen["o"] is None

    async def test_uid_of_token_verifies_with_the_admin_sdk(self, monkeypatch):
        from firebase_admin import auth

        monkeypatch.setattr(auth, "verify_id_token", lambda token: {"uid": f"uid-of-{token}"})

        assert await main.uid_of_token("t") == "uid-of-t"

    async def test_user_has_terms_reads_the_user_document(self, monkeypatch):
        from firebase_admin import firestore

        class Doc:
            def __init__(self, data):
                self.data = data

            def to_dict(self):
                return self.data

        class Client:
            def __init__(self, data):
                self.data = data

            def collection(self, name):
                assert name == "users"
                return self

            def document(self, uid):
                assert uid == "uid-1"
                return self

            def get(self):
                return Doc(self.data)

        for data, expected in [({"terms": {"version": "1"}}, True), ({}, False), (None, False)]:
            monkeypatch.setattr(firestore, "client", lambda data=data: Client(data))
            assert await main.user_has_terms("uid-1") is expected

    async def test_connect_meta_opens_the_realtime_socket(self, monkeypatch):
        import websockets.asyncio.client as client

        seen = {}

        async def connect(url, **kwargs):
            seen["url"], seen["kwargs"] = url, kwargs
            return "socket"

        monkeypatch.setattr(client, "connect", connect)

        assert await main.connect_meta() == "socket"
        assert seen["url"] == main.UPSTREAM

    async def test_main_serves_notes_on_the_port_until_stopped(self, monkeypatch):
        import websockets.asyncio.server as server

        monkeypatch.setenv("MODEL_API_KEY", "meta-key")
        monkeypatch.setenv("PORT", "8765")
        monkeypatch.setattr(main, "firebase_app", lambda: None)
        handled: list[FakeSocket] = []
        bound = {}

        class Server:
            def __init__(self, handler, host, port, **kwargs):
                bound["host"], bound["port"], self.handler = host, port, handler

            async def __aenter__(self):
                return self

            async def __aexit__(self, *_):
                return None

            async def serve_forever(self):
                # Two phones: one on the wrong path, one with no first frame.
                class Request:
                    def __init__(self, path):
                        self.path = path

                wrong = FakeSocket()
                wrong.request = Request("/other")
                await self.handler(wrong)
                handled.append(wrong)
                right = FakeSocket("not json")
                right.request = Request("/v1/live")
                await self.handler(right)
                handled.append(right)
                bare = FakeSocket("not json")
                bare.request = None
                await self.handler(bare)
                handled.append(bare)

        monkeypatch.setattr(server, "serve", Server)

        await main.main()

        assert bound == {"host": "0.0.0.0", "port": 8765}
        assert handled[0].closed == (1008, "not_found")
        assert handled[1].closed == (1008, "bad_request")
        assert handled[2].closed == (1008, "bad_request")
