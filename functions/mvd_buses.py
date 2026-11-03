"""Montevideo's city buses, live, from the Intendencia's public-transport API (#65).

The API (https://api.montevideo.gub.uy/apidocs/publictransport) is the data behind the city's
Cómo Ir app: free with an account, at a "reasonable" rate, no reuse licence stated and no
attribution asked; the README names it anyway. Every call needs an OAuth2 token (client
credentials from `MVD_API_CLIENT_ID` and `MVD_API_SECRET_ID`, Cloud Functions secrets that never
reach the phone). Smoke test 11 (`scripts/smoke/s11_mvd_bus.py`) measured it on 2026-11-02: a
token lives 300 s, each call answers in 0.1 to 0.7 s, and no rate-limit header comes back.

`MvdBuses.next_buses(lat, lng)` gives the next arrivals at the stop nearest a meeting place, on
the lines that call there: the stop list (about 5,000 stops, read once per run), the stop's
lines, then `upcomingbuses`. The whole of it must fit in `BUDGET` seconds, or it raises
`BusesUnavailable` and the caller goes on without buses: a reminder is never late for a bus.

`upcomingbuses` gives each bus's ETA in seconds and its distance to the stop in metres. Some
answers can't be true (2 s from 20 km away in the smoke test), so an arrival whose implied
speed passes `MAX_SPEED` is dropped, as is one further than `HORIZON` away.
"""

import math
import os
import time
from collections.abc import Callable
from dataclasses import dataclass
from typing import Protocol

import httpx

TOKEN_URL = "https://mvdapi-auth.montevideo.gub.uy/token"
API = "https://api.montevideo.gub.uy/api/transportepublico"
SOURCE = "Intendencia de Montevideo"

BUDGET = 4.0
"""Seconds for the whole answer: token, stops, lines and arrivals."""
TOKEN_MARGIN = 30
"""A token is renewed this many seconds before it expires."""
MAX_STOP_METRES = 400
"""The stop must be this close to the meeting place, about four blocks; outside Montevideo
(Ciudad de la Costa) there is none."""
HORIZON = 30 * 60
"""Arrivals further than this many seconds away are left out."""
MAX_SPEED = 50 / 3.6
"""Metres per second: an ETA that implies more is not believed."""
MAX_ARRIVALS = 3

_SMALL_WORDS = {"de", "del", "la", "las", "los", "el", "y"}


class BusesUnavailable(RuntimeError):
    """The API didn't answer in time, refused the credentials, or answered something else."""


@dataclass(frozen=True)
class BusStop:
    id: int
    name: str
    """ "26 de Marzo y Jose Ellauri": its two streets, as the city writes them, in title case."""
    lat: float
    lng: float


@dataclass(frozen=True)
class Arrival:
    line: str
    destination: str
    minutes: int


@dataclass(frozen=True)
class NextBuses:
    """The stop nearest the place, how far it is, and its next arrivals, soonest first."""

    stop: BusStop
    metres: int
    arrivals: list[Arrival]


class CityBuses(Protocol):
    """What the organiser's `get_next_buses` reads."""

    def next_buses(self, lat: float, lng: float) -> NextBuses | None: ...


