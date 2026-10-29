"""fcm.py: message dicts to the Admin SDK's messages, and each outcome back."""

from types import SimpleNamespace

import pytest
from firebase_admin import messaging

import fcm
import rsvp

ANDROID, WEB = rsvp.rsvp_messages(
    tokens=[("t-a", "android"), ("t-w", "web")],
    title="Sábado a la tarde · mate en la rambla",
    body="¿Venís?",
    ronda_id="ronda-1",
    week="2026-W44",
    app_url="https://ronda-uy.firebaseapp.com/app/ronda",
)


def test_the_app_url_is_mi_ronda_on_the_projects_hosting(monkeypatch):
    monkeypatch.setenv("GCLOUD_PROJECT", "ronda-uy")
    assert fcm.app_url() == "https://ronda-uy.firebaseapp.com/app/ronda"

    monkeypatch.delenv("GCLOUD_PROJECT")
    assert fcm.app_url() == "https://ronda-uy.firebaseapp.com/app/ronda"


def test_android_is_data_only_at_high_priority():
    message = fcm.message(ANDROID)

    assert message.token == "t-a"
    assert message.data["type"] == "rsvp"
    assert message.notification is None
    assert message.android.priority == "high"
    assert message.webpush is None


def test_web_is_a_notification_that_opens_the_app():
    message = fcm.message(WEB)

    assert message.notification.title == "Sábado a la tarde · mate en la rambla"
    assert message.webpush.fcm_options.link == "https://ronda-uy.firebaseapp.com/app/ronda"
    assert message.android is None
    assert message.data is None


def test_sends_nothing_under_the_functions_emulator(monkeypatch):
    monkeypatch.setenv("FUNCTIONS_EMULATOR", "true")
    monkeypatch.setattr(messaging, "send_each", pytest.fail)

    assert fcm.send([ANDROID, WEB]) == ["skipped", "skipped"]


def test_reports_each_outcome_in_batches_of_500(monkeypatch):
    monkeypatch.delenv("FUNCTIONS_EMULATOR", raising=False)
    batches = []
    responses = [
        SimpleNamespace(success=True, exception=None),
        SimpleNamespace(success=False, exception=messaging.UnregisteredError("gone")),
        SimpleNamespace(success=False, exception=ValueError("other")),
    ]

    def send_each(batch):
        batches.append(len(batch))
        return SimpleNamespace(responses=[responses[i % 3] for i in range(len(batch))])

    monkeypatch.setattr(messaging, "send_each", send_each)

    outcomes = fcm.send([ANDROID] * 501)

    assert batches == [500, 1]
    assert outcomes[:3] == ["ok", "unregistered", "failed"]
    assert outcomes[-1] == "ok"
