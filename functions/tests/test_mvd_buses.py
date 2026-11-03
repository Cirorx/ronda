"""mvd_buses.py: the Intendencia de Montevideo's live buses, over a stand-in transport that plays
back answers shaped like the real API's (recorded 2026-11-02 at stop 4078, Pocitos, by smoke
test 11, trimmed to the fields read). Nothing here reaches a network."""

import httpx
import pytest

import mvd_buses

STOPS = [
    {
        "busstopId": 4078,
        "street1": "26 DE MARZO",
        "street2": "JOSE ELLAURI",
        "location": {"type": "Point", "coordinates": [-56.15312, -34.91275]},
    },
    {
        "busstopId": 546,
        "street1": "CORUÑA",
        "street2": "GRAL JULIO AMADEO ROLETTI",
        "location": {"type": "Point", "coordinates": [-56.146758, -34.872405]},
    },
    {"busstopId": 1, "street1": "SIN UBICACION"},
]
LINES = [{"line": "191"}, {"line": "192"}, {"line": "405"}, {"line": "316"}]
UPCOMING = [
    {"line": "405", "destination": "PARQUE RODÓ", "eta": 2, "distance": 20534},
    {"line": "316", "destination": "POCITOS", "eta": 586, "distance": 13992},
    {"line": "192", "destination": "PARQUE RODÓ", "eta": 921, "distance": 11474},
    {"line": "191", "destination": "PUNTA CARRETAS", "eta": 2514, "distance": 2410},
]
"""The real answer: the first two can't be true (2 s from 20 km; 86 km/h), the last is more
than half an hour away."""
PLAZA = (-34.9125, -56.1530)
"""Plaza Gomensoro, Pocitos: stop 4078 is about 30 m away."""


class Clock:
    def __init__(self) -> None:
        self.now = 0.0

    def __call__(self) -> float:
        return self.now


class Api:
    """Plays the API: answers by path, counts the token requests, and can fail or stall."""

    def __init__(self, *, upcoming=UPCOMING, lines=LINES, stops=STOPS, lifetime=300):
        self.upcoming, self.lines, self.stops, self.lifetime = upcoming, lines, stops, lifetime
        self.tokens = 0
        self.requests: list[httpx.Request] = []
        self.fail: dict[str, httpx.Response] = {}
        self.clock = Clock()
        self.stall = 0.0

    def __call__(self, request: httpx.Request) -> httpx.Response:
        self.requests.append(request)
        self.clock.now += self.stall
        path = request.url.path
        for part, response in self.fail.items():
            if part in path or part == str(request.url.host):
                return response
        if request.url.host == "mvdapi-auth.montevideo.gub.uy":
            self.tokens += 1
            return httpx.Response(
                200, json={"access_token": f"token-{self.tokens}", "expires_in": self.lifetime}
            )
        assert request.headers["Authorization"] == f"Bearer token-{self.tokens}"
        if path.endswith("/upcomingbuses"):
            return httpx.Response(200, json=self.upcoming)
        if path.endswith("/lines"):
            return httpx.Response(200, json=self.lines)
        return httpx.Response(200, json=self.stops)

    def buses(self) -> mvd_buses.MvdBuses:
        http = httpx.Client(transport=httpx.MockTransport(self))
        return mvd_buses.MvdBuses(http, "invented-id", "invented-secret", clock=self.clock)


class TestNextBuses:
    def test_the_nearest_stop_and_its_believable_arrivals(self):
        api = Api()

        found = api.buses().next_buses(*PLAZA)

        assert found.stop == mvd_buses.BusStop(
            4078, "26 de Marzo y Jose Ellauri", -34.91275, -56.15312
        )
        assert found.metres == 30
        assert found.arrivals == [mvd_buses.Arrival("192", "Parque Rodó", 15)]
        upcoming = api.requests[-1]
        assert upcoming.url.path.endswith("/buses/busstops/4078/upcomingbuses")
        assert upcoming.url.params["lines"] == "191,192,316,405"
        assert upcoming.url.params["amountperline"] == "1"

    def test_the_token_asks_with_the_client_credentials(self):
        api = Api()

        api.buses().next_buses(*PLAZA)

        form = dict(httpx.QueryParams(api.requests[0].content.decode()))
        assert form == {
            "grant_type": "client_credentials",
            "client_id": "invented-id",
            "client_secret": "invented-secret",
        }

    def test_keeps_the_token_and_the_stops_while_they_last(self):
        api = Api()
        buses = api.buses()

        buses.next_buses(*PLAZA)
        buses.next_buses(*PLAZA)

        assert api.tokens == 1
        assert sum(r.url.path.endswith("/busstops") for r in api.requests) == 1

    def test_renews_the_token_before_it_expires(self):
        api = Api()
        buses = api.buses()

        buses.next_buses(*PLAZA)
        api.clock.now += 300 - mvd_buses.TOKEN_MARGIN
        buses.next_buses(*PLAZA)

        assert api.tokens == 2

    def test_none_when_no_stop_is_near_outside_montevideo(self):
        assert Api().buses().next_buses(-34.8330, -55.9380) is None

    def test_none_when_there_are_no_stops_at_all(self):
        assert Api(stops=[]).buses().next_buses(*PLAZA) is None

    def test_a_stop_without_lines_has_no_arrivals(self):
        api = Api(lines=[])

        found = api.buses().next_buses(*PLAZA)

        assert found.arrivals == []
        assert not any(r.url.path.endswith("/upcomingbuses") for r in api.requests)


