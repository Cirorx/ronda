"""Ronda's Cloud Functions (Python 3.13, 2nd gen).

Every function runs in southamerica-east1 next to Firestore and Storage, and
sets ``max_instances`` so a loop or a flood can't run up the bill.
"""

import firebase_admin
from firebase_functions import https_fn, options, params, scheduler_fn

REGION = "southamerica-east1"

options.set_global_options(region=REGION, max_instances=2)

# Meta Model API key, from Secret Manager (`firebase functions:secrets:set MODEL_API_KEY`).
MODEL_API_KEY = params.SecretParam("MODEL_API_KEY")


# Callables verify the caller's ID token with the default Admin app, so it must exist before
# the first request, not only when a function first touches Firestore.
firebase_admin.initialize_app()


@https_fn.on_request(region=REGION, max_instances=1)
def ping(req: https_fn.Request) -> https_fn.Response:
    """Answers that the functions runtime is up. Reads nothing, writes nothing."""
    return https_fn.Response(
        '{"ok": true, "region": "' + REGION + '"}',
        status=200,
        content_type="application/json",
    )


# Callables check auth in code; Cloud Run must let the request reach it.
@https_fn.on_call(
    region=REGION,
    max_instances=1,
    memory=options.MemoryOption.MB_512,
    invoker="public",
)
def solver_ping(req: https_fn.CallableRequest) -> dict:
    """Solves a three-variable CP-SAT model to prove OR-Tools loads and runs here."""
    from ortools.sat.python import cp_model

    model = cp_model.CpModel()
    x, y, z = (model.new_int_var(0, 10, name) for name in "xyz")
    model.add(x + y + z == 12)
    model.add(x > y)
    model.maximize(z - x)
    solver = cp_model.CpSolver()
    status = solver.solve(model)
    return {"status": solver.status_name(status), "objective": solver.objective_value}


def _require_admin(req: https_fn.CallableRequest) -> str:
    """The caller's uid, if their token carries the admin claim (scripts/set_admin.py)."""
    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "sign in first")
    if req.auth.token.get("admin") is not True:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.PERMISSION_DENIED, "admins only")
    return req.auth.uid


def _firestore():
    from firebase_admin import firestore

    return firestore.client()


def _bucket():
    from firebase_admin import storage

    return storage.bucket()


def _now():
    from datetime import UTC, datetime

    return datetime.now(UTC)


def _proposal_id(req: https_fn.CallableRequest) -> str:
    proposal_id = (req.data or {}).get("proposalId")
    if not isinstance(proposal_id, str) or not proposal_id or "/" in proposal_id:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "proposalId is required"
        )
    return proposal_id


# The solver uses every core for 8 s, then 2 s for the alternative (solver/README.md § Limits):
# 4 vCPUs need 2 GiB on Cloud Run. No min instances: the admin waits out a cold start.
@https_fn.on_call(
    region=REGION,
    max_instances=1,
    memory=options.MemoryOption.GB_2,
    cpu=4,
    timeout_sec=60,
    invoker="public",
)
def propose_groups(req: https_fn.CallableRequest) -> dict:
    """Solves the current sign-ups into a pending `proposals/{id}`. Admin only."""
    admin_uid = _require_admin(req)
    import proposals

    return proposals.propose(_firestore(), admin_uid, _now())


@https_fn.on_call(
    region=REGION,
    max_instances=1,
    memory=options.MemoryOption.MB_512,
    invoker="public",
)
def approve_proposal(req: https_fn.CallableRequest) -> dict:
    """Approves a pending proposal into rondas, or with `undo: true` takes an approval back.
    Admin only."""
    admin_uid = _require_admin(req)
    proposal_id = _proposal_id(req)
    import proposals

    try:
        if (req.data or {}).get("undo") is True:
            return proposals.undo_approval(_firestore(), proposal_id)
        return proposals.approve(_firestore(), proposal_id, admin_uid, _now())
    except proposals.ProposalError as error:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(error.code), str(error)) from error


