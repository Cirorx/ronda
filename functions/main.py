"""Ronda's Cloud Functions (Python 3.13, 2nd gen).

Every function runs in southamerica-east1 next to Firestore and Storage, and
sets ``max_instances`` so a loop or a flood can't run up the bill.
"""

import firebase_admin
from firebase_functions import firestore_fn, https_fn, options, params, scheduler_fn

REGION = "southamerica-east1"

options.set_global_options(region=REGION, max_instances=2)

# Meta Model API key, from Secret Manager (`firebase functions:secrets:set MODEL_API_KEY`).
MODEL_API_KEY = params.SecretParam("MODEL_API_KEY")
# Baseten key for the organiser agent's Muse Spark Open (`functions:secrets:set BASETEN_API_KEY`).
BASETEN_API_KEY = params.SecretParam("BASETEN_API_KEY")
# The Intendencia de Montevideo's public-transport API, for the day-of reminder's next buses
# (`functions:secrets:set MVD_API_CLIENT_ID` and `MVD_API_SECRET_ID`; mvd_buses.py).
MVD_API_CLIENT_ID = params.SecretParam("MVD_API_CLIENT_ID")
MVD_API_SECRET_ID = params.SecretParam("MVD_API_SECRET_ID")


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
    """Approves a pending proposal into rondas, with `undo: true` takes an approval back, and
    with `stop: true` stops an auto proposal from approving itself ([Frenar]). Admin only."""
    admin_uid = _require_admin(req)
    proposal_id = _proposal_id(req)
    import proposals

    data = req.data or {}
    try:
        if data.get("undo") is True:
            return proposals.undo_approval(_firestore(), proposal_id, admin_uid, _now())
        if data.get("stop") is True:
            return proposals.stop(_firestore(), proposal_id, admin_uid, _now())
        return proposals.approve(_firestore(), proposal_id, admin_uid, _now())
    except proposals.ProposalError as error:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(error.code), str(error)) from error


@https_fn.on_call(
    region=REGION,
    max_instances=1,
    memory=options.MemoryOption.MB_512,
    invoker="public",
)
def set_auto_form(req: https_fn.CallableRequest) -> dict:
    """Turns rondas forming themselves on or off and sets the hold before they approve
    themselves: `{enabled, holdMinutes}` (auto_form.py). Admin only."""
    admin_uid = _require_admin(req)
    import auto_form

    try:
        return auto_form.set_config(_firestore(), req.data, admin_uid, _now())
    except auto_form.ConfigError as error:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(error.code), str(error)) from error


# One instance stays warm: a cold Python start added seconds to the wait after a voice note.
@https_fn.on_call(
    region=REGION,
    min_instances=1,
    max_instances=2,
    timeout_sec=120,
    memory=options.MemoryOption.MB_512,
    secrets=[MODEL_API_KEY],
    invoker="public",
)
def extract(req: https_fn.CallableRequest) -> dict:
    """Reads the caller's voice note at `audio/{uid}/{id}.wav` into sign-up fields.

    Voice Transcribe, then Spark 1.3; the note is deleted before the answer goes back. Refuses
    callers who haven't accepted the terms (`users/{uid}.terms`). `{path}` does both; with
    `stage: "listen"` it answers `{transcript}` only, so the app can show the words while
    `read_transcript` reads them into fields.
    """
    import httpx
    from google.api_core.exceptions import NotFound
    from openai import OpenAI

    import voice_signup as voice

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Sign in first.")
    uid = req.auth.uid
    data = req.data if isinstance(req.data, dict) else {}
    path = data.get("path")
    stage = data.get("stage")
    user = _firestore().collection("users").document(uid).get().to_dict()
    key = MODEL_API_KEY.value
    error = https_fn.FunctionsErrorCode

    try:
        bucket = _bucket()
        with httpx.Client() as http:
            if stage == "listen":
                return voice.listen_to_note(
                    uid=uid, path=path, user=user, blob=bucket.blob, api_key=key, http=http
                )
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


