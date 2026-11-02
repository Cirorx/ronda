"""The card eval's options and session results (see test_card_eval.py)."""

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
        "--live",
        action="store_true",
        default=False,
        help="Run against the real models (keys through scripts/smoke/_env.py; never printed).",
    )


@pytest.fixture(scope="session")
def live(request) -> bool:
    return bool(request.config.getoption("--live"))


@pytest.fixture(scope="session")
def model_keys(live):
    """With --live, puts the two keys in the environment the way Cloud Functions does, read
    only through `_env.key()`; nothing here prints them."""
    if not live:
        return
    import _env

    os.environ.setdefault("BASETEN_API_KEY", _env.key("BASETEN_API_KEY"))
    os.environ.setdefault("MODEL_API_KEY", _env.key("MODEL_API_KEY"))
