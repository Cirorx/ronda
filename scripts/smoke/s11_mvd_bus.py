# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["httpx>=0.28"]
# ///
"""Smoke test 11: the Intendencia de Montevideo's public-transport API answers
(https://api.montevideo.gub.uy/apidocs/publictransport).

    uv run scripts/smoke/s11_mvd_bus.py

Gets a token (OAuth2 client credentials, `MVD_API_CLIENT_ID` and `MVD_API_SECRET_ID`), lists
the stops, takes the one nearest Plaza Gomensoro in Pocitos, asks which lines call there and
the next buses of those lines, then reads the city GTFS's version and size (no token). Prints
latencies, the token's lifetime and any rate-limit header; never a key or the token.
"""

import io
import math
import zipfile

import httpx
from _env import Timer, key

TOKEN_URL = "https://mvdapi-auth.montevideo.gub.uy/token"
API = "https://api.montevideo.gub.uy/api/transportepublico"
AGENT = {"User-Agent": "Ronda-hackathon/0.1 (github.com/Cirorx/ronda)"}
SPOT = (-34.9125, -56.1530)
"""Plaza Gomensoro, Pocitos (lat, lng)."""
BURST = 5


def metres(a: tuple[float, float], b: tuple[float, float]) -> float:
    dy = (a[0] - b[0]) * 111_320
    dx = (a[1] - b[1]) * 111_320 * math.cos(math.radians(a[0]))
    return math.hypot(dx, dy)


def limits(response: httpx.Response) -> dict[str, str]:
    return {
        name: value
        for name, value in response.headers.items()
        if "limit" in name.lower() or "retry" in name.lower() or "quota" in name.lower()
    }


with Timer() as t:
    grant = httpx.post(
        TOKEN_URL,
        data={
            "grant_type": "client_credentials",
            "client_id": key("MVD_API_CLIENT_ID"),
            "client_secret": key("MVD_API_SECRET_ID"),
        },
        headers=AGENT,
        timeout=20,
    )
grant.raise_for_status()
token = grant.json()
print(
    f"token {t.s} s: type {token.get('token_type')}, expires in {token.get('expires_in')} s, "
    f"scope {token.get('scope')!r}"
)
headers = {**AGENT, "Authorization": f"Bearer {token['access_token']}"}

with httpx.Client(base_url=API, headers=headers, timeout=20) as api:
    with Timer() as t:
        response = api.get("/buses/busstops")
    response.raise_for_status()
    stops = response.json()
    print(
        f"busstops {t.s} s, {len(response.content) / 1e6:.2f} MB: {len(stops)} stops; "
        f"limits {limits(response) or 'none sent'}"
    )
    print("first stop:", {k: v for k, v in stops[0].items() if k != "location"})

    def where(stop: dict) -> tuple[float, float]:
        lng, lat = stop["location"]["coordinates"]
        return lat, lng

    stop = min(stops, key=lambda s: metres(SPOT, where(s)))
    print(
        f"nearest Plaza Gomensoro: {stop['busstopId']} {stop.get('street1')} y "
        f"{stop.get('street2')}, {metres(SPOT, where(stop)):.0f} m"
    )

    with Timer() as t:
        response = api.get(f"/buses/busstops/{int(stop['busstopId'])}/lines")
    response.raise_for_status()
    lines = sorted({line["line"] for line in response.json()})
    print(f"lines {t.s} s: {lines}")

    timings = []
    for _ in range(BURST):
        with Timer() as t:
            response = api.get(
                f"/buses/busstops/{int(stop['busstopId'])}/upcomingbuses",
                params={"lines": ",".join(lines), "amountperline": 2},
            )
        timings.append(t.s)
        if response.status_code != 200:
            print("upcomingbuses", response.status_code, limits(response))
            break
    upcoming = response.json() if response.status_code == 200 else []
    print(
        f"upcomingbuses x{len(timings)} {timings} s: {len(upcoming)} buses; "
        f"limits {limits(response) or 'none sent'}"
    )
    for bus in sorted(upcoming, key=lambda b: b.get("eta", 0))[:6]:
        print(
            f"  {bus.get('line')} to {bus.get('destination')}: eta {bus.get('eta')} s, "
            f"{bus.get('distance')} m away"
        )

with Timer() as t:
    version = httpx.get(f"{API}/buses/gtfs/static/latest/version.txt", headers=AGENT, timeout=20)
print(f"gtfs version {t.s} s: {version.status_code} {version.text.strip()[:40]!r}")
with Timer() as t:
    archive = httpx.get(
        f"{API}/buses/gtfs/static/latest/google_transit.zip",
        headers=AGENT,
        timeout=120,
        follow_redirects=True,
    )
print(f"gtfs zip {t.s} s: {archive.status_code}, {len(archive.content) / 1e6:.1f} MB")
if archive.status_code == 200:
    feed = zipfile.ZipFile(io.BytesIO(archive.content))
    print("files:", {info.filename: info.file_size for info in feed.infolist()})