@https_fn.on_call(
    region=REGION,
    max_instances=2,
    timeout_sec=60,
    memory=options.MemoryOption.MB_512,
    secrets=[MODEL_API_KEY],
    invoker="public",
)
def read_transcript(req: https_fn.CallableRequest) -> dict:
    """Reads words Voice Transcribe heard live (`relay/`, `{text}`) into sign-up fields with
    Spark 1.3, as `extract` does after transcribing a note. Nothing is stored. Refuses callers
    who haven't accepted the terms (`users/{uid}.terms`)."""
    from openai import OpenAI

    import voice_signup as voice

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Sign in first.")
    uid = req.auth.uid
    text = req.data.get("text") if isinstance(req.data, dict) else None
    user = _firestore().collection("users").document(uid).get().to_dict()
    key = MODEL_API_KEY.value
    error = https_fn.FunctionsErrorCode
    try:
        return voice.read_transcript(
            uid=uid,
            text=text,
            user=user,
            client=OpenAI(base_url=voice.META_BASE, api_key=key, timeout=60, max_retries=2),
        )
    except voice.TermsMissing as e:
        raise https_fn.HttpsError(error.FAILED_PRECONDITION, "Accept the terms first.") from e
    except voice.BadVoiceNote as e:
        raise https_fn.HttpsError(error.INVALID_ARGUMENT, "We couldn't read the note.") from e
    except voice.ModelUnavailable as e:
        raise https_fn.HttpsError(error.UNAVAILABLE, "Try again in a moment.") from e


@https_fn.on_call(
    region=REGION,
    max_instances=2,
    timeout_sec=120,
    memory=options.MemoryOption.MB_512,
    secrets=[MODEL_API_KEY],
    invoker="public",
)
def read_line(req: https_fn.CallableRequest) -> dict:
    """Reads the caller's short voice note at `audio/{uid}/{id}.wav` into the words it says, for
    the cuaderno (`cuaderno.py`). Voice Transcribe only; the note is deleted before the answer
    goes back and nothing is stored. Refuses callers who haven't accepted the terms."""
    import httpx
    from google.api_core.exceptions import NotFound

    import cuaderno
    import voice_signup as voice

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Sign in first.")
    uid = req.auth.uid
    path = req.data.get("path") if isinstance(req.data, dict) else None
    user = _firestore().collection("users").document(uid).get().to_dict()
    error = https_fn.FunctionsErrorCode
    try:
        with httpx.Client() as http:
            return cuaderno.read_line(
                uid=uid,
                path=path,
                user=user,
                blob=_bucket().blob,
                api_key=MODEL_API_KEY.value,
                http=http,
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


# Spark 1.3 then Muse Image, one after the other (~15 s). Unlike the flyer's, this callable is
# given no Storage bucket and writes no document: the lines come in the payload and the postcard
# goes back in the answer.
@https_fn.on_call(
    region=REGION,
    max_instances=2,
    timeout_sec=120,
    memory=options.MemoryOption.MB_512,
    secrets=[MODEL_API_KEY],
    invoker="public",
)
def make_postcard(req: https_fn.CallableRequest) -> dict:
    """Draws the cuaderno's weekly postcard from the week's lines in `lines` (`cuaderno.py`) and
    answers it as a base64 JPEG. Stores nothing."""
    from openai import OpenAI

    import cuaderno
    import voice_signup as voice

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Sign in first.")
    uid = req.auth.uid
    user = _firestore().collection("users").document(uid).get().to_dict()
    key = MODEL_API_KEY.value
    try:
        return cuaderno.make_postcard(
            uid=uid,
            data=req.data,
            user=user,
            client=OpenAI(base_url=voice.META_BASE, api_key=key, timeout=60, max_retries=2),
            painter=cuaderno.MetaPainter(key),
        )
    except cuaderno.PostcardError as error:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(error.code), str(error)) from error


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


# --- The weekly loop (#45): the RSVP push, the answers and the jobs' dispatcher -------------

MONTEVIDEO = "America/Montevideo"


# On the hour in Montevideo, so a 19:00 lead time goes out at 19:00. `auto_form` runs the
# solver here (8 s on every core, then 2 s): 2 vCPUs need 1 GiB on Cloud Run.
@scheduler_fn.on_schedule(
    schedule="0 * * * *",
    timezone=scheduler_fn.Timezone(MONTEVIDEO),
    region=REGION,
    max_instances=1,
    timeout_sec=300,
    memory=options.MemoryOption.GB_1,
    cpu=2,
    secrets=[MODEL_API_KEY, BASETEN_API_KEY, MVD_API_CLIENT_ID, MVD_API_SECRET_ID],
)
def dispatch(event: scheduler_fn.ScheduledEvent) -> None:
    """Runs every job that is due at the scheduled time (jobs.JOBS)."""
    import jobs

    jobs.run_due(_firestore(), event.schedule_time, jobs.context())


