"""small_plans.py beyond the filter: the day, the words, and the callable's body."""

import logging
from datetime import date, time

import pytest

import small_plans as sp
import voice_signup as voice
from tests.organiser_fakes import at
from tests.small_plan_fakes import MONDAY, NOW, FakeForecast, day, spark_drafting, week
from tests.test_voice_signup import FakeBlob, http_answering, transcript, wav

TUESDAY = date(2026, 11, 3)
FRIDAY = date(2026, 11, 6)
UID = "demo-001"
USER = {"terms": {"version": "2026-10-27"}, "barrio": "solymar-norte"}


def draft(**fields) -> sp.Draft:
    base = {
        "activity": "Caminar 30 minutos por la rambla",
        "day": "unknown",
        "time": "19:00",
        "place": "",
        "kind": "walk",
        "outdoor": True,
        "flag": "none",
    }
    return sp.Draft(**(base | fields))


class TestCandidateDays:
    def test_the_next_seven_days_from_today_when_the_hour_is_still_ahead(self):
        days = sp.candidate_days(NOW, time(18))

        assert days[0] == MONDAY
        assert len(days) == 7

    def test_today_is_out_when_the_hour_is_less_than_an_hour_away(self):
        days = sp.candidate_days(at(2, 17, 30), time(18))

        assert days[0] == TUESDAY
        assert len(days) == 7


class TestRainAt:
    def test_reads_the_worst_probability_over_the_plans_hours(self):
        assert sp.rain_at(week(), MONDAY, time(18)) == 5

    def test_a_wet_hour_reads_as_at_least_wet_even_with_a_low_probability(self):
        assert sp.rain_at({MONDAY: day(10, 1.0)}, MONDAY, time(18)) == sp.WET_PROBABILITY

    def test_no_word_on_the_day_or_the_hour_is_none(self):
        assert sp.rain_at({}, MONDAY, time(18)) is None
        assert (
            sp.rain_at({MONDAY: day().__class__(hours={}, sunset="19:50")}, MONDAY, time(18))
            is None
        )


class TestChooseSlot:
    def days(self):
        return sp.candidate_days(NOW, time(18))

    def choose(self, *, named=None, outdoor=True, wet=(), table=None):
        return sp.choose_slot(
            self.days(),
            time(18),
            named=named,
            outdoor=outdoor,
            week=week(wet) if table is None else table,
        )

    def test_no_days_left_is_no_slot(self):
        assert sp.choose_slot([], time(18), named=None, outdoor=True, week={}) is None

    def test_indoors_the_named_day_or_the_first(self):
        assert self.choose(outdoor=False) == sp.Slot(MONDAY, time(18), None)
        assert self.choose(outdoor=False, named=FRIDAY) == sp.Slot(FRIDAY, time(18), None)

    def test_a_named_day_outside_the_week_is_ignored(self):
        assert self.choose(named=date(2027, 1, 1)).on == MONDAY

    def test_outdoors_with_no_day_named_it_is_the_earliest_dry_day(self):
        assert self.choose(wet=(0, 1)) == sp.Slot(date(2026, 11, 4), time(18), True)

    def test_outdoors_a_dry_named_day_stays(self):
        assert self.choose(named=FRIDAY, wet=(0,)) == sp.Slot(FRIDAY, time(18), True)

    def test_outdoors_a_wet_named_day_moves_to_the_nearest_dry_one(self):
        slot = self.choose(named=FRIDAY, wet=(4, 5))  # Friday and Saturday are wet

        assert slot == sp.Slot(date(2026, 11, 5), time(18), True, moved=True)

    def test_with_no_dry_day_it_is_the_day_with_the_least_rain(self):
        table = {on: day(95 - n * 5, 2.0) for n, on in enumerate(self.days())}

        slot = self.choose(table=table)

        assert slot.on == self.days()[-1]
        assert slot.dry is False

    def test_with_no_forecast_it_is_the_named_day_or_the_first(self):
        assert self.choose(table={}) == sp.Slot(MONDAY, time(18), None)
        assert self.choose(table={}, named=FRIDAY).on == FRIDAY

    def test_a_named_day_the_forecast_does_not_cover_moves_to_the_nearest_known_dry_one(self):
        table = {on: d for on, d in week().items() if on != FRIDAY}

        slot = self.choose(named=FRIDAY, table=table)

        assert slot == sp.Slot(date(2026, 11, 5), time(18), True, moved=True)