class MvdBuses:
    """`CityBuses` from the Intendencia's API, over `http`. Keeps the token while it lives and
    the stop list for its own life (one run)."""

    def __init__(
        self,
        http: httpx.Client,
        client_id: str,
        secret: str,
        *,
        clock: Callable[[], float] = time.monotonic,
    ) -> None:
        self._http = http
        self._client_id = client_id
        self._secret = secret
        self._clock = clock
        self._token: tuple[str, float] | None = None
        self._stops: list[BusStop] | None = None

    def next_buses(self, lat: float, lng: float) -> NextBuses | None:
        """The next arrivals at the stop nearest (lat, lng); None when no stop is within
        `MAX_STOP_METRES`. Raises `BusesUnavailable` past `BUDGET` or on any bad answer."""
        deadline = self._clock() + BUDGET
        stop, metres = min(
            (
                (stop, metres_between((lat, lng), (stop.lat, stop.lng)))
                for stop in self._all(deadline)
            ),
            key=lambda pair: pair[1],
            default=(None, math.inf),
        )
        if stop is None or metres > MAX_STOP_METRES:
            return None
        lines = sorted(
            {str(row["line"]) for row in self._get(f"/buses/busstops/{stop.id}/lines", deadline)}
        )
        if not lines:
            return NextBuses(stop, round(metres), [])
        rows = self._get(
            f"/buses/busstops/{stop.id}/upcomingbuses",
            deadline,
            params={"lines": ",".join(lines), "amountperline": 1},
        )
        return NextBuses(stop, round(metres), arrivals(rows))

    def _all(self, deadline: float) -> list[BusStop]:
        if self._stops is None:
            self._stops = [
                stop for row in self._get("/buses/busstops", deadline) if (stop := _stop(row))
            ]
        return self._stops

    def _get(self, path: str, deadline: float, params: dict | None = None) -> list[dict]:
        token = self._bearer(deadline)
        try:
            response = self._http.get(
                f"{API}{path}",
                params=params,
                headers={"Authorization": f"Bearer {token}"},
                timeout=self._left(deadline),
            )
            response.raise_for_status()
            body = response.json()
        except (httpx.HTTPError, ValueError) as error:
            raise BusesUnavailable(type(error).__name__) from error
        if not isinstance(body, list):
            raise BusesUnavailable("not a list")
        return [row for row in body if isinstance(row, dict)]

    def _bearer(self, deadline: float) -> str:
        if self._token and self._clock() < self._token[1]:
            return self._token[0]
        try:
            response = self._http.post(
                TOKEN_URL,
                data={
                    "grant_type": "client_credentials",
                    "client_id": self._client_id,
                    "client_secret": self._secret,
                },
                timeout=self._left(deadline),
            )
            response.raise_for_status()
            grant = response.json()
            token, lifetime = str(grant["access_token"]), float(grant.get("expires_in", 0))
        except (httpx.HTTPError, ValueError, KeyError, TypeError) as error:
            raise BusesUnavailable(f"token: {type(error).__name__}") from error
        self._token = (token, self._clock() + lifetime - TOKEN_MARGIN)
        return token

    def _left(self, deadline: float) -> float:
        left = deadline - self._clock()
        if left <= 0:
            raise BusesUnavailable("too slow")
        return left


def from_environment(http: httpx.Client) -> MvdBuses | None:
    """`MvdBuses` with the keys the function's secrets put in the environment, or None when
    either is missing (then the organiser has no live buses, and says so)."""
    client_id, secret = os.environ.get("MVD_API_CLIENT_ID"), os.environ.get("MVD_API_SECRET_ID")
    if not client_id or not secret:
        return None
    return MvdBuses(http, client_id, secret)


def arrivals(rows: list[dict]) -> list[Arrival]:
    """The believable arrivals within `HORIZON`, one per line, soonest first, at most
    `MAX_ARRIVALS`."""
    soonest: dict[str, tuple[int, str]] = {}
    for row in rows:
        eta, distance, line = row.get("eta"), row.get("distance"), row.get("line")
        if not isinstance(eta, int | float) or not line or not 0 < eta <= HORIZON:
            continue
        if isinstance(distance, int | float) and distance / eta > MAX_SPEED:
            continue
        line = str(line)
        if line not in soonest or eta < soonest[line][0]:
            soonest[line] = (int(eta), _title(str(row.get("destination") or "")))
    ranked = sorted(soonest.items(), key=lambda item: (item[1][0], item[0]))
    return [
        Arrival(line, destination, max(1, round(eta / 60)))
        for line, (eta, destination) in ranked[:MAX_ARRIVALS]
    ]


def _stop(row: dict) -> BusStop | None:
    try:
        lng, lat = row["location"]["coordinates"]
        streets = [_title(str(row.get(k) or "")) for k in ("street1", "street2")]
        return BusStop(int(row["busstopId"]), " y ".join(s for s in streets if s), lat, lng)
    except (KeyError, TypeError, ValueError):
        return None


def _title(words: str) -> str:
    """ "26 DE MARZO" → "26 de Marzo"."""
    return " ".join(
        word.lower() if word.lower() in _SMALL_WORDS and i else word.capitalize()
        for i, word in enumerate(words.split())
    )


def metres_between(a: tuple[float, float], b: tuple[float, float]) -> float:
    """Distance between two (lat, lng) points, flat-earth: exact enough inside a city, and
    without importing the solver (which loads OR-Tools)."""
    dy = (a[0] - b[0]) * 111_320
    dx = (a[1] - b[1]) * 111_320 * math.cos(math.radians((a[0] + b[0]) / 2))
    return math.hypot(dx, dy)