@https_fn.on_call(
    region=REGION,
    max_instances=1,
    timeout_sec=300,
    memory=options.MemoryOption.GB_1,
    cpu=2,
    secrets=[MODEL_API_KEY, BASETEN_API_KEY, MVD_API_CLIENT_ID, MVD_API_SECRET_ID],
    invoker="public",
)
def run_job(req: https_fn.CallableRequest) -> dict:
    """Runs one job by `name` now, or at `now` (ISO 8601 with an offset) for tests and the demo.
    `force: true` skips the job's own timing, as the admin's "send the RSVP now". Admin only."""
    from datetime import datetime

    import jobs

    _require_admin(req)
    data = req.data if isinstance(req.data, dict) else {}
    error = https_fn.FunctionsErrorCode.INVALID_ARGUMENT
    now = _now()
    if (at := data.get("now")) is not None:
        try:
            now = datetime.fromisoformat(at)
        except (TypeError, ValueError) as e:
            raise https_fn.HttpsError(error, "now is an ISO 8601 time") from e
        if now.tzinfo is None:
            raise https_fn.HttpsError(error, "now needs an offset")
    name = data.get("name")
    try:
        counts = jobs.run(name, _firestore(), now, jobs.context(force=data.get("force") is True))
    except jobs.UnknownJob as e:
        raise https_fn.HttpsError(error, "no such job") from e
    return {"name": name, **counts}


# Several members can answer in the same minute the push lands.
@https_fn.on_call(
    region=REGION,
    max_instances=5,
    memory=options.MemoryOption.MB_512,
    invoker="public",
)
def answer_rsvp(req: https_fn.CallableRequest) -> dict:
    """Records the caller's "voy" or "esta no" for their ronda's upcoming meeting:
    `{rondaId, answer: yes | no, week?, pauseWeeks?}`. Members of that ronda only."""
    import rsvp

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "sign in first")
    data = req.data if isinstance(req.data, dict) else {}
    ronda_id, week = data.get("rondaId"), data.get("week")
    if not isinstance(ronda_id, str) or not ronda_id or "/" in ronda_id:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "rondaId is required"
        )
    if week is not None and not isinstance(week, str):
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "week is a string")
    try:
        return rsvp.answer(
            _firestore(),
            req.auth.uid,
            ronda_id,
            data.get("answer"),
            _now(),
            week=week,
            pause_weeks=data.get("pauseWeeks"),
        )
    except rsvp.RsvpError as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


# --- ¿Seguimos? (#46): the private question after a ronda's first meeting ------------------


@https_fn.on_call(
    region=REGION,
    max_instances=5,
    memory=options.MemoryOption.MB_512,
    invoker="public",
)
def answer_seguimos(req: https_fn.CallableRequest) -> dict:
    """Records the caller's "sí" or "no" while their ronda's ¿seguimos? is open,
    `{rondaId, answer: yes | no}`, or after a close below the floor their pick,
    `{rondaId, choice: join | wait}`. Members of that ronda only."""
    import seguimos

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "sign in first")
    data = req.data if isinstance(req.data, dict) else {}
    ronda_id = data.get("rondaId")
    if not isinstance(ronda_id, str) or not ronda_id or "/" in ronda_id:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "rondaId is required"
        )
    try:
        return seguimos.answer(
            _firestore(),
            req.auth.uid,
            ronda_id,
            _now(),
            value=data.get("answer"),
            choice=data.get("choice"),
        )
    except seguimos.SeguimosError as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


# --- The organiser agent (#49): the host's pick after the rain check -----------------------


@https_fn.on_call(
    region=REGION,
    max_instances=2,
    memory=options.MemoryOption.MB_512,
    invoker="public",
)
def answer_move(req: https_fn.CallableRequest) -> dict:
    """Records the host's pick for a rain proposal and sends its one message to the members:
    `{rondaId, week, choice: covered | postpone | asIs}`. The proposal's host only (rain.py)."""
    import jobs
    import rain

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "sign in first")
    data = req.data if isinstance(req.data, dict) else {}
    ronda_id, week, choice = data.get("rondaId"), data.get("week"), data.get("choice")
    if not all(isinstance(v, str) and v and "/" not in v for v in (ronda_id, week, choice)):
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "rondaId, week and choice are required"
        )
    context = jobs.context()
    try:
        return rain.answer_move(
            _firestore(),
            req.auth.uid,
            ronda_id,
            week,
            choice,
            _now(),
            send=context.send,
            app_url=context.app_url,
        )
    except rain.MoveError as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


# --- The pilot's admin (#55): who to add to a ronda, adding them, and the pilot's numbers -----


