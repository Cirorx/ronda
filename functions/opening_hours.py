"""OpenStreetMap's `opening_hours`, the small part of it Algo chico needs (docs/PRODUCT.md §
Algo chico esta semana): is a place open on a given day at a given time?

Understood: `24/7`; rules joined by `;`, each an optional list of days (`Mo`, `Mo-Fr`,
`Sa,Su`) and then `off` or times (`09:00-18:00`, `09:00-13:00,15:00-19:00`, and `sunrise` and
`sunset` as an end of a range). A later rule replaces an earlier one for the days it names.
`sunrise` is read as 07:00, the latest it comes in Montevideo, so a place is never offered
before it is certainly light. Rules about public holidays (`PH`) are skipped: Ronda has no
holiday calendar. Anything else (months, week numbers, `+`, comments) is not understood, and a
place whose hours aren't understood is not offered: better to skip a plaza than to send
someone to a closed door. A range that ends before it starts runs to midnight.
"""

import re
from datetime import date, time

DAYS = ("Mo", "Tu", "We", "Th", "Fr", "Sa", "Su")
SUNRISE = "07:00"

_CLOCK = r"(?:\d{1,2}:\d{2}|sunrise|sunset)"
_RANGE = rf"{_CLOCK}\s*-\s*{_CLOCK}"
_TIMES = re.compile(rf"^{_RANGE}(?:\s*,\s*{_RANGE})*$")
_DAYS = re.compile(r"^(?:Mo|Tu|We|Th|Fr|Sa|Su)(?:-(?:Mo|Tu|We|Th|Fr|Sa|Su))?$")


class Unparsable(ValueError):
    """The hours use something this module doesn't read."""


def open_at(hours: str | None, on: date, at: time, sunset: str = "19:00") -> bool:
    """Whether a place with these `hours` is open on `on` at `at`.

    No hours at all means nothing says it is closed, so open; hours that aren't understood
    mean closed. `sunset` is that day's, as `HH:MM`.
    """
    if hours is None or not hours.strip():
        return True
    try:
        intervals = _intervals(hours.strip(), on.weekday(), sunset)
    except Unparsable:
        return False
    return any(start <= at < end for start, end in intervals)


def _intervals(hours: str, weekday: int, sunset: str) -> list[tuple[time, time]]:
    if hours == "24/7":
        return [(time(0), time.max)]
    intervals: list[tuple[time, time]] = []
    for rule in (part.strip() for part in hours.split(";")):
        if not rule:
            continue
        days, times = _split(rule)
        if days is None:  # a public-holiday rule
            continue
        if weekday in days:
            intervals = _times(times, sunset)
    return intervals


def _split(rule: str) -> tuple[set[int] | None, str]:
    """The weekdays a rule covers (every day when it names none; `None` for holidays) and its
    times, or `off`."""
    head, _, rest = rule.partition(" ")
    if head == "PH":
        return None, rest
    if not head or not (head[0].isalpha() and head.split(",")[0][:2] in DAYS):
        return set(range(7)), rule
    days: set[int] = set()
    for item in head.split(","):
        if not _DAYS.match(item):
            raise Unparsable(item)
        first, _, last = item.partition("-")
        start = DAYS.index(first)
        end = DAYS.index(last) if last else start
        days.update(range(start, end + 1) if start <= end else [*range(start, 7), *range(end + 1)])
    return days, rest.strip()


def _times(text: str, sunset: str) -> list[tuple[time, time]]:
    if text in ("off", "closed"):
        return []
    if not _TIMES.match(text):
        raise Unparsable(text)
    result = []
    for item in text.split(","):
        first, _, last = item.partition("-")
        start, end = _clock(first.strip(), sunset), _clock(last.strip(), sunset)
        result.append((start, end if end > start else time.max))
    return result


def _clock(text: str, sunset: str) -> time:
    text = {"sunrise": SUNRISE, "sunset": sunset}.get(text, text)
    hour, minute = (int(part) for part in text.split(":"))
    if hour == 24 and minute == 0:
        return time.max
    try:
        return time(hour, minute)
    except ValueError as error:
        raise Unparsable(text) from error
