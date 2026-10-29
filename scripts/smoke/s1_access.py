# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["httpx>=0.28"]
# ///
"""Smoke test 1: a 200 from muse-spark-1.3 proves the Meta API answers from Uruguay.

uv run scripts/smoke/s1_access.py
"""

import httpx
from _env import META_BASE, Timer, key

with Timer() as t:
    r = httpx.post(
        f"{META_BASE}/responses",
        headers={"Authorization": f"Bearer {key('MODEL_API_KEY')}"},
        json={"model": "muse-spark-1.3", "input": "Decí hola en rioplatense, en una línea."},
        timeout=60,
    )
print(f"HTTP {r.status_code} in {t.s} s")
if r.status_code != 200:
    print({402: "no card", 403: "region block"}.get(r.status_code, ""), r.text[:300])
    raise SystemExit(1)
body = r.json()
text = [c.get("text") for o in body.get("output", []) for c in o.get("content", []) or []]
print("text:", " ".join(filter(None, text))[:200])
print("usage:", body.get("usage"))
