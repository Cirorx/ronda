import re
import tomllib
from pathlib import Path

import pytest

import reset
import seed

SCRIPTS = Path(__file__).resolve().parents[1]


def _inline_metadata(script: Path) -> dict:
    """The PEP 723 `# /// script` block of `script`, parsed."""
    block = re.search(r"^# /// script\n(.*?)^# ///$", script.read_text(), re.DOTALL | re.MULTILINE)
    assert block, script
    return tomllib.loads(re.sub(r"^# ?", "", block.group(1), flags=re.MULTILINE))


@pytest.fixture
def no_emulators(monkeypatch):
    monkeypatch.delenv("FIRESTORE_EMULATOR_HOST", raising=False)
    monkeypatch.delenv("FIREBASE_AUTH_EMULATOR_HOST", raising=False)
    monkeypatch.setattr(seed, "seed", _never)
    monkeypatch.setattr(reset, "clear", _never)


def _never(*args):
    raise AssertionError("reached the database")


@pytest.mark.parametrize("script", ["seed.py", "reset.py"])
def test_the_inline_dependencies_are_the_project_ones(script):
    project = tomllib.loads((SCRIPTS / "pyproject.toml").read_text())["project"]

    metadata = _inline_metadata(SCRIPTS / script)

    assert metadata["dependencies"] == project["dependencies"]
    assert metadata["requires-python"] == project["requires-python"]


def test_seed_refuses_to_run_without_the_firestore_emulator(no_emulators, capsys):
    assert seed.main(["30"]) == 1
    assert "FIRESTORE_EMULATOR_HOST" in capsys.readouterr().out


def test_reset_refuses_to_run_without_the_auth_emulator(no_emulators, monkeypatch, capsys):
    monkeypatch.setenv("FIRESTORE_EMULATOR_HOST", "127.0.0.1:8088")

    assert reset.main([]) == 1
    assert "FIREBASE_AUTH_EMULATOR_HOST" in capsys.readouterr().out


def test_reset_refuses_to_run_without_the_firestore_emulator(no_emulators, monkeypatch, capsys):
    monkeypatch.setenv("FIREBASE_AUTH_EMULATOR_HOST", "127.0.0.1:9099")

    assert reset.main([]) == 1
    assert "FIRESTORE_EMULATOR_HOST" in capsys.readouterr().out


@pytest.mark.parametrize("people", ["31", "0"])
def test_seed_takes_only_the_thirty_or_two_hundred_set(no_emulators, people):
    with pytest.raises(SystemExit):
        seed.main([people])


def test_the_project_is_gcloud_project_when_set(monkeypatch):
    monkeypatch.setenv("GCLOUD_PROJECT", "demo-elsewhere")

    assert seed.project_id() == "demo-elsewhere"


def test_the_project_is_the_firebaserc_default_otherwise(monkeypatch):
    monkeypatch.delenv("GCLOUD_PROJECT", raising=False)

    assert seed.project_id() == "ronda-uy"


def test_reset_names_the_project_flag_when_it_refuses(no_emulators, capsys):
    assert reset.main([]) == 1
    assert "--project" in capsys.readouterr().out
