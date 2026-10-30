"""The admin's "Sumar a esta ronda": a signed-up member added to a ronda by hand.

For whoever the solver left out, or signed up after Aprobar (docs/ARCHITECTURE.md § Data model).

- `candidates(db, ronda_id)`: who the admin could add, each with what doesn't match the ronda
  (`warnings`), and who is in it now.
- `add(db, ronda_id, uid, now, move=...)`: writes `rondas/{id}/members/{uid}` and
  `users/{uid}/rondas/{id}` in one transaction, with the ronda's `size`, its "who's coming"
  view (the new member counts as sin contestar: they are in no `rsvp` map) and the approved
  proposal that made the ronda, so /admin shows them in its group and no longer left out.

The rules, checked in `add`:
- Never an invented `demo-` sign-up where they don't count (demo_users.counts, #53).
- Only someone with a profile in a barrio the solver knows, into a ronda that still meets.
- The size cap: active and paused members stay below the pretext's `SizeRule.cap`.
- One ronda each: someone in another ronda that still meets moves only with `move=True`, which
  leaves the old one (`state: left`, `leftAt`) and deletes its `users/{uid}/rondas` link, since
  the phone follows the lowest ronda id it finds there. A link to a ronda they already left, or
  that no longer meets, is deleted too.
- Warnings never block: a slot or pretext they didn't pick, a barrio more than the solver's ten
  blocks away, a seat their phone didn't mark as possible (which need, the server never knows).

Nothing here sends anything: if the week's ¿Venís? already went out, the new member answers
from the card; an open ¿seguimos? didn't ask them.
"""

from datetime import datetime

import demo_users
import rsvp
from proposals import APPROVED, BARRIOS, unseated_person

SEATED = ("active", "paused")
"""Member states that take a seat; `left` doesn't."""

SLOT, PRETEXT, BARRIO, SEAT = "slot", "pretext", "barrio", "seat"
"""What `warnings` can name."""


class MemberError(Exception):
    """A step the callable refuses; `code` is the callable's error code."""

    def __init__(self, code: str, message: str) -> None:
        super().__init__(message)
        self.code = code


def slot_id(ronda: dict) -> str:
    """ "sat-afternoon": the ronda's slot as the profile stores it."""
    slot = ronda.get("slot", {})
    return f"{slot.get('day', '')}-{slot.get('time', '')}"


def seat_id(ronda: dict) -> str:
    """The ronda's seat id, `{barrio}_{pretext}_{slot}`."""
    return ronda.get("seatId") or f"{ronda.get('barrio')}_{ronda.get('pretext')}_{slot_id(ronda)}"


def blocks(from_barrio: str, to_barrio: str) -> int | None:
    """Whole blocks between two barrio centroids, as the solver measures a walk; `None` when
    either barrio is unknown."""
    from ronda_solver.geo import blocks_between

    here, there = BARRIOS.get(from_barrio), BARRIOS.get(to_barrio)
    if here is None or there is None:
        return None
    return round(blocks_between((here["lat"], here["lng"]), (there["lat"], there["lng"])))


def warnings(ronda: dict, user: dict, eligible: list[str] | None) -> list[str]:
    """What about `user` doesn't match `ronda`, in the order the screen shows it."""
    from ronda_solver.rules import MAX_WALK_BLOCKS

    found = []
    if slot_id(ronda) not in user.get("slots", []):
        found.append(SLOT)
    if ronda.get("pretext") not in user.get("pretexts", []):
        found.append(PRETEXT)
    walk = blocks(user.get("barrio", ""), ronda.get("barrio", ""))
    if walk is None or walk > MAX_WALK_BLOCKS:
        found.append(BARRIO)
    if seat_id(ronda) not in (eligible or []):
        found.append(SEAT)
    return found


def cap(ronda: dict) -> int:
    """The most members the ronda's pretext allows."""
    from ronda_solver.rules import size_rule

    return size_rule(ronda.get("pretext")).cap


def seated(members: dict[str, dict]) -> list[str]:
    """The members who take a seat, by uid."""
    return sorted(uid for uid, m in members.items() if m.get("state", "active") in SEATED)