def _ronda_id(req: https_fn.CallableRequest) -> str:
    ronda_id = (req.data if isinstance(req.data, dict) else {}).get("rondaId")
    if not isinstance(ronda_id, str) or not ronda_id or "/" in ronda_id:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "rondaId is required"
        )
    return ronda_id


@https_fn.on_call(
    region=REGION, max_instances=1, memory=options.MemoryOption.MB_512, invoker="public"
)
def ronda_candidates(req: https_fn.CallableRequest) -> dict:
    """Who the admin could add to ronda `rondaId`, with what doesn't match it. Admin only."""
    _require_admin(req)
    ronda_id = _ronda_id(req)
    import ronda_members

    try:
        return ronda_members.candidates(_firestore(), ronda_id)
    except ronda_members.MemberError as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


@https_fn.on_call(
    region=REGION, max_instances=1, memory=options.MemoryOption.MB_512, invoker="public"
)
def add_to_ronda(req: https_fn.CallableRequest) -> dict:
    """ "Sumar a esta ronda": adds sign-up `uid` to ronda `rondaId`; `move: true` takes them out
    of the ronda they are in. Admin only (ronda_members.py)."""
    _require_admin(req)
    ronda_id = _ronda_id(req)
    uid = req.data.get("uid")
    if not isinstance(uid, str) or not uid or "/" in uid:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.INVALID_ARGUMENT, "uid is required")
    import ronda_members

    try:
        return ronda_members.add(
            _firestore(), ronda_id, uid, _now(), move=req.data.get("move") is True
        )
    except ronda_members.MemberError as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


@https_fn.on_call(
    region=REGION, max_instances=1, memory=options.MemoryOption.MB_512, invoker="public"
)
def pilot_numbers(req: https_fn.CallableRequest) -> dict:
    """The pilot's numbers for /admin, demo sign-ups left out (pilot_numbers.py). Admin only."""
    _require_admin(req)
    import pilot_numbers as numbers

    return numbers.numbers(_firestore(), _now())


# --- Hosts, place and hour, and attendance (#47): hosts.py and attendance.py ---------------


def _setup_call(req: https_fn.CallableRequest, run):
    import hosts

    _require_admin(req)
    try:
        return run(hosts)
    except hosts.SetupError as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


@https_fn.on_call(
    region=REGION, max_instances=1, memory=options.MemoryOption.MB_512, invoker="public"
)
def ronda_setups(req: https_fn.CallableRequest) -> dict:
    """Every ronda that still meets with its place, hour, hosts and members. Admin only."""
    return _setup_call(req, lambda hosts: {"rondas": hosts.setups(_firestore(), _now())})


@https_fn.on_call(
    region=REGION, max_instances=1, memory=options.MemoryOption.MB_512, invoker="public"
)
def set_ronda_setup(req: https_fn.CallableRequest) -> dict:
    """Sets a ronda's public place, hour and hosts. Admin only."""
    return _setup_call(req, lambda hosts: hosts.set_setup(_firestore(), req.data, _now()))


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def record_attendance(req: https_fn.CallableRequest) -> dict:
    """Records one [Vino] / [No vino], `{rondaId, week, uid, came}`. The ronda's hosts or the
    admin (attendance.py)."""
    import attendance

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "sign in first")
    admin = req.auth.token.get("admin") is True
    try:
        return attendance.record(_firestore(), req.auth.uid, admin, req.data, _now())
    except attendance.AttendanceError as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


# --- The bench (#48, #50's offer_bench_seat): bench.py --------------------------------------


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def answer_bench_offer(req: https_fn.CallableRequest) -> dict:
    """[Lo tomo] or [Esta vez no] on the caller's own offer of a freed seat:
    `{offerId, take: true | false}` (bench.py)."""
    import bench

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "sign in first")
    data = req.data if isinstance(req.data, dict) else {}
    try:
        return bench.answer(
            _firestore(), req.auth.uid, data.get("offerId"), data.get("take"), _now()
        )
    except bench.BenchError as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


def _fields(snapshot) -> dict:
    return (snapshot.to_dict() or {}) if snapshot is not None and snapshot.exists else {}


def _run_bench(ronda_id: str) -> None:
    import bench
    import jobs

    context = jobs.context()
    bench.run_bench(
        _firestore(), _now(), send=context.send, app_url=context.app_url, ronda_id=ronda_id
    )