class TestFailures:
    @pytest.mark.parametrize("part", ["/busstops", "/lines", "/upcomingbuses"])
    def test_an_error_answer_is_unavailable(self, part):
        api = Api()
        api.fail[part] = httpx.Response(503)

        with pytest.raises(mvd_buses.BusesUnavailable):
            api.buses().next_buses(*PLAZA)

    def test_a_refused_token_is_unavailable(self):
        api = Api()
        api.fail["mvdapi-auth.montevideo.gub.uy"] = httpx.Response(401, json={"error": "no"})

        with pytest.raises(mvd_buses.BusesUnavailable, match="token"):
            api.buses().next_buses(*PLAZA)

    def test_a_token_answer_without_a_token_is_unavailable(self):
        api = Api()
        api.fail["mvdapi-auth.montevideo.gub.uy"] = httpx.Response(200, json={"nope": 1})

        with pytest.raises(mvd_buses.BusesUnavailable, match="token"):
            api.buses().next_buses(*PLAZA)

    def test_an_answer_that_is_not_a_list_is_unavailable(self):
        api = Api()
        api.fail["/lines"] = httpx.Response(200, json={"error": "rate"})

        with pytest.raises(mvd_buses.BusesUnavailable, match="not a list"):
            api.buses().next_buses(*PLAZA)

    def test_an_answer_that_is_not_json_is_unavailable(self):
        api = Api()
        api.fail["/busstops"] = httpx.Response(200, text="<html>")

        with pytest.raises(mvd_buses.BusesUnavailable):
            api.buses().next_buses(*PLAZA)

    def test_past_the_budget_it_gives_up_rather_than_wait(self):
        api = Api()
        api.stall = mvd_buses.BUDGET / 2

        with pytest.raises(mvd_buses.BusesUnavailable, match="too slow"):
            api.buses().next_buses(*PLAZA)


class TestArrivals:
    def test_one_per_line_soonest_first_at_most_three(self):
        rows = [
            {"line": "1", "destination": "A", "eta": 600, "distance": 1000},
            {"line": "1", "destination": "A", "eta": 300, "distance": 500},
            {"line": "2", "destination": "B", "eta": 120},
            {"line": "2", "destination": "B", "eta": 500},
            {"line": "3", "destination": "", "eta": 900, "distance": 0},
            {"line": "4", "destination": "D", "eta": 1200, "distance": 100},
        ]

        assert mvd_buses.arrivals(rows) == [
            mvd_buses.Arrival("2", "B", 2),
            mvd_buses.Arrival("1", "A", 5),
            mvd_buses.Arrival("3", "", 15),
        ]

    @pytest.mark.parametrize(
        "row",
        [
            {"line": "1", "eta": 0},
            {"line": "1", "eta": "soon"},
            {"line": "", "eta": 60},
            {"eta": 60},
            {"line": "1", "eta": mvd_buses.HORIZON + 1},
            {"line": "1", "eta": 10, "distance": 10_000},
        ],
    )
    def test_leaves_out_what_cannot_be_believed(self, row):
        assert mvd_buses.arrivals([row]) == []

    def test_a_bus_seconds_away_reads_one_minute(self):
        assert mvd_buses.arrivals([{"line": "7", "eta": 20, "distance": 50}])[0].minutes == 1


class TestFromEnvironment:
    def test_builds_the_client_from_the_secrets(self, monkeypatch):
        monkeypatch.setenv("MVD_API_CLIENT_ID", "invented-id")
        monkeypatch.setenv("MVD_API_SECRET_ID", "invented-secret")

        assert isinstance(mvd_buses.from_environment(httpx.Client()), mvd_buses.MvdBuses)

    @pytest.mark.parametrize("missing", ["MVD_API_CLIENT_ID", "MVD_API_SECRET_ID"])
    def test_none_without_either_key(self, monkeypatch, missing):
        monkeypatch.setenv("MVD_API_CLIENT_ID", "invented-id")
        monkeypatch.setenv("MVD_API_SECRET_ID", "invented-secret")
        monkeypatch.delenv(missing)

        assert mvd_buses.from_environment(httpx.Client()) is None


def test_street_names_read_as_people_write_them():
    assert mvd_buses._title("26 DE MARZO") == "26 de Marzo"
    assert mvd_buses._title("AV DE LAS AMERICAS") == "Av de las Americas"
    assert mvd_buses._title("DEL PLATA") == "Del Plata"