def regroup(
    proposal: dict, ronda_id: str, uid: str, entry: dict, plus_ones: dict[str, str]
) -> dict:
    """The fields of approved `proposal` to rewrite once `uid` sits in ronda `ronda_id`: out of
    every other group and of `unseated` / `unseatedPeople`, into the ronda's group when the
    proposal made it (`entry` is their member entry), and every `plusOneInGroup` again, as
    `proposal_document` sets it (`plus_ones` maps each member's uid to their +1's)."""
    groups = [
        {**group, "members": [dict(m) for m in group["members"] if m["uid"] != uid]}
        for group in proposal.get("groups", [])
    ]
    for group_ronda, group in zip(proposal.get("rondaIds", []), groups, strict=False):
        if group_ronda == ronda_id:
            group["members"].append(dict(entry))
    unseated = [u for u in proposal.get("unseated", []) if u != uid]
    everyone = {m["uid"] for g in groups for m in g["members"]} | set(unseated)
    for group in groups:
        uids = {m["uid"] for m in group["members"]}
        for member in group["members"]:
            member.pop("plusOneInGroup", None)
            plus_one = plus_ones.get(member["uid"])
            if plus_one in everyone:
                member["plusOneInGroup"] = plus_one in uids
    return {
        "groups": groups,
        "unseated": unseated,
        "unseatedPeople": [p for p in proposal.get("unseatedPeople", []) if p["uid"] != uid],
    }


# --- Reading --------------------------------------------------------------------------------


def _open_ronda(db, ronda_id: str) -> dict:
    snapshot = db.document(f"rondas/{ronda_id}").get()
    if not snapshot.exists:
        raise MemberError("not-found", "no such ronda")
    ronda = snapshot.to_dict() or {}
    if ronda.get("status") not in rsvp.OPEN_STATUSES:
        raise MemberError("failed-precondition", "the ronda no longer meets")
    return ronda


def _eligible(db, uid: str) -> list[str] | None:
    snapshot = db.document(f"users/{uid}/private/eligible").get()
    return (snapshot.to_dict() or {}).get("seatIds", []) if snapshot.exists else None


def _links(db, uid: str, ronda_id: str) -> tuple[dict[str, dict], list[str]]:
    """`uid`'s other rondas: those they sit in that still meet, by id, and the stale links (a
    ronda they left, that no longer meets or no longer exists)."""
    sitting: dict[str, dict] = {}
    stale: list[str] = []
    for link in db.collection(f"users/{uid}/rondas").stream():
        if link.id == ronda_id:
            continue
        ronda = db.document(f"rondas/{link.id}").get()
        member = db.document(f"rondas/{link.id}/members/{uid}").get()
        if (
            ronda.exists
            and (ronda.to_dict() or {}).get("status") in rsvp.OPEN_STATUSES
            and member.exists
            and (member.to_dict() or {}).get("state", "active") in SEATED
        ):
            sitting[link.id] = ronda.to_dict() or {}
        else:
            stale.append(link.id)
    return sitting, stale


def candidates(db, ronda_id: str) -> dict:
    """Who the admin could add to ronda `ronda_id`: every sign-up who counts here, with a
    profile in a known barrio, not sitting in it; those in no ronda first, then by first name.
    Each with first name, age band, barrio, slots, pretexts, the walk in blocks, `warnings`,
    and the ronda they sit in now (`rondaId`, `rondaLine`) if any. With the ronda's line, its
    members' first names, how many seats are taken and its cap."""
    ronda = _open_ronda(db, ronda_id)
    members = rsvp._members(db, ronda_id)
    inside = seated(members)
    names = rsvp._first_names(db, inside)
    people = []
    for snapshot in db.collection("users").stream():
        uid, user = snapshot.id, snapshot.to_dict() or {}
        if (
            not demo_users.counts(uid)
            or "firstName" not in user
            or user.get("barrio") not in BARRIOS
            or uid in inside
        ):
            continue
        sitting, _ = _links(db, uid, ronda_id)
        other = min(sitting, default=None)
        people.append(
            {
                **unseated_person(uid, user),
                "ageBand": user.get("ageBand", ""),
                "blocks": blocks(user["barrio"], ronda.get("barrio", "")),
                "warnings": warnings(ronda, user, _eligible(db, uid)),
                "rondaId": other,
                "rondaLine": rsvp.ronda_line(sitting[other]) if other else None,
            }
        )
    people.sort(key=lambda p: (p["rondaId"] is not None, p["firstName"], p["uid"]))
    return {
        "rondaId": ronda_id,
        "line": rsvp.ronda_line(ronda),
        "members": sorted(name for name in names.values() if name),
        "taken": len(inside),
        "cap": cap(ronda),
        "people": people,
    }


# --- Writing --------------------------------------------------------------------------------


