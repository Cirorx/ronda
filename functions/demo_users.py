"""Which sign-ups count: the invented `demo-` ones stay out of the real project's numbers.

scripts/reset.py seeds the invented sign-ups under the emulators and, for demos, on the real
project too. They count under the Functions emulator and on Firebase's `demo-*` projects, so
demos and tests have people to show. On any other project Cerca's counts
(cerca_tuyo.run_refresh_cerca) and the solver's input (proposals.propose) leave them out
(docs/ARCHITECTURE.md § Demo data).
"""

import os

DEMO_UID_PREFIX = "demo-"
"""Every invented sign-up's uid starts with it: the rules leave no room for a label field on
`users/{uid}`, so the id is the label. scripts/reset.py's `is_demo_uid` is the same test, kept
there because the scripts don't import functions/; scripts/tests/test_demo_uids.py checks that
the two agree."""

DEMO_PROJECT_PREFIX = "demo-"
"""Firebase's demo projects: emulator-only, so nothing on one is real."""


def is_demo_uid(uid: object) -> bool:
    """Whether `uid` is one of the invented sign-ups."""
    return str(uid).startswith(DEMO_UID_PREFIX)


def demo_counts_here() -> bool:
    """Whether the invented sign-ups count where this runs: under the Functions emulator or on
    a `demo-*` project. Read at call time, like fcm.py; a project with no id counts as real."""
    return os.environ.get("FUNCTIONS_EMULATOR") == "true" or os.environ.get(
        "GCLOUD_PROJECT", ""
    ).startswith(DEMO_PROJECT_PREFIX)


def counts(uid: object) -> bool:
    """Whether `uid` counts here: every uid where demo sign-ups count, elsewhere every uid but
    theirs."""
    return not is_demo_uid(uid) or demo_counts_here()
