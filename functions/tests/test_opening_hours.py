"""OpenStreetMap's opening_hours, the part Algo chico reads."""

from datetime import date, time

import pytest

from opening_hours import open_at

MONDAY, SATURDAY, SUNDAY = date(2026, 11, 2), date(2026, 11, 7), date(2026, 11, 8)


class TestOpenAt:
    def test_a_place_with_no_hours_is_not_known_to_be_closed(self):
        assert open_at(None, MONDAY, time(10))
        assert open_at("  ", MONDAY, time(10))

    def test_always_open(self):
        assert open_at("24/7", SUNDAY, time(3))

    def test_a_weekday_range_and_a_time_range(self):
        assert open_at("Mo-Fr 09:00-18:00", MONDAY, time(9))
        assert open_at("Mo-Fr 09:00-18:00", MONDAY, time(17, 59))
        assert not open_at("Mo-Fr 09:00-18:00", MONDAY, time(18))
        assert not open_at("Mo-Fr 09:00-18:00", MONDAY, time(8, 59))
        assert not open_at("Mo-Fr 09:00-18:00", SATURDAY, time(10))

    def test_a_list_of_days_and_a_list_of_ranges(self):
        hours = "Sa,Su 08:00-13:00,15:00-19:00"

        assert open_at(hours, SATURDAY, time(9))
        assert not open_at(hours, SATURDAY, time(14))
        assert open_at(hours, SUNDAY, time(16))
        assert not open_at(hours, MONDAY, time(9))

    def test_a_later_rule_replaces_an_earlier_one_for_its_days(self):
        hours = "Mo-Su 09:00-18:00; Su off"

        assert open_at(hours, SATURDAY, time(10))
        assert not open_at(hours, SUNDAY, time(10))

    def test_a_rule_with_no_days_covers_every_day(self):
        assert open_at("10:00-12:00", SUNDAY, time(11))

    def test_a_range_of_days_that_wraps_the_week(self):
        assert open_at("Sa-Mo 10:00-12:00", SUNDAY, time(11))
        assert open_at("Sa-Mo 10:00-12:00", MONDAY, time(11))
        assert not open_at("Sa-Mo 10:00-12:00", date(2026, 11, 3), time(11))

    def test_public_holiday_rules_are_skipped(self):
        assert open_at("Mo-Su 09:00-18:00; PH off", MONDAY, time(10))

    def test_empty_rules_between_semicolons_are_skipped(self):
        assert open_at("Mo-Su 09:00-18:00;;", MONDAY, time(10))

    def test_off_and_closed_are_closed(self):
        assert not open_at("off", MONDAY, time(10))
        assert not open_at("Mo-Fr closed", MONDAY, time(10))

    def test_sunrise_is_seven_and_sunset_is_the_days(self):
        assert open_at("sunrise-sunset", MONDAY, time(7), sunset="19:50")
        assert not open_at("sunrise-sunset", MONDAY, time(6, 30), sunset="19:50")
        assert open_at("sunrise-sunset", MONDAY, time(19, 49), sunset="19:50")
        assert not open_at("sunrise-sunset", MONDAY, time(19, 50), sunset="19:50")

    def test_a_range_that_ends_before_it_starts_runs_to_midnight(self):
        assert open_at("Mo 22:00-02:00", MONDAY, time(23))
        assert not open_at("Mo 22:00-02:00", MONDAY, time(21))

    def test_closing_at_twenty_four_is_midnight(self):
        assert open_at("Mo 18:00-24:00", MONDAY, time(23, 30))

    @pytest.mark.parametrize(
        "hours",
        [
            "Mo-Fr",
            "Nov-Mar Mo-Fr 09:00-18:00",
            "Mo-Fr 09:00+",
            "Mo-Xx 09:00-18:00",
            "Mo-Fr 25:00-26:00",
            "Mo-Fr 09:00-18:00 open",
            "by appointment",
        ],
    )
    def test_hours_that_are_not_understood_read_as_closed(self, hours):
        assert not open_at(hours, MONDAY, time(10))
