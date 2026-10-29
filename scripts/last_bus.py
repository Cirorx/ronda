"""The last bus from one stop, read from the DNT metropolitan GTFS (docs/MODELS.md, test 7).

The feed publishes times only at each trip's timepoints, mostly its ends: in the 2026-09-21 feed
720 thousand of 795 thousand `stop_times` rows have none. A stop between two timepoints gets a
time interpolated along the straight-line distance between the trip's stops, as GTFS asks of
consumers, and is marked `estimated`, so the page can say which time is the published one.

`read_feed(zip, stop_ids)` keeps only the trips through the stops asked for (two passes over
`stop_times.txt`), `nearest_stops(stops, spot)` finds candidates, and `last_buses(feed, stop_id,
on)` gives the latest bus of each day type with service on that date. Services come from
`calendar.txt`; the feed has no `calendar_dates.txt`, so holidays are not known.
"""

import csv
import io
import sys
import zipfile
from collections import defaultdict
from dataclasses import dataclass
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
# ronda_solver is not an installable package (solver/pyproject.toml: package = false).
sys.path.append(str(ROOT / "solver"))
from ronda_solver.geo import metres_between  # noqa: E402

DNT_GTFS = (
    "https://catalogodatos.gub.uy/dataset/1d50ccf7-121d-48a7-951e-28a02858d24e/resource/"
    "9f44b654-751a-42a4-a481-af91b7c9a2e4/download/gtfs_20260921.zip"
)
"""The published feed, 2026-09-21, as smoke test 7 reads it."""

DAY_TYPES = {
    "weekday": ("monday", "tuesday", "wednesday", "thursday", "friday"),
    "saturday": ("saturday",),
    "sunday": ("sunday",),
}


@dataclass(frozen=True)
class Stop:
    id: str
    name: str
    lat: float
    lng: float


@dataclass(frozen=True)
class Service:
    days: frozenset[str]
    start: date
    end: date


@dataclass(frozen=True)
class Call:
    """One trip at one stop: its place in the trip and its published time, if any (seconds
    after the service day's midnight; GTFS writes 25:10:00 for 01:10 the next morning)."""

    sequence: int
    stop_id: str
    seconds: int | None


@dataclass(frozen=True)
class Feed:
    stops: dict[str, Stop]
    services: dict[str, Service]
    routes: dict[str, str]
    """route_id → route_short_name."""
    trips: dict[str, tuple[str, str]]
    """trip_id → (route_id, service_id)."""
    calls: dict[str, list[Call]]
    """trip_id → every call of the trips through the stops read, in sequence."""


def read_stops(archive: Path) -> dict[str, Stop]:
    """Every stop, named by its description ("Transversal y H.Garcia Lagos") when it has one."""
    with zipfile.ZipFile(archive) as feed:
        return {
            row["stop_id"]: Stop(
                row["stop_id"],
                (row.get("stop_desc") or row["stop_name"]).strip(),
                float(row["stop_lat"]),
                float(row["stop_lon"]),
            )
            for row in _rows(feed, "stops.txt")
        }


def read_feed(archive: Path, stop_ids: set[str], stops: dict[str, Stop] | None = None) -> Feed:
    """The feed, holding only the trips that call at one of `stop_ids`."""
    with zipfile.ZipFile(archive) as feed:
        through = {
            row["trip_id"] for row in _rows(feed, "stop_times.txt") if row["stop_id"] in stop_ids
        }
        calls: dict[str, list[Call]] = defaultdict(list)
        for row in _rows(feed, "stop_times.txt"):
            if row["trip_id"] in through:
                time = row["departure_time"] or row["arrival_time"]
                calls[row["trip_id"]].append(
                    Call(
                        int(row["stop_sequence"]), row["stop_id"], _seconds(time) if time else None
                    )
                )
        services = {
            row["service_id"]: Service(
                frozenset(day for days in DAY_TYPES.values() for day in days if row[day] == "1"),
                _date(row["start_date"]),
                _date(row["end_date"]),
            )
            for row in _rows(feed, "calendar.txt")
        }
        routes = {row["route_id"]: row["route_short_name"] for row in _rows(feed, "routes.txt")}
        trips = {
            row["trip_id"]: (row["route_id"], row["service_id"])
            for row in _rows(feed, "trips.txt")
            if row["trip_id"] in through
        }
    for trip_calls in calls.values():
        trip_calls.sort(key=lambda call: call.sequence)
    return Feed(stops or read_stops(archive), services, routes, trips, dict(calls))


