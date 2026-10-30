"""reset.py's demo-uid test and functions/demo_users.py's are one rule: a uid that starts with
`demo-` is invented. Runs without the emulators. Every uid is invented."""

import importlib.util
from pathlib import Path

import pytest

import reset

FUNCTIONS_DEMO_USERS = Path(__file__).resolve().parents[2] / "functions" / "demo_users.py"
UIDS = ["demo-001", "demo-host", "demo-", "demo", "Demo-001", "my-demo-001", "Xb3kQ9", "", None]


def functions_demo_users():
    """functions/demo_users.py, loaded from its file: it imports nothing but the standard
    library, and the scripts never import functions/ otherwise."""
    spec = importlib.util.spec_from_file_location("functions_demo_users", FUNCTIONS_DEMO_USERS)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_the_functions_keep_out_the_same_uids_reset_deletes():
    demo_users = functions_demo_users()

    assert demo_users.DEMO_UID_PREFIX == reset.DEMO_UID_PREFIX
    assert [demo_users.is_demo_uid(uid) for uid in UIDS] == [reset.is_demo_uid(uid) for uid in UIDS]


@pytest.mark.parametrize(
    ("uids", "demo"),
    [
        (["demo-001", "demo-002"], True),
        (["demo-001", "Xb3kQ9"], False),
        (["Xb3kQ9"], False),
        ([], False),
    ],
)
def test_built_from_demo_needs_at_least_one_uid_and_every_one_a_demo_uid(uids, demo):
    assert reset.built_from_demo(uids) is demo
