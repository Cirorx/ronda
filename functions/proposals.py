"""Proposals: the solver's groups waiting for the admin, and what approving one writes.

`propose(db, admin_uid, now)` reads the sign-ups, runs the solver and writes `proposals/{id}`.
On the real project the invented `demo-` sign-ups never reach the solver (demo_users.py), so no
proposal groups them next to real members.
`approve(db, proposal_id, admin_uid, now)` turns a pending proposal into `rondas/{id}`,
`rondas/{id}/members/{uid}` and `users/{uid}/rondas/{id}`; `undo_approval` deletes them again
and puts it back to pending.
Nothing here sends anything to a member: before approval only the admin can read a proposal
(firestore.rules), and the Tuesday push is the organiser's job.

The document builders are pure (`solver_input`, `proposal_document`, `ronda_documents`), so the
tests cover them without Firestore; the three entry points only read and write around them.
"""

from datetime import datetime

import demo_users
from ronda_solver import solve
from ronda_solver.demo import DEMO_BARRIOS

BARRIOS = {barrio: {"lat": lat, "lng": lng} for barrio, (lat, lng) in DEMO_BARRIOS.items()}
"""The barrio centroids distance is measured between: the app's `Barrio` ids, with the solver's
approximate centroids (no other table exists yet)."""

PENDING = "pending"
APPROVED = "approved"

OPEN_SEAT_FROM_WEEK = 4
"""docs/ARCHITECTURE.md § Data model: a new ronda opens a seat to the bench from week 4."""


