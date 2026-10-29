# /// script
# requires-python = ">=3.13,<3.14"
# dependencies = ["httpx>=0.28"]
# ///
"""Smoke test 7: the public data feeds answer — Open-Meteo forecast and sunset for Ciudad de
la Costa, the DNT metropolitan GTFS zip, one Overpass query. No keys.

    uv run scripts/smoke/s7_public_data.py
"""

import io
import zipfile

import httpx
from _env import Timer

AGENT = {"User-Agent": "Ronda-hackathon/0.1 (github.com/Cirorx/ronda)"}
FORECAST = (
    "https://api.open-meteo.com/v1/forecast?latitude=-34.83&longitude=-55.96"
    "&hourly=precipitation_probability,precipitation,wind_gusts_10m,weather_code"
    "&daily=sunrise,sunset&timezone=America/Montevideo&forecast_days=3"
)
GTFS = (
    "https://catalogodatos.gub.uy/dataset/1d50ccf7-121d-48a7-951e-28a02858d24e/resource/"
    "9f44b654-751a-42a4-a481-af91b7c9a2e4/download/gtfs_20260921.zip"
)
BOX = "(-34.87,-56.03,-34.76,-55.83)"
OVERPASS = (
    f'[out:json][timeout:25];(nwr["leisure"~"park|pitch"]{BOX};'
    f'nwr["amenity"~"community_centre|library"]{BOX};);out center 100;'
)

with Timer() as t:
    weather = httpx.get(FORECAST, headers=AGENT, timeout=30).json()
hourly = weather["hourly"]
print(
    f"Open-Meteo {t.s} s: {len(hourly['time'])} hours, sunset {weather['daily']['sunset'][0]}, "
    f"max rain probability {max(hourly['precipitation_probability'])}%"
)

with Timer() as t:
    response = httpx.get(GTFS, headers=AGENT, timeout=120, follow_redirects=True)
names = zipfile.ZipFile(io.BytesIO(response.content)).namelist()
print(f"GTFS {t.s} s, {len(response.content) / 1e6:.1f} MB: {sorted(names)}")
print("stop_times.txt present:", "stop_times.txt" in names)

with Timer() as t:
    places = httpx.post(
        "https://overpass-api.de/api/interpreter",
        data={"data": OVERPASS},
        headers=AGENT,
        timeout=60,
    ).json()["elements"]
named = [p["tags"].get("name") for p in places if p.get("tags", {}).get("name")]
print(f"Overpass {t.s} s: {len(places)} places, e.g. {named[:5]}")
