"""report_client_error: what the web app's error log keeps, scrubs and refuses."""

import inspect
from datetime import UTC, datetime, timedelta
from types import SimpleNamespace

import pytest
from firebase_functions import https_fn

import client_errors
import main
from tests.fake_firestore import FakeFirestore

NOW = datetime(2026, 10, 30, 21, 15, tzinfo=UTC)
MEMBER = SimpleNamespace(uid="Xy7k2PqR9sT1uV3wZ5aB8cD0eF4g", token={})


def a_report(**fields) -> dict:
    return {
        "platform": "web",
        "appVersion": "1.0.0",
        "build": "3",
        "flavor": "production",
        "screen": "/bienvenida/entrar",
        "step": "voiceUpload",
        "code": "firebase_storage/unauthorized",
        "message": "Upload failed",
        "stack": "#0 main (package:ronda/main.dart:1:2)",
        "fatal": False,
        **fields,
    }


def stored(db: FakeFirestore) -> list[dict]:
    return [v for k, v in db.documents.items() if k.startswith("client_errors/")]


def quotas(db: FakeFirestore) -> dict[str, dict]:
    return {k: v for k, v in db.documents.items() if k.startswith("client_error_quota/")}


class TestScrub:
    @pytest.mark.parametrize(
        ("text", "expected"),
        [
            ("mail vecina@example.com now", "mail <email> now"),
            ("call 099 123 456", "call <number>"),
            ("call +598 99 123 456", "call <number>"),
            ("GET https://x.test/y?token=abc&a=1 failed", "GET https://x.test/y?<query> failed"),
            ("https://x.test/y stays", "https://x.test/y stays"),
            ('said "me duele la rodilla" today', "said <text> today"),
            ("said 'hola' and «chau»", "said <text> and <text>"),
            (
                "users/Xy7k2PqR9sT1uV3wZ5aB8cD0eF4g/private/eligible",
                "users/<id>/private/eligible",
            ),
            ("_OnboardingVoiceRecorderState stays", "_OnboardingVoiceRecorderState stays"),
            ("package:ronda/app.dart:123:45", "package:ronda/app.dart:123:45"),
        ],
    )
    def test_replaces_what_could_be_personal(self, text, expected):
        assert client_errors.scrub(text) == expected

    def test_a_message_keeps_its_first_line_only(self):
        message = "FormatException: Unexpected character\nMarta, 60-69, Solymar\n^"
        assert client_errors.scrub_message(message) == "FormatException: Unexpected character"

    def test_an_empty_message_and_stack_stay_empty(self):
        assert client_errors.scrub_message("") == ""
        assert client_errors.scrub_stack("") == ""

    def test_a_stack_keeps_forty_lines_at_most(self):
        stack = "\n".join(f"#{n} frame" for n in range(100))
        assert len(client_errors.scrub_stack(stack).split("\n")) == client_errors.MAX_STACK_LINES

    def test_the_uid_hash_is_salted_and_short(self):
        hashed = client_errors.uid_hash("abc")
        assert len(hashed) == client_errors.HASH_LENGTH
        assert hashed != client_errors.short_hash("abc")
        # The same value packages/error_reporter's uidHash computes.
        assert hashed == "21679a36ee4baa70"


class TestRequesterIp:
    def test_takes_the_first_forwarded_hop(self):
        headers = {"X-Forwarded-For": "203.0.113.7, 10.0.0.1"}
        assert client_errors.requester_ip(headers, "10.0.0.2") == "203.0.113.7"

    def test_falls_back_to_the_socket(self):
        assert client_errors.requester_ip({}, "10.0.0.2") == "10.0.0.2"
        assert client_errors.requester_ip(None, None) == "unknown"


class TestReportsFrom:
    @pytest.mark.parametrize(
        "data", [None, [], {}, {"reports": []}, {"reports": "x"}, {"reports": [1]}]
    )
    def test_refuses_a_malformed_call(self, data):
        with pytest.raises(client_errors.ClientErrorRefused) as excinfo:
            client_errors.reports_from(data)
        assert excinfo.value.code == "invalid-argument"

    def test_refuses_more_than_ten_reports(self):
        with pytest.raises(client_errors.ClientErrorRefused):
            client_errors.reports_from({"reports": [a_report()] * 11})

    def test_caps_and_normalises_every_field(self):
        [report] = client_errors.reports_from(
            {
                "reports": [
                    a_report(
                        platform="windows",
                        flavor="staging",
                        screen="s" * 500,
                        code="",
                        message=["not", "text"],
                        stack=None,
                        fatal="yes",
                        firstName="Marta",
                        needs=["walkALot"],
                    )
                ]
            }
        )
        assert report == {
            "platform": "other",
            "flavor": "other",
            "appVersion": "1.0.0",
            "build": "3",
            "screen": "s" * client_errors.LIMITS["screen"],
            "step": "voiceUpload",
            "code": "unknown",
            "message": "",
            "stack": "",
            "fatal": False,
        }

    def test_scrubs_again_on_the_server(self):
        [report] = client_errors.reports_from(
            {"reports": [a_report(message="No user vecina@example.com", step=7)]}
        )
        assert report["message"] == "No user <email>"
        assert report["step"] == ""