class TestSchedule:
    def shaped(self, **fields):
        base = {
            "activity": "Caminar",
            "day": None,
            "time": None,
            "place": None,
            "kind": "walk",
            "outdoor": True,
        }
        return sp.Shaped(**(base | fields))

    def test_the_kinds_default_hour_is_used_when_none_was_said(self):
        assert sp.schedule(self.shaped(kind="feria"), now=NOW, week=week()).at == time(10)
        assert sp.schedule(self.shaped(), now=NOW, week=week()).at == time(18)

    def test_the_hour_and_weekday_the_member_said(self):
        slot = sp.schedule(self.shaped(day="fri", time="19:00"), now=NOW, week=week())

        assert (slot.on, slot.at) == (FRIDAY, time(19))

    def test_a_weekday_that_already_passed_today_waits_for_next_week(self):
        slot = sp.schedule(self.shaped(day="mon", time="09:00"), now=NOW, week=week())

        assert slot.on == date(2026, 11, 9)


class TestForecastWeek:
    def test_asks_for_the_barrios_centroid_over_the_next_week(self):
        forecast = FakeForecast()

        found = sp.forecast_week(forecast, "solymar-norte", NOW)

        assert found
        assert forecast.calls == [(-34.8255, -55.9420, MONDAY, date(2026, 11, 9))]

    def test_an_unknown_barrio_has_no_forecast(self):
        forecast = FakeForecast()

        assert sp.forecast_week(forecast, None, NOW) == {}
        assert sp.forecast_week(forecast, "nowhere", NOW) == {}
        assert forecast.calls == []

    def test_open_meteo_down_has_no_forecast(self, caplog):
        with caplog.at_level(logging.WARNING):
            assert sp.forecast_week(FakeForecast(fail=True), "solymar-norte", NOW) == {}
        assert "forecast failed" in caplog.text


class TestReadDraft:
    def test_asks_spark_for_the_strict_draft_with_todays_date(self):
        client, calls = spark_drafting(draft())

        assert sp.read_draft("caminar", NOW, client=client) == draft()
        [call] = calls
        assert call["response_format"] is sp.Draft
        assert call["model"] == voice.FIELDS_MODEL
        assert "mon 2026-11-02" in call["messages"][0]["content"]
        assert call["messages"][1] == {"role": "user", "content": "caminar"}

    def test_an_sdk_error_is_the_model_being_unavailable(self):
        client, _ = spark_drafting(error=RuntimeError("boom"))

        with pytest.raises(voice.ModelUnavailable, match="RuntimeError"):
            sp.read_draft("caminar", NOW, client=client)

    def test_nothing_parsed_is_the_model_being_unavailable(self):
        client, _ = spark_drafting(None)

        with pytest.raises(voice.ModelUnavailable):
            sp.read_draft("caminar", NOW, client=client)


class TestWordsOfNote:
    PATH = f"audio/{UID}/note-1.wav"

    def read(self, blob, http, path=PATH):
        return sp.words_of_note(uid=UID, path=path, blob=lambda _: blob, api_key="key", http=http)

    def test_reads_the_note_and_deletes_it(self):
        blob = FakeBlob(wav())

        words = self.read(blob, http_answering(transcript("quiero caminar")))

        assert words == "quiero caminar"
        assert blob.deleted

    def test_deletes_it_when_it_cannot_be_read(self):
        blob = FakeBlob(b"not a wav")

        with pytest.raises(voice.BadVoiceNote):
            self.read(blob, http_answering())
        assert blob.deleted

    def test_a_note_that_is_not_the_callers_is_refused_and_left_alone(self):
        blob = FakeBlob(wav())

        with pytest.raises(PermissionError):
            self.read(blob, http_answering(), path="audio/demo-002/note-1.wav")
        assert not blob.deleted

    def test_a_failed_delete_is_logged_and_the_words_still_come_back(self, caplog):
        blob = FakeBlob(wav(), delete_error=RuntimeError("gone"))

        with caplog.at_level(logging.WARNING):
            words = self.read(blob, http_answering(transcript("hola")))

        assert words == "hola"
        assert "delete failed (RuntimeError)" in caplog.text


