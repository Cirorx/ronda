"""Proposals: the solver's groups waiting for the admin, and what approving one writes.

`propose(db, admin_uid, now)` reads the sign-ups, runs the solver and writes `proposals/{id}`.
On the real project the invented `demo-` sign-ups never reach the solver (demo_users.py), so no
proposal groups them next to real members.
`approve(db, proposal_id, admin_uid, now)` turns a pending proposal into `rondas/{id}`,
`rondas/{id}/members/{uid}` and `users/{uid}/rondas/{id}`, and sets each ronda's place, hour and
hosts from its group's `setup` when it has one (auto_setup.py), through `hosts.set_setup`;
`undo_approval` deletes them again and puts it back to pending (an auto proposal comes back
stopped, so it doesn't approve itself again). `stop` is the admin's [Frenar] on an auto
proposal: it waits for a manual Aprobar.
A new proposal supersedes every older pending one that names any of its people (`supersede`):
it is marked `superseded`, never deleted, so the queue holds one live proposal.
Nothing here sends anything to a member: before approval only the admin can read a proposal
(firestore.rules); an approved auto proposal is announced by the `auto_form` job, and the
Tuesday push is the organiser's job.

The document builders are pure (`solver_input`, `proposal_document`, `ronda_documents`), so the
tests cover them without Firestore; the three entry points only read and write around them.
"""

import logging
from datetime import datetime

import demo_users
import member_barrios
import rsvp
import safety
from ronda_solver import solve
from ronda_solver.barrios import CENTROIDS

log = logging.getLogger(__name__)

BARRIOS = {barrio: {"lat": lat, "lng": lng} for barrio, (lat, lng) in CENTROIDS.items()}
"""The barrio centroids distance is measured between: the app's `Barrio` ids, Ciudad de la
Costa's and Montevideo's (`ronda_solver.barrios`)."""

PENDING = "pending"
APPROVED = "approved"
SUPERSEDED = "superseded"
"""An older pending proposal a newer one replaced: kept, never approved."""

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
    has only accepted the terms, or whose phone sent no ids yet, is left out. Casa goes in as
    `barrio`, trabajo as `workBarrio` when it is a known barrio, each with whether it reaches
    its neighbours (member_barrios.py). No name, no need.
    """
    people = []
    for uid, user in sorted(users.items()):
        anchors = member_barrios.anchors(user)
        if "firstName" not in user or not anchors or uid not in eligible:
            continue
        person = {
            "uid": uid,
            "ageBand": user["ageBand"],
            "barrio": user["barrio"],
            "pretexts": list(user.get("pretexts", [])),
            "slots": list(user.get("slots", [])),
            "eligibleSeatIds": list(eligible[uid]),
        }
        if anchors[0].neighbours:
            person["barrioNeighbours"] = True
        for work in anchors[1:]:
            person["workBarrio"] = work.barrio
            person["workBarrioNeighbours"] = work.neighbours
        if plus_one := user.get("plusOneUid"):
            person["plusOneUid"] = plus_one
        people.append(person)
    return {
        "barrios": BARRIOS,
        "people": people,
        "avoidPairs": [[pair["uidA"], pair["uidB"]] for pair in avoid],
    }


def unseated_person(uid: str, user: dict) -> dict:
    """One entry of `unseatedPeople`: what the admin needs to place someone by hand, and no more:
    first name, barrio, the slots and pretexts they picked."""
    return {
        "uid": uid,
        "firstName": user.get("firstName", ""),
        "barrio": user.get("barrio", ""),
        "slots": list(user.get("slots", [])),
        "pretexts": list(user.get("pretexts", [])),
    }


def proposal_document(result: dict, users: dict[str, dict], admin_uid: str, now: datetime) -> dict:
    """`proposals/{id}` for a solver result: each group with its members' first names, age bands
    and walk, the rejected alternative's reason, and who is still without a seat: `unseated`
    (uids, which scripts/reset.py reads) and `unseatedPeople`, the same people by first name,
    barrio and slots, so /admin can name them.

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
        "unseatedPeople": [unseated_person(uid, users[uid]) for uid in result["unseated"]],
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


def _offered(db, uid: str) -> bool:
    """Whether `uid` holds a pending offer of a freed seat (bench.py)."""
    return any(
        (snapshot.to_dict() or {}).get("status") == "pending"
        for snapshot in db.collection(f"users/{uid}/offers").stream()
    )


def _read_sign_ups(db) -> tuple[dict[str, dict], dict[str, list[str]], list[dict]]:
    """The users who count here (demo_users.counts), aren't out of Ronda (safety.removed), have
    no seat in a ronda that still meets and no pending offer of one (they'd be placed twice),
    their eligible seat ids and the avoid pairs between two of them."""
    out = safety.removed(db)
    seated = rsvp.seated_uids(db)
    users = {
        snapshot.id: snapshot.to_dict()
        for snapshot in db.collection("users").stream()
        if demo_users.counts(snapshot.id)
        and snapshot.id not in out
        and snapshot.id not in seated
        and not _offered(db, snapshot.id)
    }
    eligible = {}
    for uid in users:
        snapshot = db.document(f"users/{uid}/private/eligible").get()
        if snapshot.exists:
            eligible[uid] = snapshot.to_dict().get("seatIds", [])
    avoid = [p for p in safety.avoid_pairs(db) if p["uidA"] in users and p["uidB"] in users]
    return users, eligible, avoid


