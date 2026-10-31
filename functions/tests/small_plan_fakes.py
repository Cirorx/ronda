"""Stand-ins for Algo chico's outside world: a forecast, and Spark 1.3 filling a `Draft`.

The week starts on Monday 2026-11-02 at 12:00 in Montevideo (UTC-3, ISO week 45)."""

from datetime import date, timedelta
from types import SimpleNamespace

from organiser.weather import Day, WeatherUnavailable
from tests.organiser_fakes import at

MONDAY = date(2026, 11, 2)
NOW = at(2, 12)
"""Monday noon."""


def day(rain: int = 5, mm: float = 0.0, sunset: str = "19:50") -> Day:
    """A day whose every hour reads as `rain` % and `mm`."""
    return Day(hours={hour: (rain, mm, 10) for hour in range(24)}, sunset=sunset)


def week(wet: tuple[int, ...] = (), start: date = MONDAY, days: int = 8) -> dict[date, Day]:
    """Dry days from `start`, but the days at these offsets, which are wet."""
    return {
        start + timedelta(days=offset): (day(80, 2.0) if offset in wet else day())
        for offset in range(days)
    }


class FakeForecast:
    """A forecast that answers `days` from `table`, or fails."""

    def __init__(self, table: dict[date, Day] | None = None, *, fail: bool = False) -> None:
        self.table = week() if table is None else table
        self.fail = fail
        self.calls: list[tuple[float, float, date, date]] = []

    def days(self, lat: float, lng: float, first: date, last: date) -> dict[date, Day]:
        self.calls.append((lat, lng, first, last))
        if self.fail:
            raise WeatherUnavailable("down")
        return {on: d for on, d in self.table.items() if first <= on <= last}


def spark_drafting(draft=None, *, error: Exception | None = None):
    """An `openai.OpenAI` whose `parse` answers `draft` (or raises); returns it and its calls."""
    calls = []

    def parse(**kwargs):
        calls.append(kwargs)
        if error:
            raise error
        message = SimpleNamespace(parsed=draft)
        return SimpleNamespace(choices=[SimpleNamespace(message=message)])

    completions = SimpleNamespace(parse=parse)
    return SimpleNamespace(chat=SimpleNamespace(completions=completions)), calls
