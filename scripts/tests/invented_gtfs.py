"""A tiny invented GTFS feed, shaped like the DNT one (times only at timepoints, no
calendar_dates.txt), so the last-bus and flyer tests never download the real timetable.

Stops A, B and C lie on one meridian, B a third of the way from A to C; D is a second stop near
B with no bus on weekends. No real line, stop or time.

`write_invented_city_gtfs` writes a second feed shaped like the Intendencia de Montevideo's
(a time at every stop, no `stop_desc`), with stop M1 next to Pocitos's centroid.
"""

import csv
import io
import zipfile
from pathlib import Path

STOPS = [
    ("A", "TERMINAL INVENTADA", "Terminal Inventada", -34.8000, -55.9400),
    ("B", "PARADA B", "Rambla y Calle Inventada", -34.8100, -55.9400),
    ("C", "FINAL C", "", -34.8300, -55.9400),
    ("D", "PARADA D", "Avenida Inventada y Calle B", -34.8102, -55.9403),
]
CALENDAR = [
    ("weekdays", "1", "1", "1", "1", "1", "0", "0", "20260302", "20261225"),
    ("saturdays", "0", "0", "0", "0", "0", "1", "0", "20260302", "20261225"),
    ("old-sundays", "0", "0", "0", "0", "0", "0", "1", "20250101", "20251231"),
]
ROUTES = [("r1", "X1"), ("r2", "X2")]
TRIPS = [
    ("r1", "weekdays", "t-evening"),
    ("r1", "weekdays", "t-after-midnight"),
    ("r2", "saturdays", "t-saturday"),
    ("r1", "old-sundays", "t-old-sunday"),
    ("r1", "weekdays", "t-starts-untimed"),
    ("r1", "no-such-service", "t-unknown-service"),
    ("r2", "weekdays", "t-d-only"),
]
STOP_TIMES = [
    ("t-evening", "22:00:00", "22:00:00", "A", "1"),
    ("t-evening", "", "", "B", "2"),
    ("t-evening", "22:30:00", "22:30:00", "C", "3"),
    ("t-after-midnight", "23:50:00", "23:50:00", "A", "1"),
    ("t-after-midnight", "", "", "B", "2"),
    ("t-after-midnight", "24:20:00", "24:20:00", "C", "3"),
    ("t-saturday", "21:00:00", "21:00:00", "A", "1"),
    ("t-saturday", "21:05:00", "21:05:00", "B", "2"),
    ("t-saturday", "21:30:00", "21:30:00", "C", "3"),
    ("t-old-sunday", "23:00:00", "23:00:00", "A", "1"),
    ("t-old-sunday", "", "", "B", "2"),
    ("t-old-sunday", "23:30:00", "23:30:00", "C", "3"),
    ("t-starts-untimed", "", "", "B", "1"),
    ("t-starts-untimed", "23:59:00", "23:59:00", "C", "2"),
    ("t-unknown-service", "23:58:00", "23:58:00", "B", "1"),
    ("t-d-only", "20:00:00", "20:00:00", "D", "1"),
    ("t-d-only", "20:10:00", "20:10:00", "C", "2"),
]


CITY_STOPS = [
    ("M1", "Calle Inventada Y Otra Calle", "", -34.9110, -56.1505),
    ("M2", "Terminal Inventada Del Centro", "", -34.9060, -56.1900),
]
CITY_CALENDAR = [
    ("1", "1", "1", "1", "1", "1", "0", "0", "20220103", "20261231"),
    ("2", "0", "0", "0", "0", "0", "1", "0", "20220108", "20261231"),
]
CITY_ROUTES = [("900", "X100")]
CITY_TRIPS = [("900", "1", "late"), ("900", "1", "after-midnight"), ("900", "2", "saturday")]
CITY_STOP_TIMES = [
    ("late", "23:30:00", "23:30:00", "M2", "1"),
    ("late", "23:41:00", "23:41:00", "M1", "2"),
    ("after-midnight", "24:05:00", "24:05:00", "M2", "1"),
    ("after-midnight", "24:16:00", "24:16:00", "M1", "2"),
    ("saturday", "22:50:00", "22:50:00", "M2", "1"),
    ("saturday", "23:01:00", "23:01:00", "M1", "2"),
]


def write_invented_city_gtfs(path: Path) -> Path:
    """Writes the invented city feed as a zip at `path`."""
    return write_invented_gtfs(
        path,
        stops=CITY_STOPS,
        calendar=CITY_CALENDAR,
        routes=CITY_ROUTES,
        trips=CITY_TRIPS,
        stop_times=CITY_STOP_TIMES,
    )


def write_invented_gtfs(
    path: Path,
    *,
    stops=STOPS,
    calendar=CALENDAR,
    routes=ROUTES,
    trips=TRIPS,
    stop_times=STOP_TIMES,
) -> Path:
    """Writes the feed as a zip at `path`, with a byte order mark like the real one."""
    tables = {
        "stops.txt": (
            ("stop_id", "stop_code", "stop_name", "stop_desc", "stop_lat", "stop_lon"),
            [(i, i, name, desc, lat, lng) for i, name, desc, lat, lng in stops],
        ),
        "calendar.txt": (
            (
                "service_id",
                *("monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"),
                "start_date",
                "end_date",
            ),
            calendar,
        ),
        "routes.txt": (
            ("route_id", "agency_id", "route_short_name", "route_long_name", "route_type"),
            [(i, "1", short, f"Invented {short}", "3") for i, short in routes],
        ),
        "trips.txt": (("route_id", "service_id", "trip_id"), trips),
        "stop_times.txt": (
            ("trip_id", "arrival_time", "departure_time", "stop_id", "stop_sequence"),
            stop_times,
        ),
    }
    with zipfile.ZipFile(path, "w") as feed:
        for name, (header, rows) in tables.items():
            text = io.StringIO()
            writer = csv.writer(text, quoting=csv.QUOTE_NONNUMERIC)
            writer.writerow(header)
            writer.writerows(rows)
            feed.writestr(name, "﻿" + text.getvalue())
    return path
