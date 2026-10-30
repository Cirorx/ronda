"""Every test runs as on a `demo-*` project outside the emulator, whatever the shell exports, so
the invented `demo-` sign-ups count (demo_users.py). A test of the real project or of the
emulator sets its own."""

import pytest


@pytest.fixture(autouse=True)
def demo_project(monkeypatch):
    monkeypatch.setenv("GCLOUD_PROJECT", "demo-ronda-tests")
    monkeypatch.delenv("FUNCTIONS_EMULATOR", raising=False)
