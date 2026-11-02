"""`--live` runs against the real Meta Model API; `--record` rewrites the fixtures from it."""

import pytest


def pytest_addoption(parser):
    parser.addoption("--live", action="store_true", help="call the real API instead of replaying")
    parser.addoption("--record", action="store_true", help="with --live: rewrite fixtures/")


@pytest.fixture(scope="session")
def live(request) -> bool:
    return request.config.getoption("--live")


@pytest.fixture(scope="session")
def record(request) -> bool:
    return request.config.getoption("--record")
