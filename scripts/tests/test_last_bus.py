from datetime import date

import pytest

import last_bus
from tests.invented_gtfs import write_invented_gtfs

ON = date(2026, 11, 1)


@pytest.fixture
def archive(tmp_path):
    return write_invented_gtfs(tmp_path / "gtfs.zip")


def test_a_stop_is_named_by_its_description_or_else_its_name(archive):
    stops = last_bus.read_stops(archive)

    assert stops["B"].name == "Rambla y Calle Inventada"
    assert stops["C"].name == "FINAL C"
    assert (stops["A"].lat, stops["A"].lng) == (-34.8, -55.94)


def test_the_nearest_stops_come_first_with_their_distance(archive):
    stops = last_bus.read_stops(archive)

    nearest = last_bus.nearest_stops(stops, (-34.8101, -55.9401), count=2)

    assert [stop.id for stop, _ in nearest] == ["B", "D"]
    assert nearest[0][1] < 20


def test_the_feed_keeps_only_the_trips_through_the_stops_asked_for(archive):
    feed = last_bus.read_feed(archive, {"D"})

    assert set(feed.calls) == {"t-d-only"} == set(feed.trips)
    assert [call.stop_id for call in feed.calls["t-d-only"]] == ["D", "C"]


def test_a_stop_between_timepoints_gets_an_estimate_along_the_route(archive):
    feed = last_bus.read_feed(archive, {"B"})

    buses = last_bus.last_buses(feed, "B", ON)

    assert buses["weekday"] == {
        "time": "00:00",
        "estimated": True,
        "route": "X1",
        "published": {"time": "23:50", "stop": "Terminal Inventada"},
    }


def test_a_timed_stop_gives_its_published_time(archive):
    feed = last_bus.read_feed(archive, {"B"})

    assert last_bus.last_buses(feed, "B", ON)["saturday"] == {
        "time": "21:05",
        "estimated": False,
        "route": "X2",
        "published": {"time": "21:05", "stop": "Rambla y Calle Inventada"},
    }


def test_a_service_outside_its_dates_runs_no_bus(archive):
    feed = last_bus.read_feed(archive, {"B"})

    assert last_bus.last_buses(feed, "B", ON)["sunday"] is None
    assert last_bus.last_buses(feed, "B", date(2025, 6, 1))["sunday"]["time"] == "23:10"


def test_a_stop_with_no_bus_on_a_day_type_says_none(archive):
    feed = last_bus.read_feed(archive, {"D"})

    assert last_bus.last_buses(feed, "D", ON) == {
        "weekday": {
            "time": "20:00",
            "estimated": False,
            "route": "X2",
            "published": {"time": "20:00", "stop": "Avenida Inventada y Calle B"},
        },
        "saturday": None,
        "sunday": None,
    }


def test_a_trip_without_a_timepoint_before_the_stop_is_left_out():
    stops = {
        "B": last_bus.Stop("B", "B", -34.81, -55.94),
        "C": last_bus.Stop("C", "C", -34.83, -55.94),
    }
    calls = [last_bus.Call(1, "B", None), last_bus.Call(2, "C", 3600)]

    assert last_bus._passing(stops, calls, 0) is None


def test_stops_in_one_place_share_the_time_by_their_order():
    here = last_bus.Stop("H", "H", -34.81, -55.94)
    stops = {"H": here}
    calls = [last_bus.Call(1, "H", 0), last_bus.Call(2, "H", None), last_bus.Call(3, "H", 600)]

    assert last_bus._passing(stops, calls, 1) == (300, calls[0])


@pytest.mark.parametrize(
    ("seconds", "clock"),
    [
        (0, "00:00"),
        (22 * 3600 + 10 * 60 + 29, "22:10"),
        (25 * 3600 + 10 * 60, "01:10"),
        (86370, "00:00"),
    ],
)
def test_the_clock_wraps_after_midnight_and_rounds_to_the_minute(seconds, clock):
    assert last_bus._clock(seconds) == clock