def solve_sign_ups(db) -> tuple[dict, dict[str, dict]]:
    """The solver's result on the current sign-ups (`_read_sign_ups`), and those users."""
    users, eligible, avoid = _read_sign_ups(db)
    return solve(solver_input(users, eligible, avoid)), users


def people(proposal: dict) -> set[str]:
    """Everyone a proposal names: its groups' members and who it leaves without a seat."""
    grouped = {m["uid"] for group in proposal.get("groups", []) for m in group["members"]}
    return grouped | set(proposal.get("unseated", []))


def supersede(db, proposal_id: str, proposal: dict, now: datetime) -> int:
    """Marks `superseded` every other pending proposal that names any of `proposal`'s people.
    Returns how many."""
    named = people(proposal)
    count = 0
    for snapshot in db.collection("proposals").stream():
        older = snapshot.to_dict() or {}
        if snapshot.id == proposal_id or older.get("status") != PENDING:
            continue
        if people(older) & named:
            db.document(f"proposals/{snapshot.id}").update(
                {"status": SUPERSEDED, "supersededBy": proposal_id, "supersededAt": now}
            )
            count += 1
    return count


def propose(db, admin_uid: str, now: datetime) -> dict:
    """Solves the current sign-ups and writes a pending `proposals/{id}`, superseding the older
    pending ones it covers. Returns its id and how many groups and unseated people it holds."""
    result, users = solve_sign_ups(db)
    reference = db.collection("proposals").document()
    document = proposal_document(result, users, admin_uid, now)
    reference.set(document)
    supersede(db, reference.id, document, now)
    return {
        "proposalId": reference.id,
        "groups": len(result["proposals"]),
        "unseated": len(result["unseated"]),
    }


def stop(db, proposal_id: str, admin_uid: str, now: datetime) -> dict:
    """[Frenar]: a pending auto proposal no longer approves itself; it waits for Aprobar."""
    reference = db.document(f"proposals/{proposal_id}")
    proposal = _proposal(reference, expected=PENDING)
    if proposal.get("auto") is not True:
        raise ProposalError("failed-precondition", "the proposal does not approve itself")
    reference.update({"stoppedAt": now, "stoppedBy": admin_uid})
    return {"proposalId": proposal_id}


def approve(db, proposal_id: str, admin_uid: str, now: datetime) -> dict:
    """Writes the rondas of a pending proposal and marks it approved, in one batch; then sets
    each ronda's place, hour and hosts from its group's setup, when it has one (`_set_up`)."""
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
    approval = {
        "status": APPROVED,
        "rondaIds": ronda_ids,
        "approvedAt": now,
        "approvedBy": admin_uid,
    }
    if proposal.get("auto") is True:
        # Its members hear about it from the auto_form job, inside the hours.
        approval["notice"] = NOTICE_PENDING
    batch.update(reference, approval)
    batch.commit()
    for ronda_id, group in zip(ronda_ids, proposal["groups"], strict=True):
        if group.get("setup"):
            _set_up(db, ronda_id, group["setup"], now)
    return {"proposalId": proposal_id, "rondaIds": ronda_ids}


NOTICE_PENDING = "pending"
"""`proposals/{id}.notice` of an approved auto proposal whose members aren't told yet."""


def _set_up(db, ronda_id: str, setup: dict, now: datetime) -> None:
    """Writes a group's setup on its new ronda through `hosts.set_setup`, the admin's own path,
    and points the setup's trace at the ronda. A setup the checks refuse leaves the ronda "a
    confirmar"; the approval stands."""
    import hosts

    try:
        hosts.set_setup(
            db,
            {
                "rondaId": ronda_id,
                "place": setup["place"],
                "hour": setup["hour"],
                "anfitrion": setup["anfitrion"],
                "cola": setup["cola"],
            },
            now,
        )
    except (hosts.SetupError, KeyError) as error:
        log.error("setup of %s refused: %s", ronda_id, type(error).__name__)
        return
    if run_id := setup.get("runId"):
        db.document(f"agent_runs/{run_id}").set({"rondaId": ronda_id}, merge=True)


def undo_approval(db, proposal_id: str, admin_uid: str, now: datetime) -> dict:
    """Deletes the rondas an approval wrote, and each member's link to theirs, and puts the
    proposal back to pending; an auto one comes back stopped."""
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
    back = {
        "status": PENDING,
        "rondaIds": DELETE_FIELD,
        "approvedAt": DELETE_FIELD,
        "approvedBy": DELETE_FIELD,
    }
    if proposal.get("auto") is True:
        back |= {"notice": DELETE_FIELD, "stoppedAt": now, "stoppedBy": admin_uid}
    batch.update(reference, back)
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