class TestReport:
    def test_writes_each_report_with_its_expiry_and_the_hashed_uid(self):
        db = FakeFirestore()

        result = client_errors.report(
            db, {"reports": [a_report(fatal=True)]}, uid=MEMBER.uid, ip="203.0.113.7", now=NOW
        )

        assert result == {"accepted": 1}
        [row] = stored(db)
        assert row["at"] == NOW
        assert row["expireAt"] == NOW + timedelta(days=30)
        assert row["uidHash"] == client_errors.uid_hash(MEMBER.uid)
        assert row["fatal"] is True
        assert MEMBER.uid not in str(db.documents)
        assert "203.0.113.7" not in str(db.documents)

    def test_a_signed_out_report_carries_no_uid_and_counts_against_the_ip(self):
        db = FakeFirestore()

        client_errors.report(db, {"reports": [a_report()]}, uid=None, ip="203.0.113.7", now=NOW)

        assert "uidHash" not in stored(db)[0]
        [(path, quota)] = quotas(db).items()
        assert path.startswith("client_error_quota/ip") and path.endswith("_2026103021")
        assert quota == {"count": 1, "expireAt": NOW + timedelta(hours=2)}

    def test_keeps_only_what_fits_in_the_hour_then_refuses(self):
        db = FakeFirestore()
        ten = {"reports": [a_report()] * 10}
        for _ in range(5):
            client_errors.report(db, ten, uid=MEMBER.uid, ip="x", now=NOW)

        assert client_errors.report(db, ten, uid=MEMBER.uid, ip="x", now=NOW) == {"accepted": 10}
        with pytest.raises(client_errors.ClientErrorRefused) as excinfo:
            client_errors.report(db, ten, uid=MEMBER.uid, ip="x", now=NOW)
        assert excinfo.value.code == "resource-exhausted"
        assert len(stored(db)) == client_errors.HOURLY_LIMIT

    def test_a_partly_full_hour_keeps_the_first_reports(self):
        db = FakeFirestore()
        key = f"u{client_errors.uid_hash(MEMBER.uid)}_2026103021"
        db.documents[f"client_error_quota/{key}"] = {"count": client_errors.HOURLY_LIMIT - 2}

        result = client_errors.report(
            db, {"reports": [a_report()] * 5}, uid=MEMBER.uid, ip="x", now=NOW
        )

        assert result == {"accepted": 2}

    def test_a_new_hour_starts_a_new_count(self):
        db = FakeFirestore()
        ten = {"reports": [a_report()] * 10}
        for _ in range(6):
            client_errors.report(db, ten, uid=None, ip="x", now=NOW)

        later = NOW + timedelta(hours=1)
        assert client_errors.report(db, ten, uid=None, ip="x", now=later) == {"accepted": 10}


def call(auth, data, headers=None, remote_addr="10.0.0.2"):
    raw = SimpleNamespace(headers=headers or {}, remote_addr=remote_addr)
    request = SimpleNamespace(auth=auth, data=data, raw_request=raw)
    return inspect.unwrap(main.report_client_error)(request)


class TestReportClientError:
    @pytest.fixture
    def db(self, monkeypatch) -> FakeFirestore:
        db = FakeFirestore()
        monkeypatch.setattr(main, "_firestore", lambda: db)
        monkeypatch.setattr(main, "_now", lambda: NOW)
        return db

    def test_takes_a_signed_out_caller(self, db):
        result = call(None, {"reports": [a_report()]}, {"X-Forwarded-For": "203.0.113.7"})

        assert result == {"accepted": 1}
        assert "uidHash" not in stored(db)[0]

    def test_hashes_a_signed_in_caller(self, db):
        call(MEMBER, {"reports": [a_report()]})

        assert stored(db)[0]["uidHash"] == client_errors.uid_hash(MEMBER.uid)

    def test_answers_a_refusal_with_its_code(self, db):
        with pytest.raises(https_fn.HttpsError) as excinfo:
            call(None, {"reports": []})
        assert excinfo.value.code == https_fn.FunctionsErrorCode.INVALID_ARGUMENT

    def test_works_without_the_raw_request(self, db):
        request = SimpleNamespace(auth=None, data={"reports": [a_report()]})
        assert inspect.unwrap(main.report_client_error)(request) == {"accepted": 1}
