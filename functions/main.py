"""Ronda's Cloud Functions (Python 3.13, 2nd gen).

Every function runs in southamerica-east1 next to Firestore and Storage, and
sets ``max_instances`` so a loop or a flood can't run up the bill.
"""

from firebase_functions import https_fn, options

REGION = "southamerica-east1"

options.set_global_options(region=REGION, max_instances=2)


@https_fn.on_request(region=REGION, max_instances=1)
def ping(req: https_fn.Request) -> https_fn.Response:
    """Answers that the functions runtime is up. Reads nothing, writes nothing."""
    return https_fn.Response(
        '{"ok": true, "region": "' + REGION + '"}',
        status=200,
        content_type="application/json",
    )