def add(db, ronda_id: str, uid: str, now: datetime, *, move: bool = False) -> dict:
    """Adds sign-up `uid` to ronda `ronda_id` as an active member (see the module's rules).
    Returns the ronda, the uid, the warnings and, after a move, the ronda they left."""
    if not demo_users.counts(uid):
        raise MemberError("failed-precondition", "an invented sign-up never joins a ronda here")
    ronda = _open_ronda(db, ronda_id)
    user_snapshot = db.document(f"users/{uid}").get()
    user = (user_snapshot.to_dict() or {}) if user_snapshot.exists else {}
    if "firstName" not in user or user.get("barrio") not in BARRIOS:
        raise MemberError("not-found", "no sign-up with a profile in a known barrio")
    members = rsvp._members(db, ronda_id)
    inside = seated(members)
    if uid in inside:
        raise MemberError("already-exists", "already in this ronda")
    if len(inside) >= cap(ronda):
        raise MemberError("resource-exhausted", "the ronda is full")
    sitting, stale = _links(db, uid, ronda_id)
    if sitting and not move:
        raise MemberError("failed-precondition", "in another ronda: move them explicitly")

    today = rsvp.local(now).date()
    entry = {"brings": list(user.get("brings", [])), "state": "active", "joinedAt": now}
    members[uid] = entry
    # Each ronda whose members change, with what its view needs: members, first names, meeting.
    changed = {ronda_id: (ronda, members)}
    for old_id, old in sitting.items():
        old_members = rsvp._members(db, old_id)
        old_members[uid] = {**old_members[uid], "state": "left"}
        changed[old_id] = (old, old_members)
    views = {}
    for changed_id, (changed_ronda, changed_members) in changed.items():
        meeting = rsvp.next_meeting(changed_ronda["slot"]["day"], today)
        views[changed_id] = (
            meeting,
            db.document(f"rondas/{changed_id}/weeks/{rsvp.iso_week(meeting)}"),
            rsvp._first_names(db, rsvp.counted(changed_members)),
        )
    proposal_refs = [
        db.document(f"proposals/{snapshot.id}")
        for snapshot in db.collection("proposals").stream()
        if (snapshot.to_dict() or {}).get("status") == APPROVED
        and set((snapshot.to_dict() or {}).get("rondaIds", [])) & set(changed)
    ]
    plus_ones = _plus_ones(db, proposal_refs, uid, user)
    group_entry = {
        "uid": uid,
        "firstName": user["firstName"],
        "ageBand": user.get("ageBand", ""),
        "distanceBlocks": blocks(user["barrio"], ronda.get("barrio", "")),
    }

    def write(transaction) -> None:
        # Every read comes before the first write, as Firestore transactions require.
        weeks = {
            changed_id: week_ref.get(transaction=transaction)
            for changed_id, (_, week_ref, _) in views.items()
        }
        proposals = [
            (ref, ref.get(transaction=transaction).to_dict() or {}) for ref in proposal_refs
        ]
        transaction.set(db.document(f"rondas/{ronda_id}/members/{uid}"), entry)
        transaction.set(db.document(f"users/{uid}/rondas/{ronda_id}"), {"joinedAt": now})
        for old_id in sitting:
            transaction.update(
                db.document(f"rondas/{old_id}/members/{uid}"), {"state": "left", "leftAt": now}
            )
        for old_id in [*sitting, *stale]:
            transaction.delete(db.document(f"users/{uid}/rondas/{old_id}"))
        for changed_id, (_, changed_members) in changed.items():
            meeting, _, names = views[changed_id]
            transaction.update(
                db.document(f"rondas/{changed_id}"), {"size": len(seated(changed_members))}
            )
            transaction.set(
                db.document(f"rondas/{changed_id}/views/{rsvp.VIEW}"),
                rsvp.week_view(
                    meeting,
                    changed_members,
                    names,
                    rsvp._rsvp(weeks[changed_id]),
                    now,
                    rsvp.guests(weeks[changed_id]),
                ),
            )
        for ref, proposal in proposals:
            transaction.update(ref, regroup(proposal, ronda_id, uid, group_entry, plus_ones))

    rsvp._in_transaction(db, write)
    return {
        "rondaId": ronda_id,
        "uid": uid,
        "warnings": warnings(ronda, user, _eligible(db, uid)),
        "movedFrom": min(sitting, default=None),
    }


def _plus_ones(db, proposal_refs: list, uid: str, user: dict) -> dict[str, str]:
    """Each member of the proposals' groups (and `uid`) by uid, with their +1's uid if any."""
    uids = {
        member["uid"]
        for ref in proposal_refs
        for group in (ref.get().to_dict() or {}).get("groups", [])
        for member in group["members"]
    } - {uid}
    plus_ones = {u: p for u in sorted(uids) if (p := _plus_one(db, u))}
    if plus_one := user.get("plusOneUid"):
        plus_ones[uid] = plus_one
    return plus_ones


def _plus_one(db, uid: str) -> str:
    snapshot = db.document(f"users/{uid}").get()
    return (snapshot.to_dict() or {}).get("plusOneUid", "") if snapshot.exists else ""
