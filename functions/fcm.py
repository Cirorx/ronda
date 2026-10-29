"""Sending through Firebase Cloud Messaging: the jobs build HTTP v1 message dicts
(rsvp.rsvp_messages) and `send` delivers them with the Admin SDK.

Under the functions emulator nothing is sent: FCM has no emulator, and a test ronda must never
reach a real phone by accident. Nothing here logs a token.
"""

import os

BATCH = 500
"""`messaging.send_each` takes at most 500 messages."""


def app_url() -> str:
    """Where a web notification opens the app: Mi ronda on the project's own Hosting."""
    project = os.environ.get("GCLOUD_PROJECT", "ronda-uy")
    return f"https://{project}.firebaseapp.com/app/ronda"


def message(fields: dict):
    """An HTTP v1 message dict as the Admin SDK's `messaging.Message`.

    `token` is a registration token, which firebase-admin 7 deprecates for installation ids;
    the app saves registration tokens until the sender moves (docs/STACK.md § Push).
    """
    from firebase_admin import messaging

    notification = fields.get("notification")
    webpush = fields.get("webpush")
    android = fields.get("android")
    return messaging.Message(
        token=fields["token"],
        data=fields.get("data"),
        notification=messaging.Notification(**notification) if notification else None,
        android=messaging.AndroidConfig(priority=android["priority"].lower()) if android else None,
        webpush=messaging.WebpushConfig(
            fcm_options=messaging.WebpushFCMOptions(link=webpush["fcm_options"]["link"])
        )
        if webpush
        else None,
    )


def send(messages: list[dict]) -> list[str]:
    """Sends each message: `ok`, `unregistered` (a token FCM no longer knows) or `failed`, in
    order; `skipped` for every one under the functions emulator."""
    if os.environ.get("FUNCTIONS_EMULATOR") == "true":
        return ["skipped"] * len(messages)
    from firebase_admin import messaging

    outcomes = []
    for start in range(0, len(messages), BATCH):
        batch = [message(fields) for fields in messages[start : start + BATCH]]
        for response in messaging.send_each(batch).responses:
            if response.success:
                outcomes.append("ok")
            elif isinstance(response.exception, messaging.UnregisteredError):
                outcomes.append("unregistered")
            else:
                outcomes.append("failed")
    return outcomes