# The bench moves as soon as a member's answer changes or a person answers an offer, instead of
# waiting for the hourly dispatcher (which still runs it, for deadlines and anything missed).
@firestore_fn.on_document_written(
    document="rondas/{rondaId}/answers/{uid}",
    region=REGION,
    max_instances=1,
    timeout_sec=300,
    memory=options.MemoryOption.MB_512,
    secrets=[MODEL_API_KEY, BASETEN_API_KEY],
)
def bench_on_answer(event: firestore_fn.Event) -> None:
    """Runs ronda `rondaId`'s bench when a member's RSVP changes: an "esta no" frees a seat, a
    "voy" after one may take it back."""
    before, after = _fields(event.data.before), _fields(event.data.after)
    if (before.get("week"), before.get("answer")) != (after.get("week"), after.get("answer")):
        _run_bench(event.params["rondaId"])


@firestore_fn.on_document_updated(
    document="users/{uid}/offers/{offerId}",
    region=REGION,
    max_instances=1,
    timeout_sec=300,
    memory=options.MemoryOption.MB_512,
    secrets=[MODEL_API_KEY, BASETEN_API_KEY],
)
def bench_on_offer(event: firestore_fn.Event) -> None:
    """Runs the offer's ronda's bench when its person answers it: after "Esta vez no" the next
    person is offered the seat; after "Lo tomo" the trace and the host's summary catch up."""
    before, after = _fields(event.data.before), _fields(event.data.after)
    if before.get("status") == "pending" and after.get("status") in ("taken", "declined"):
        _run_bench(after["rondaId"])


# --- The waiting list's threshold and didn't-fill (#48): waitlists.py ------------------------


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def answer_waitlist(req: https_fn.CallableRequest) -> dict:
    """The caller's pick after their waiting list didn't fill: `{choice: join | wait}`
    (waitlists.py)."""
    import waitlists

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "sign in first")
    data = req.data if isinstance(req.data, dict) else {}
    try:
        return waitlists.answer(_firestore(), req.auth.uid, data.get("choice"), _now())
    except waitlists.WaitlistError as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


# --- The weekly loop's code jobs (#47, #50): the después, "¿Abrís vos?" and the buddy --------


def _member_call(req: https_fn.CallableRequest, refusal: type[Exception], run):
    """Runs `run()` for a signed-in caller, mapping a `refusal` to its code."""
    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "sign in first")
    try:
        return run()
    except refusal as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def set_despues(req: https_fn.CallableRequest) -> dict:
    """Sets the upcoming meeting's después, `{rondaId, week?, kind, what?, where?, homeOf?,
    address?}`. This week's hosts only (despues.py)."""
    import despues
    import jobs

    context = jobs.context()
    return _member_call(
        req,
        despues.DespuesError,
        lambda: despues.set_despues(
            _firestore(), req.auth.uid, req.data, _now(), send=context.send, app_url=context.app_url
        ),
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def answer_despues(req: https_fn.CallableRequest) -> dict:
    """The person whose home the después would be says yes or no, `{rondaId, week, answer}`."""
    import despues

    db = _firestore()
    return _member_call(
        req, despues.DespuesError, lambda: despues.answer(db, req.auth.uid, req.data, _now())
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def answer_handoff(req: https_fn.CallableRequest) -> dict:
    """ "Sí, abro yo" or "Hoy no puedo", `{rondaId, week, answer: yes | no}`, from a member
    asked "¿Abrís vos?" (handoff.py)."""
    import handoff
    import jobs

    context = jobs.context()
    return _member_call(
        req,
        handoff.HandoffError,
        lambda: handoff.answer(
            _firestore(), req.auth.uid, req.data, _now(), send=context.send, app_url=context.app_url
        ),
    )


def _welcome_call(req: https_fn.CallableRequest, run):
    """Runs `run()` for a signed-in caller; a refusal keeps its code, and a recognition line
    the gates held says which in `details.reason` (emoji, voseo, money, public_place)."""
    import first_visit

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "sign in first")
    try:
        return run()
    except first_visit.WelcomeError as e:
        details = {"reason": e.reason} if e.reason else None
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e), details) from e


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def set_welcome(req: https_fn.CallableRequest) -> dict:
    """A host picks who waits for a newcomer, `{rondaId, newcomerUid, waiterUid, sign?}`
    (first_visit.py). The ronda's anfitrión or cola only."""
    import first_visit

    return _welcome_call(
        req, lambda: first_visit.set_waiter(_firestore(), req.auth.uid, req.data, _now())
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def decline_welcome(req: https_fn.CallableRequest) -> dict:
    """The member a host picked to wait says "No puedo", `{rondaId, newcomerUid}`."""
    import first_visit

    return _welcome_call(
        req, lambda: first_visit.decline(_firestore(), req.auth.uid, req.data, _now())
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def buddy_options(req: https_fn.CallableRequest) -> dict:
    """Whether it is time to choose a buddy in ronda `rondaId`, who could be chosen, and who
    is (buddy.py). Members of that ronda only."""
    import buddy

    return _member_call(
        req, buddy.BuddyError, lambda: buddy.options(_firestore(), req.auth.uid, req.data, _now())
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def set_buddy(req: https_fn.CallableRequest) -> dict:
    """Chooses the caller's buddy in ronda `rondaId`, `{rondaId, buddyUid}`; `""` is nobody."""
    import buddy

    db = _firestore()
    return _member_call(req, buddy.BuddyError, lambda: buddy.choose(db, req.auth.uid, req.data))


# --- Monitoring: the web app's error log (Crashlytics covers Android and iOS) ---------------


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def report_client_error(req: https_fn.CallableRequest) -> dict:
    """Stores the web app's scrubbed error reports, `{reports: [{platform, appVersion, build,
    flavor, screen, step, code, message, stack, fatal}]}`, as `client_errors/{id}`. The one
    callable that takes signed-out callers: a sign-up that fails before sign-in must still be
    seen. Rate-limited per hashed uid or hashed IP (client_errors.py)."""
    import client_errors

    raw = getattr(req, "raw_request", None)
    ip = client_errors.requester_ip(
        getattr(raw, "headers", None), getattr(raw, "remote_addr", None)
    )
    uid = req.auth.uid if req.auth is not None else None
    try:
        return client_errors.report(_firestore(), req.data, uid=uid, ip=ip, now=_now())
    except client_errors.ClientErrorRefused as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


# --- ¿Dónde queda? (#58): the weekly barrio photo game ----------------------------------------


def _donde_queda_call(req: https_fn.CallableRequest, run):
    """Runs `run()` for a signed-in caller; a refusal keeps its code, and a refused photo says
    why in `details.reason` (houseNumber, person, empty, words)."""
    import donde_queda

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "sign in first")
    try:
        return run()
    except donde_queda.DondeQuedaError as e:
        details = {"reason": e.reason} if e.reason else None
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e), details) from e