@https_fn.on_call(
    region=REGION,
    max_instances=2,
    timeout_sec=120,
    memory=options.MemoryOption.MB_512,
    secrets=[MODEL_API_KEY],
    invoker="public",
)
def extract(req: https_fn.CallableRequest) -> dict:
    """Reads the caller's voice note at `audio/{uid}/{id}.wav` into sign-up fields.

    Voice Transcribe, then Spark 1.3; the note is deleted before the answer goes back. Refuses
    callers who haven't accepted the terms (`users/{uid}.terms`).
    """
    import httpx
    from google.api_core.exceptions import NotFound
    from openai import OpenAI

    import voice_signup as voice

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Sign in first.")
    uid = req.auth.uid
    path = req.data.get("path") if isinstance(req.data, dict) else None
    user = _firestore().collection("users").document(uid).get().to_dict()
    bucket = _bucket()
    key = MODEL_API_KEY.value
    error = https_fn.FunctionsErrorCode
    try:
        with httpx.Client() as http:
            return voice.read_voice_note(
                uid=uid,
                path=path,
                user=user,
                blob=bucket.blob,
                api_key=key,
                http=http,
                client=OpenAI(base_url=voice.META_BASE, api_key=key, timeout=60, max_retries=2),
            )
    except voice.TermsMissing as e:
        raise https_fn.HttpsError(error.FAILED_PRECONDITION, "Accept the terms first.") from e
    except voice.BadVoiceNote as e:
        raise https_fn.HttpsError(error.INVALID_ARGUMENT, "We couldn't read the note.") from e
    except PermissionError as e:
        raise https_fn.HttpsError(error.PERMISSION_DENIED, "Not your note.") from e
    except NotFound as e:
        raise https_fn.HttpsError(error.NOT_FOUND, "No note at that path.") from e
    except voice.ModelUnavailable as e:
        raise https_fn.HttpsError(error.UNAVAILABLE, "Try again in a moment.") from e


# SAM 3.1 and Muse Image run side by side (~20 s); Pillow composes a 1240 × 1754 flyer.
@https_fn.on_call(
    region=REGION,
    max_instances=2,
    timeout_sec=120,
    memory=options.MemoryOption.GB_1,
    secrets=[MODEL_API_KEY],
    invoker="public",
)
def make_mate_flyer(req: https_fn.CallableRequest) -> dict:
    """Makes the "Un mate de más" flyer from the caller's blurred photo at
    `flyer_photos/{uid}/{id}.jpg` for ronda `rondaId` (`mate_flyer.py`). The photo is deleted
    whatever happens."""
    import mate_flyer

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Sign in first.")
    try:
        return mate_flyer.make_mate_flyer(
            uid=req.auth.uid,
            data=req.data,
            db=_firestore(),
            bucket=_bucket(),
            api_key=MODEL_API_KEY.value,
            now=_now(),
        )
    except mate_flyer.FlyerError as error:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(error.code), str(error)) from error


# Delete-on-success in `extract` is the main control and the bucket's 1-day lifecycle rule the
# backstop; this catches what the first missed within the hour. It only lists and deletes.
@scheduler_fn.on_schedule(schedule="every 1 hours", region=REGION, max_instances=1)
def sweep_audio(event: scheduler_fn.ScheduledEvent) -> None:
    """Deletes every voice note under `audio/` created more than an hour before this run."""
    import audio_sweeper

    audio_sweeper.run_sweep_audio(_bucket(), event.schedule_time)


# The hourly dispatcher (#28) should adopt cerca_tuyo.run_refresh_cerca and drop this schedule.
@scheduler_fn.on_schedule(
    schedule="every 1 hours",
    region=REGION,
    max_instances=1,
    memory=options.MemoryOption.MB_512,
)
def refresh_cerca(event: scheduler_fn.ScheduledEvent) -> None:
    """Rewrites the per-barrio counts Cerca tuyo reads (`cerca/{barrio}`)."""
    import cerca_tuyo

    cerca_tuyo.run_refresh_cerca(_firestore(), event.schedule_time)


# Public, no login: Hosting rewrites /api/f/** here (firebase.json) for the tear-off flyer's page,
# so Cloud Run must let every request through.
@https_fn.on_request(region=REGION, max_instances=2, invoker="public")
def flyer_landing(req: https_fn.Request) -> https_fn.Response:
    """Counts a scan of a tear-off flyer (POST) and answers what its page `/f/{id}` shows."""
    import cerca_tuyo

    status, body = cerca_tuyo.landing(_firestore(), req.method, req.path, _now())
    return https_fn.Response(
        body, status=status, content_type="application/json", headers={"Cache-Control": "no-store"}
    )
