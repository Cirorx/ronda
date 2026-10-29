"""Ronda's Cloud Functions (Python 3.13, 2nd gen).

Every function runs in southamerica-east1 next to Firestore and Storage, and
sets ``max_instances`` so a loop or a flood can't run up the bill.
"""

import firebase_admin
from firebase_functions import https_fn, options

REGION = "southamerica-east1"

options.set_global_options(region=REGION, max_instances=2)

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
