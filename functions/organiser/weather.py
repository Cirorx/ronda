"""Open-Meteo's forecast and sunset for one place and day (CC BY 4.0, credited in the README).

One request gives the day's hourly rain probability, rain and gusts, and its sunset, in
Montevideo's time; `OpenMeteo` keeps each answer for the rest of the run, so the forecast and the
sunset of the same day cost one call. Tests pass a fake `Weather`: nothing here runs offline.
"""

from dataclasses import dataclass
from datetime import date
from typing import Protocol

import httpx

OPEN_METEO = "https://api.open-meteo.com/v1/forecast"
SOURCE = "Open-Meteo"
HOURLY = "precipitation_probability,precipitation,wind_gusts_10m"


class WeatherUnavailable(RuntimeError):
    """Open-Meteo didn't answer, or answered something else."""


@dataclass(frozen=True)
class Forecast:
    """The worst of the meeting's hours: rain probability (%), rain (mm) and gusts (km/h)."""

    day: date
    hour: int
    rain_probability: int
    rain_mm: float
    gusts_kmh: int


@dataclass(frozen=True)
class Day:
    """One day at one place: each hour's values, and the sunset as `HH:MM`."""

    hours: dict[int, tuple[int, float, int]]
    """hour → (rain probability %, rain mm, gusts km/h)."""
    sunset: str

    def forecast(self, day: date, hour: int, span: int = 2) -> Forecast:
        """The worst values over `span` hours from `hour`, the meeting's length."""
        rows = [self.hours[h] for h in range(hour, hour + span) if h in self.hours]
        if not rows:
            raise WeatherUnavailable(f"no forecast for {hour}:00")
        return Forecast(
            day=day,
            hour=hour,
            rain_probability=max(row[0] for row in rows),
            rain_mm=round(max(row[1] for row in rows), 1),
            gusts_kmh=max(row[2] for row in rows),
        )


class Weather(Protocol):
    """The forecast source the tools read."""

    def day(self, lat: float, lng: float, on: date) -> Day: ...


class OpenMeteo:
    """`Weather` from Open-Meteo's free API, over `http`."""

    def __init__(self, http: httpx.Client) -> None:
        self._http = http
        self._days: dict[tuple[float, float, date], Day] = {}

    def day(self, lat: float, lng: float, on: date) -> Day:
        key = (round(lat, 4), round(lng, 4), on)
        if key not in self._days:
            self._days[key] = self._fetch(*key)
        return self._days[key]

    def _fetch(self, lat: float, lng: float, on: date) -> Day:
        try:
            response = self._http.get(
                OPEN_METEO,
                params={
                    "latitude": lat,
                    "longitude": lng,
                    "hourly": HOURLY,
                    "daily": "sunset",
                    "timezone": "America/Montevideo",
                    "start_date": on.isoformat(),
                    "end_date": on.isoformat(),
                },
                timeout=10,
            )
            response.raise_for_status()
            return parse(response.json())
        except (httpx.HTTPError, ValueError, KeyError, TypeError, IndexError) as error:
            raise WeatherUnavailable(type(error).__name__) from error


def parse(body: dict) -> Day:
    """A `Day` from Open-Meteo's JSON: `hourly.time` like `2026-11-05T16:00`."""
    hourly = body["hourly"]
    hours = {
        int(at[11:13]): (int(p or 0), float(mm or 0), round(g or 0))
        for at, p, mm, g in zip(
            hourly["time"],
            hourly["precipitation_probability"],
            hourly["precipitation"],
            hourly["wind_gusts_10m"],
            strict=True,
        )
    }
    return Day(hours=hours, sunset=body["daily"]["sunset"][0][11:16])
