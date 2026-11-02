"""`--live` runs the real models (Muse Spark Open on Baseten, Spark 1.3 as fallback, as the job
does); `--record` with it rewrites `fixtures/recorded/` and RESULTS.md. Keys come only through
`scripts/smoke/_env.py` `key()` and are never printed."""

import os
import pathlib
import sys

import pytest

HERE = pathlib.Path(__file__).resolve().parent
ROOT = HERE.parents[1]
for path in (ROOT / "functions", ROOT / "scripts" / "smoke", HERE):
    if str(path) not in sys.path:
        sys.path.insert(0, str(path))


def pytest_addoption(parser):
    parser.addoption(
        "--live", action="store_true", help="call the real models instead of replaying"
    )
    parser.addoption(
        "--record", action="store_true", help="with --live: rewrite fixtures/recorded/"
    )


@pytest.fixture(scope="session")
def live(request) -> bool:
    return bool(request.config.getoption("--live"))


@pytest.fixture(scope="session")
def record(request, live) -> bool:
    return live and bool(request.config.getoption("--record"))


@pytest.fixture(scope="session")
def model_keys(live):
    """With --live, puts the two keys in the environment the way Cloud Functions does."""
    if not live:
        return
    import _env

    os.environ.setdefault("BASETEN_API_KEY", _env.key("BASETEN_API_KEY"))
    os.environ.setdefault("MODEL_API_KEY", _env.key("MODEL_API_KEY"))
