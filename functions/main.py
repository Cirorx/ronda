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
