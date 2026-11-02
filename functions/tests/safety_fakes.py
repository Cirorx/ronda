"""A small invented world for reports.py, safety.py and removals.py: one Saturday mate ronda with
Ana, Beto and Cora (and Dani, who left), a Tuesday truco ronda with Ana and Fede, and Gabi, who
sits in no ronda. Every uid and name is invented."""

from datetime import UTC, datetime

NOW = datetime(2026, 11, 2, 15, 0, tzinfo=UTC)  # Monday 12:00 in Montevideo
NIGHT = datetime(2026, 11, 3, 1, 0, tzinfo=UTC)  # Monday 22:00 in Montevideo
EARLIER = datetime(2026, 10, 20, 15, 0, tzinfo=UTC)


def _member(state="active"):
    return {"brings": ["pan"], "state": state, "joinedAt": EARLIER}


def world() -> dict[str, dict]:
    documents = {
        "rondas/r1": {
            "pretext": "mate",
            "barrio": "el-pinar-sur",
            "slot": {"day": "sat", "time": "afternoon"},
            "size": 3,
            "status": "active",
        },
        "rondas/r2": {
            "pretext": "truco",
            "barrio": "el-pinar-norte",
            "slot": {"day": "tue", "time": "evening"},
            "size": 2,
            "status": "forming",
        },
        "rondas/r1/members/dani": _member("left"),
        "rondas/r1/weeks/2026-W45": {"date": "2026-11-07", "rsvp": {"ana": "yes", "beto": "yes"}},
        "users/dani/rondas/r1": {"joinedAt": EARLIER},
        "users/gabi": {"firstName": "Gabi"},
        "users/hugo": {"terms": {}},
    }
    for uid, name in (("ana", "Ana"), ("beto", "Beto"), ("cora", "Cora"), ("dani", "Dani")):
        documents[f"users/{uid}"] = {"firstName": name}
    for uid in ("ana", "beto", "cora"):
        documents[f"rondas/r1/members/{uid}"] = _member()
        documents[f"users/{uid}/rondas/r1"] = {"joinedAt": EARLIER}
    documents["users/fede"] = {"firstName": "Fede"}
    for uid in ("ana", "fede"):
        documents[f"rondas/r2/members/{uid}"] = _member()
        documents[f"users/{uid}/rondas/r2"] = {"joinedAt": EARLIER}
    documents["users/beto/tokens/tok-beto"] = {"platform": "android"}
    return documents
