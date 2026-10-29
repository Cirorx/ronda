# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["firebase-admin==7.7.0"]
# ///
"""Give a signed-in account the admin custom claim, which opens the approval screen.

The account must exist first: the owner signs in to the app once, then, from the repo root:

    uv run --python 3.13 scripts/set_admin.py <email>             # the real project
    FIREBASE_AUTH_EMULATOR_HOST=127.0.0.1:9099 \\
        uv run --python 3.13 scripts/set_admin.py <email>         # the Auth emulator

The real project needs Application Default Credentials with rights on it
(`gcloud auth application-default login`). `--revoke` takes the claim away. Other custom claims
are kept. The app reads the claim from a fresh ID token, so sign out and in again (or wait up to
an hour) after running it. The project is GCLOUD_PROJECT, else .firebaserc's default.
"""

import argparse
import json
import os
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def project_id() -> str:
    if project := os.environ.get("GCLOUD_PROJECT"):
        return project
    return json.loads((ROOT / ".firebaserc").read_text())["projects"]["default"]


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    parser.add_argument("email", help="the account's email, as it signed in")
    parser.add_argument("--revoke", action="store_true", help="remove the claim instead")
    args = parser.parse_args(argv)

    import firebase_admin
    from firebase_admin import auth

    project = project_id()
    firebase_admin.initialize_app(options={"projectId": project})
    try:
        user = auth.get_user_by_email(args.email)
    except auth.UserNotFoundError:
        print(f"No account for that email in {project}: sign in to the app once first.")
        return 1
    claims = dict(user.custom_claims or {})
    if args.revoke:
        claims.pop("admin", None)
    else:
        claims["admin"] = True
    auth.set_custom_user_claims(user.uid, claims or None)
    where = "the Auth emulator" if os.environ.get("FIREBASE_AUTH_EMULATOR_HOST") else project
    print(f"{'Removed' if args.revoke else 'Set'} the admin claim for uid {user.uid} in {where}.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