@https_fn.on_call(
    region=REGION,
    max_instances=2,
    timeout_sec=120,
    memory=options.MemoryOption.GB_1,
    secrets=[MODEL_API_KEY],
    invoker="public",
)
def post_donde_queda(req: https_fn.CallableRequest) -> dict:
    """The member asked posts this week's photo, `{rondaId, week, photoPath, line, hint?, lat,
    lng}`: checked by SAM 3.1 and Spark 1.3, blurred and published under the ronda
    (donde_queda.py). The upload is deleted whatever happens."""
    import donde_queda

    return _donde_queda_call(
        req,
        lambda: donde_queda.post_photo(
            uid=req.auth.uid,
            data=req.data,
            db=_firestore(),
            bucket=_bucket(),
            api_key=MODEL_API_KEY.value,
            now=_now(),
        ),
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def pass_donde_queda(req: https_fn.CallableRequest) -> dict:
    """ "Esta semana no", `{rondaId, week}`: the turn passes on without saying why."""
    import donde_queda

    return _donde_queda_call(
        req, lambda: donde_queda.pass_turn(_firestore(), req.auth.uid, req.data, _now())
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def guess_donde_queda(req: https_fn.CallableRequest) -> dict:
    """One pin per member on this week's photo, `{rondaId, week, lat, lng}`."""
    import donde_queda

    return _donde_queda_call(
        req, lambda: donde_queda.guess(_firestore(), req.auth.uid, req.data, _now())
    )


# --- Algo chico esta semana (#56): nothing here writes a document ---------------------------


@https_fn.on_call(
    region=REGION,
    max_instances=3,
    timeout_sec=120,
    memory=options.MemoryOption.MB_512,
    secrets=[MODEL_API_KEY],
    invoker="public",
)
def shape_small_plan(req: https_fn.CallableRequest) -> dict:
    """Turns what the caller said into one small dated plan: `{text}` they typed or `{path}` of
    a voice note at `audio/{uid}/{id}.wav` (Voice Transcribe, deleted once read), then Spark
    1.3 and the filter, with the day from Open-Meteo. Answers `{plan}` or `{rejected}`; keeps
    nothing (`small_plans.py`)."""
    import httpx
    from google.api_core.exceptions import NotFound
    from openai import OpenAI

    import small_plans
    import voice_signup as voice
    from organiser.weather import OpenMeteo

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Sign in first.")
    uid = req.auth.uid
    user = _firestore().collection("users").document(uid).get().to_dict()
    key = MODEL_API_KEY.value
    error = https_fn.FunctionsErrorCode
    try:
        with httpx.Client() as http:
            return small_plans.shape_request(
                uid=uid,
                data=req.data,
                user=user,
                now=_now(),
                blob=_bucket().blob,
                api_key=key,
                http=http,
                client=OpenAI(base_url=voice.META_BASE, api_key=key, timeout=60, max_retries=2),
                weather=OpenMeteo(http),
            )
    except voice.TermsMissing as e:
        raise https_fn.HttpsError(error.FAILED_PRECONDITION, "Accept the terms first.") from e
    except (voice.BadVoiceNote, small_plans.BadWords) as e:
        raise https_fn.HttpsError(error.INVALID_ARGUMENT, "We couldn't read that.") from e
    except PermissionError as e:
        raise https_fn.HttpsError(error.PERMISSION_DENIED, "Not your note.") from e
    except NotFound as e:
        raise https_fn.HttpsError(error.NOT_FOUND, "No note at that path.") from e
    except voice.ModelUnavailable as e:
        raise https_fn.HttpsError(error.UNAVAILABLE, "Try again in a moment.") from e


@https_fn.on_call(
    region=REGION,
    max_instances=3,
    timeout_sec=90,
    memory=options.MemoryOption.MB_512,
    secrets=[MODEL_API_KEY, BASETEN_API_KEY],
    invoker="public",
)
def suggest_small_plans(req: https_fn.CallableRequest) -> dict:
    """Three suggestions for the caller's small plan this week: free places near their barrio
    from the OSM cache, a dry day from Open-Meteo, and Muse Spark Open's pick of three that fit
    what they like to do (the rules pick when it, and Spark 1.3 behind it, can't). Keeps
    nothing (`plan_suggestions.py`)."""
    import httpx

    import free_places
    import plan_suggestions
    from organiser.model import ModelUnavailable, from_environment
    from organiser.weather import OpenMeteo

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "Sign in first.")
    db = _firestore()
    user = db.collection("users").document(req.auth.uid).get().to_dict()
    try:
        model = from_environment()
    except ModelUnavailable:
        model = None
    with httpx.Client() as http:
        return plan_suggestions.suggest(
            user=user,
            places=free_places.nearby(db, (user or {}).get("barrio")),
            now=_now(),
            weather=OpenMeteo(http),
            model=model,
        )


# --- ¿Alguien se suma? (#57): a small plan opened to the ronda --------------------------------


def _shared_plan_call(req: https_fn.CallableRequest, run):
    """Runs `run()` for a signed-in caller; a refusal keeps its code, and a held plan says why
    in `details.reason` (past, time, words, money, address, phone, place, other)."""
    import shared_plans
    import voice_signup as voice

    if req.auth is None:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode.UNAUTHENTICATED, "sign in first")
    try:
        return run()
    except shared_plans.SharedPlanError as e:
        details = {"reason": e.reason} if e.reason else None
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e), details) from e
    except voice.ModelUnavailable as e:
        raise https_fn.HttpsError(
            https_fn.FunctionsErrorCode.UNAVAILABLE, "try again in a moment"
        ) from e