class ProposalError(Exception):
    """A proposal that can't take the requested step; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def solver_input(users: dict[str, dict], eligible: dict[str, list[str]], avoid: list[dict]) -> dict:
    """The solver's input (solver/README.md) from `users/{uid}`, their eligible seat ids and the
    `avoid/{pairId}` documents.

    Only people with a saved profile in a known barrio and eligible ids take part: someone who
    has only accepted the terms, or whose phone sent no ids yet, is left out. No name, no need.
    """
    people = []
    for uid, user in sorted(users.items()):
        if "firstName" not in user or user.get("barrio") not in BARRIOS or uid not in eligible:
            continue
        person = {
            "uid": uid,
            "ageBand": user["ageBand"],
            "barrio": user["barrio"],
            "pretexts": list(user.get("pretexts", [])),
            "slots": list(user.get("slots", [])),
            "eligibleSeatIds": list(eligible[uid]),
        }
        if plus_one := user.get("plusOneUid"):
            person["plusOneUid"] = plus_one
        people.append(person)
    return {
        "barrios": BARRIOS,
        "people": people,
        "avoidPairs": [[pair["uidA"], pair["uidB"]] for pair in avoid],
    }


def proposal_document(result: dict, users: dict[str, dict], admin_uid: str, now: datetime) -> dict:
    """`proposals/{id}` for a solver result: each group with its members' first names, age bands
    and walk, the rejected alternative's reason, and who is still without a seat.

    `plusOneInGroup` is true or false only for a member whose +1 also signed up, so the screen can
    say "Ana y su invitado van juntos" without knowing the other groups.
    """
    seated_uids = {m["uid"] for group in result["proposals"] for m in group["members"]}
    groups = []
    for group in result["proposals"]:
        uids = {m["uid"] for m in group["members"]}
        members = []
        for member in group["members"]:
            user = users[member["uid"]]
            entry = {
                "uid": member["uid"],
                "firstName": user["firstName"],
                "ageBand": member["ageBand"],
                "distanceBlocks": member["distanceBlocks"],
            }
            plus_one = user.get("plusOneUid")
            if plus_one in seated_uids or plus_one in result["unseated"]:
                entry["plusOneInGroup"] = plus_one in uids
            members.append(entry)
        groups.append(
            {
                "id": group["id"],
                "barrio": group["barrio"],
                "pretext": group["pretext"],
                "slot": group["slot"],
                "members": members,
                "checks": group["checks"],
            }
        )
    alternative = result["rejectedAlternative"]
    return {
        "status": PENDING,
        "solverStatus": result["status"],
        "groups": groups,
        "unseated": result["unseated"],
        "rejectedAlternative": None
        if alternative is None
        else {
            "brokenRule": alternative["brokenRule"],
            "reason": alternative["reason"],
            "reasons": alternative["reasons"],
        },
        "createdAt": now,
        "createdBy": admin_uid,
    }


def ronda_documents(
    proposal: dict, ronda_ids: list[str], users: dict[str, dict], now: datetime
) -> dict[str, dict]:
    """`rondas/{id}` and `rondas/{id}/members/{uid}` for each group of an approved proposal,
    and `users/{uid}/rondas/{id}`, how a member's phone finds their ronda, keyed by document
    path; `ronda_ids[i]` names group i.

    A ronda starts `forming`, with no place yet (its host sets a public one) and no season: the
    first ¿seguimos? starts that.
    """
    documents: dict[str, dict] = {}
    for ronda_id, group in zip(ronda_ids, proposal["groups"], strict=True):
        day, _, time = group["slot"].partition("-")
        documents[f"rondas/{ronda_id}"] = {
            "seatId": group["id"],
            "pretext": group["pretext"],
            "barrio": group["barrio"],
            "slot": {"day": day, "time": time},
            "size": len(group["members"]),
            "status": "forming",
            "openSeatFromWeek": OPEN_SEAT_FROM_WEEK,
            "createdAt": now,
        }
        for member in group["members"]:
            documents[f"rondas/{ronda_id}/members/{member['uid']}"] = {
                "brings": list(users.get(member["uid"], {}).get("brings", [])),
                "state": "active",
                "joinedAt": now,
            }
            documents[f"users/{member['uid']}/rondas/{ronda_id}"] = {"joinedAt": now}
    return documents


def _read_sign_ups(db) -> tuple[dict[str, dict], dict[str, list[str]], list[dict]]:
    """The users who count here (demo_users.counts), their eligible seat ids and the avoid
    pairs between two of them."""
    users = {
        snapshot.id: snapshot.to_dict()
        for snapshot in db.collection("users").stream()
        if demo_users.counts(snapshot.id)
    }
    eligible = {}
    for uid in users:
        snapshot = db.document(f"users/{uid}/private/eligible").get()
        if snapshot.exists:
            eligible[uid] = snapshot.to_dict().get("seatIds", [])
    pairs = [snapshot.to_dict() for snapshot in db.collection("avoid").stream()]
    avoid = [p for p in pairs if demo_users.counts(p["uidA"]) and demo_users.counts(p["uidB"])]
    return users, eligible, avoid


def propose(db, admin_uid: str, now: datetime) -> dict:
    """Solves the current sign-ups and writes a pending `proposals/{id}`. Returns its id and
    how many groups and unseated people it holds."""
    users, eligible, avoid = _read_sign_ups(db)
    result = solve(solver_input(users, eligible, avoid))
    reference = db.collection("proposals").document()
    reference.set(proposal_document(result, users, admin_uid, now))
    return {
        "proposalId": reference.id,
        "groups": len(result["proposals"]),
        "unseated": len(result["unseated"]),
    }


def approve(db, proposal_id: str, admin_uid: str, now: datetime) -> dict:
    """Writes the rondas of a pending proposal and marks it approved, in one batch."""
    reference = db.document(f"proposals/{proposal_id}")
    proposal = _proposal(reference, expected=PENDING)
    if not proposal["groups"]:
        raise ProposalError("failed-precondition", "the proposal has no groups")
    ronda_ids = [db.collection("rondas").document().id for _ in proposal["groups"]]
    uids = [m["uid"] for group in proposal["groups"] for m in group["members"]]
    users = {}
    for uid in uids:
        snapshot = db.document(f"users/{uid}").get()
        users[uid] = snapshot.to_dict() if snapshot.exists else {}
    batch = db.batch()
    for path, fields in ronda_documents(proposal, ronda_ids, users, now).items():
        batch.set(db.document(path), fields)
    batch.update(
        reference,
        {"status": APPROVED, "rondaIds": ronda_ids, "approvedAt": now, "approvedBy": admin_uid},
    )
    batch.commit()
    return {"proposalId": proposal_id, "rondaIds": ronda_ids}


def undo_approval(db, proposal_id: str) -> dict:
    """Deletes the rondas an approval wrote, and each member's link to theirs, and puts the
    proposal back to pending."""
    from google.cloud.firestore import DELETE_FIELD

    reference = db.document(f"proposals/{proposal_id}")
    proposal = _proposal(reference, expected=APPROVED)
    batch = db.batch()
    for ronda_id in proposal.get("rondaIds", []):
        ronda = db.document(f"rondas/{ronda_id}")
        for member in ronda.collection("members").list_documents():
            batch.delete(db.document(f"users/{member.id}/rondas/{ronda_id}"))
            batch.delete(member)
        batch.delete(ronda)
    batch.update(
        reference,
        {
            "status": PENDING,
            "rondaIds": DELETE_FIELD,
            "approvedAt": DELETE_FIELD,
            "approvedBy": DELETE_FIELD,
        },
    )
    batch.commit()
    return {"proposalId": proposal_id}


def _proposal(reference, expected: str) -> dict:
    snapshot = reference.get()
    if not snapshot.exists:
        raise ProposalError("not-found", "no such proposal")
    proposal = snapshot.to_dict()
    if proposal["status"] != expected:
        raise ProposalError("failed-precondition", f"the proposal is not {expected}")
    return proposal