def nearest_stops(
    stops: dict[str, Stop], spot: tuple[float, float], count: int = 5
) -> list[tuple[Stop, float]]:
    """The `count` stops nearest `spot` (lat, lng), with their distance in metres."""
    ranked = sorted(
        ((stop, metres_between(spot, (stop.lat, stop.lng))) for stop in stops.values()),
        key=lambda pair: pair[1],
    )
    return ranked[:count]


def last_buses(feed: Feed, stop_id: str, on: date) -> dict[str, dict | None]:
    """The latest bus at `stop_id` for each day type whose service runs on `on`.

    Each is `{time, estimated, route, published: {time, stop}}`: `time` is when it passes the
    stop, `published` the timetable's own time it is reckoned from (the stop itself when the
    feed gives one there). None where no trip calls that day.
    """
    latest: dict[str, tuple[int, dict]] = {}
    for trip_id, calls in feed.calls.items():
        route_id, service_id = feed.trips[trip_id]
        service = feed.services.get(service_id)
        if service is None or not service.start <= on <= service.end:
            continue
        for index, call in enumerate(calls):
            if call.stop_id != stop_id:
                continue
            passing = _passing(feed.stops, calls, index)
            if passing is None:
                continue
            seconds, published = passing
            bus = {
                "time": _clock(seconds),
                "estimated": published is not call,
                "route": feed.routes.get(route_id, route_id),
                "published": {
                    "time": _clock(published.seconds),
                    "stop": feed.stops[published.stop_id].name,
                },
            }
            for day_type, days in DAY_TYPES.items():
                if service.days & set(days) and seconds > latest.get(day_type, (-1, None))[0]:
                    latest[day_type] = (seconds, bus)
    return {day_type: latest[day_type][1] if day_type in latest else None for day_type in DAY_TYPES}


def _passing(stops: dict[str, Stop], calls: list[Call], index: int) -> tuple[int, Call] | None:
    """When the trip passes `calls[index]`, and the timed call that time comes from."""
    call = calls[index]
    if call.seconds is not None:
        return call.seconds, call
    before = next((k for k in range(index - 1, -1, -1) if calls[k].seconds is not None), None)
    after = next((k for k in range(index + 1, len(calls)) if calls[k].seconds is not None), None)
    if before is None or after is None:
        return None
    along = [0.0]
    for a, b in zip(calls[before:after], calls[before + 1 : after + 1], strict=True):
        along.append(along[-1] + metres_between(_where(stops, a), _where(stops, b)))
    share = along[index - before] / along[-1] if along[-1] else (index - before) / (after - before)
    start, end = calls[before].seconds, calls[after].seconds
    return round(start + share * (end - start)), calls[before]


def _where(stops: dict[str, Stop], call: Call) -> tuple[float, float]:
    stop = stops[call.stop_id]
    return stop.lat, stop.lng


def _rows(feed: zipfile.ZipFile, name: str):
    with feed.open(name) as raw:
        yield from csv.DictReader(io.TextIOWrapper(raw, encoding="utf-8-sig"))


def _seconds(time: str) -> int:
    hours, minutes, seconds = (int(part) for part in time.split(":"))
    return hours * 3600 + minutes * 60 + seconds


def _clock(seconds: int) -> str:
    """HH:MM on the clock, rounded to the minute: 25:10 reads 01:10."""
    minutes = round(seconds / 60)
    return f"{minutes // 60 % 24:02}:{minutes % 60:02}"


def _date(text: str) -> date:
    return date(int(text[:4]), int(text[4:6]), int(text[6:]))