class TestShapeWords:
    def shape(self, words, drafted=None, *, forecast=None, barrio="solymar-norte"):
        client, calls = spark_drafting(drafted or draft())
        answer = sp.shape_words(
            words, now=NOW, barrio=barrio, weather=forecast or FakeForecast(), client=client
        )
        return answer, calls

    def test_a_spoken_sentence_becomes_a_dated_plan_whose_day_comes_from_the_forecast(self):
        forecast = FakeForecast(week(wet=(0, 1)))

        answer, _ = self.shape("caminar por la rambla a las siete", forecast=forecast)

        assert answer == {
            "plan": {
                "activity": "Caminar 30 minutos por la rambla",
                "date": "2026-11-04",
                "time": "19:00",
                "place": None,
                "kind": "walk",
                "outdoor": True,
                "dry": True,
                "moved": False,
            }
        }

    def test_the_day_the_member_named_moves_when_it_rains(self):
        forecast = FakeForecast(week(wet=(4,)))

        answer, _ = self.shape("caminar el viernes", draft(day="fri"), forecast=forecast)

        assert answer["plan"]["date"] == "2026-11-05"
        assert answer["plan"]["moved"] is True

    def test_without_a_forecast_the_plan_still_comes_back(self):
        answer, _ = self.shape("caminar", forecast=FakeForecast(fail=True))

        assert answer["plan"]["dry"] is None

    def test_nothing_said_is_nothing_to_read(self):
        with pytest.raises(sp.BadWords):
            self.shape("   ")

    def test_a_dropped_topic_never_reaches_the_model(self):
        answer, calls = self.shape("quiero bajar de peso")

        assert answer == {"rejected": "diet"}
        assert calls == []

    def test_a_draft_the_filter_drops_is_rejected(self):
        answer, _ = self.shape("caminar", draft(flag="people"))

        assert answer == {"rejected": "people"}

    def test_a_plan_with_no_day_left_is_unclear(self, monkeypatch):
        monkeypatch.setattr(sp, "schedule", lambda *args, **kwargs: None)

        answer, _ = self.shape("caminar")

        assert answer == {"rejected": "unclear"}


class TestShapeRequest:
    def request(self, data, *, user=USER, blob=None, http=None, drafted=None):
        client, _ = spark_drafting(drafted or draft())
        return sp.shape_request(
            uid=UID,
            data=data,
            user=user,
            now=NOW,
            blob=lambda _: blob,
            api_key="key",
            http=http or http_answering(),
            client=client,
            weather=FakeForecast(),
        )

    def test_shapes_what_the_caller_typed(self):
        assert "plan" in self.request({"text": "caminar por la rambla"})

    def test_cuts_what_was_typed_at_three_hundred_characters(self, monkeypatch):
        seen = []
        monkeypatch.setattr(
            sp, "shape_words", lambda words, **kwargs: seen.append(words) or {"plan": {}}
        )

        self.request({"text": "a" * 500})

        assert [len(words) for words in seen] == [sp.MAX_TYPED]

    def test_shapes_what_voice_transcribe_heard_live(self, monkeypatch):
        seen = []
        monkeypatch.setattr(
            sp, "shape_words", lambda words, **kwargs: seen.append(words) or {"plan": {}}
        )

        self.request({"transcript": "  caminar  por\nla rambla " + "a" * 2000})

        assert seen[0].startswith("caminar por la rambla ")
        assert len(seen[0]) == sp.MAX_SPOKEN

    def test_reads_and_deletes_a_voice_note(self):
        blob = FakeBlob(wav())

        answer = self.request(
            {"path": f"audio/{UID}/note-1.wav"},
            blob=blob,
            http=http_answering(transcript("caminar por la rambla")),
        )

        assert "plan" in answer
        assert blob.deleted

    def test_refuses_a_caller_who_has_not_accepted_the_terms(self):
        for user in (None, {"barrio": "solymar-norte"}):
            with pytest.raises(voice.TermsMissing):
                self.request({"text": "caminar"}, user=user)

    @pytest.mark.parametrize("data", [None, {}, "caminar", {"text": 5}])
    def test_needs_words_or_a_note(self, data):
        with pytest.raises(sp.BadWords):
            self.request(data)

    def test_a_voice_note_that_says_nothing_is_nothing_to_read(self):
        with pytest.raises(sp.BadWords):
            self.request(
                {"path": f"audio/{UID}/note-1.wav"},
                blob=FakeBlob(wav()),
                http=http_answering(transcript("")),
            )

    def test_the_callable_keeps_no_trace_of_the_words_in_its_logs(self, caplog):
        with caplog.at_level(logging.DEBUG):
            self.request({"text": "caminar por la rambla"})

        assert "rambla" not in caplog.text