@https_fn.on_call(
    region=REGION,
    max_instances=2,
    timeout_sec=60,
    memory=options.MemoryOption.MB_512,
    secrets=[MODEL_API_KEY],
    invoker="public",
)
def share_small_plan(req: https_fn.CallableRequest) -> dict:
    """Opens the caller's small plan to their ronda, `{rondaId, activity, place?, kind, date,
    time}`: held, with the reason, when code or Spark 1.3 finds the place private, an address,
    a phone number, money or a bad hour (shared_plans.py)."""
    from openai import OpenAI

    import shared_plans
    import voice_signup as voice

    return _shared_plan_call(
        req,
        lambda: shared_plans.share(
            uid=req.auth.uid,
            data=req.data,
            db=_firestore(),
            checker=shared_plans.SparkPlan(
                OpenAI(
                    base_url=voice.META_BASE, api_key=MODEL_API_KEY.value, timeout=30, max_retries=2
                )
            ),
            now=_now(),
        ),
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def withdraw_small_plan(req: https_fn.CallableRequest) -> dict:
    """The author takes their shared plan back, `{rondaId}`."""
    import shared_plans

    return _shared_plan_call(
        req, lambda: shared_plans.withdraw(_firestore(), req.auth.uid, req.data, _now())
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def join_small_plan(req: https_fn.CallableRequest) -> dict:
    """ "Me sumo", `{rondaId, authorUid}`."""
    import shared_plans

    return _shared_plan_call(
        req, lambda: shared_plans.join(_firestore(), req.auth.uid, req.data, _now())
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def leave_small_plan(req: https_fn.CallableRequest) -> dict:
    """A member takes back their "Me sumo", `{rondaId, authorUid}`."""
    import shared_plans

    return _shared_plan_call(
        req, lambda: shared_plans.leave(_firestore(), req.auth.uid, req.data, _now())
    )


# --- Safety (#71): Contar algo que pasó, and the admin's queue -------------------------------


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def report_people(req: https_fn.CallableRequest) -> dict:
    """ "¿Con quién?": the other members of the caller's rondas by first name (reports.py)."""
    import reports

    return _member_call(
        req, reports.ReportError, lambda: reports.people(_firestore(), req.auth.uid)
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def send_report(req: https_fn.CallableRequest) -> dict:
    """Contar algo que pasó, `{text, tags, aboutUid}`: only the admin reads it; the caller keeps
    a receipt (reports.py)."""
    import reports

    return _member_call(
        req, reports.ReportError, lambda: reports.file(_firestore(), req.auth.uid, req.data, _now())
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def add_to_report(req: https_fn.CallableRequest) -> dict:
    """More words on the caller's own report, `{reportId, text}` (reports.py)."""
    import reports

    return _member_call(
        req, reports.ReportError, lambda: reports.add(_firestore(), req.auth.uid, req.data, _now())
    )


@https_fn.on_call(
    region=REGION, max_instances=2, memory=options.MemoryOption.MB_512, invoker="public"
)
def withdraw_report(req: https_fn.CallableRequest) -> dict:
    """[Retirar] on the caller's own report, `{reportId}`: it stays in the admin's queue,
    marked «retirado» (reports.py)."""
    import reports

    return _member_call(
        req,
        reports.ReportError,
        lambda: reports.withdraw(_firestore(), req.auth.uid, req.data, _now()),
    )


def _safety_call(req: https_fn.CallableRequest, run):
    """Runs `run(db)` for the admin only, mapping a refusal to its code."""
    import reports
    import safety

    _require_admin(req)
    try:
        return run(_firestore())
    except (reports.ReportError, safety.SafetyError) as e:
        raise https_fn.HttpsError(https_fn.FunctionsErrorCode(e.code), str(e)) from e


@https_fn.on_call(
    region=REGION, max_instances=1, memory=options.MemoryOption.MB_512, invoker="public"
)
def review_report(req: https_fn.CallableRequest) -> dict:
    """The admin reads, archives or reopens a report, `{reportId, action: read | archive |
    reopen}`. Admin only (reports.py)."""
    import reports

    return _safety_call(req, lambda db: reports.review(db, req.data, _now()))


@https_fn.on_call(
    region=REGION, max_instances=1, memory=options.MemoryOption.MB_512, invoker="public"
)
def separate_pair(req: https_fn.CallableRequest) -> dict:
    """[Separarlos] on a report, `{reportId}`: its two people are never seated together again.
    Admin only (safety.py)."""
    import safety

    return _safety_call(req, lambda db: safety.separate(db, req.data, _now()))


@https_fn.on_call(
    region=REGION, max_instances=1, memory=options.MemoryOption.MB_512, invoker="public"
)
def join_pair_again(req: https_fn.CallableRequest) -> dict:
    """[Juntarlos de nuevo], `{pairId}`. Admin only (safety.py)."""
    import safety

    return _safety_call(req, lambda db: safety.join_again(db, req.data))


@https_fn.on_call(
    region=REGION, max_instances=1, memory=options.MemoryOption.MB_512, invoker="public"
)
def remove_from_ronda(req: https_fn.CallableRequest) -> dict:
    """[Sacar de Ronda] on a report, `{reportId}`: the person it is about leaves every ronda,
    is kept out until let back in, and gets one neutral notice. Admin only (removals.py)."""
    import jobs
    import removals

    def run(db) -> dict:
        context = jobs.context()
        return removals.remove(db, req.data, _now(), send=context.send, app_url=context.app_url)

    return _safety_call(req, run)


@https_fn.on_call(
    region=REGION, max_instances=1, memory=options.MemoryOption.MB_512, invoker="public"
)
def let_back_in(req: https_fn.CallableRequest) -> dict:
    """[Dejar entrar de nuevo], `{uid}`. Admin only (removals.py)."""
    import removals

    return _safety_call(req, lambda db: removals.let_back_in(db, req.data))
