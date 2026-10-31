"""¿Dónde queda?'s fixed rules, with no Firestore: whose turn it is, which photo is refused and
why, which hint is held, and who came close (donde_queda.py). Every person and place is
invented."""

import io
from datetime import date

from PIL import Image, ImageDraw

import donde_queda as d
import mate_flyer

MEETING = date(2026, 11, 5)


def member(joined: str, state: str = "active", **fields) -> dict:
    return {"state": state, "joinedAt": joined, **fields}


def photo(size=(400, 300)) -> Image.Image:
    """An invented barrio photo: a green door in a brick wall, enough detail not to be empty."""
    image = Image.new("RGB", size, (170, 90, 60))
    draw = ImageDraw.Draw(image)
    for y in range(0, size[1], 12):
        draw.line((0, y, size[0], y), fill=(200, 200, 190), width=2)
    draw.rectangle((150, 60, 250, 290), fill=(30, 120, 60))
    return image


def mask(left, top, right, bottom) -> mate_flyer.Mask:
    return mate_flyer.Mask(left, top, right, bottom, 2, 2, bytes([1, 1, 1, 1]))


class TestWhoseTurn:
    def test_the_order_is_the_active_members_by_when_they_joined(self):
        members = {
            "b": member("2"),
            "a": member("1"),
            "left": member("0", "left"),
            "c": member("3"),
        }

        assert d.turn_order(members, MEETING) == ["a", "b", "c"]

    def test_a_member_paused_over_the_meeting_is_skipped_and_one_back_by_then_is_not(self):
        members = {
            "a": member("1"),
            "away": member("2", "paused", pausedUntil="2026-11-19"),
            "back": member("3", "paused", pausedUntil="2026-11-05"),
        }

        assert d.turn_order(members, MEETING) == ["a", "back"]

    def test_each_week_starts_one_after_the_last_weeks_first(self):
        order = ["a", "b", "c"]

        assert d.starter(order, None) == "a"
        assert d.starter(order, "a") == "b"
        assert d.starter(order, "c") == "a"

    def test_a_last_starter_who_left_starts_from_whoever_joined_after_them(self):
        order = ["a", "c"]

        assert d.starter(order, "gone", joined={"gone": "2", "a": "1", "c": "3"}) == "c"
        assert d.starter(order, "gone", joined={"gone": "9", "a": "1", "c": "3"}) == "a"
        assert d.starter([], "a") is None

    def test_esta_semana_no_passes_to_the_next_without_coming_back_round(self):
        order = ["a", "b", "c"]

        assert d.next_asked(order, "b", passed=["b"]) == "c"
        assert d.next_asked(order, "b", passed=["b", "c"]) == "a"
        assert d.next_asked(order, "b", passed=["b", "c", "a"]) is None

    def test_someone_who_left_mid_week_is_passed_over(self):
        assert d.next_asked(["a", "c"], "b", passed=["b"]) == "a"
        assert d.next_asked([], "b", passed=["b"]) is None


class TestRefusedPhotos:
    def test_a_photo_of_the_barrio_is_fine_and_blurs_nothing(self):
        verdict = d.judge(photo(), {})

        assert verdict == d.Verdict(None, [])

    def test_a_visible_house_number_is_refused(self):
        verdict = d.judge(photo(), {d.HOUSE_NUMBER: [mask(10, 10, 40, 30)]})

        assert verdict.refusal == d.HOUSE_NUMBER_REFUSED

    def test_a_person_as_the_subject_is_refused(self):
        verdict = d.judge(photo(), {d.PERSON: [mask(100, 0, 300, 300)]})

        assert verdict.refusal == d.PERSON_REFUSED

    def test_someone_passing_in_the_background_and_a_number_plate_are_blurred(self):
        passer_by = mask(10, 200, 40, 290)
        plate = mask(300, 260, 360, 280)

        verdict = d.judge(photo(), {d.PERSON: [passer_by], d.PLATE: [plate]})

        assert verdict == d.Verdict(None, [passer_by, plate])

    def test_a_blank_or_black_photo_is_empty(self):
        black = Image.new("RGB", (400, 300), (5, 5, 5))
        grey = Image.new("RGB", (400, 300), (128, 128, 128))

        assert d.judge(black, {}).refusal == d.EMPTY_REFUSED
        assert d.judge(grey, {}).refusal == d.EMPTY_REFUSED

    def test_the_house_number_wins_over_everything_else(self):
        black = Image.new("RGB", (400, 300), (5, 5, 5))

        verdict = d.judge(black, {d.HOUSE_NUMBER: [mask(1, 1, 5, 5)]})

        assert verdict.refusal == d.HOUSE_NUMBER_REFUSED

    def test_blurring_hides_whats_inside_the_box_and_leaves_the_rest(self):
        image = photo()
        before = image.copy()

        blurred = d.blur_boxes(image, [mask(140, 50, 260, 300)])

        inside = (140, 50, 260, 300)
        assert blurred.crop(inside).tobytes() != before.crop(inside).tobytes()
        assert blurred.getpixel((20, 20)) == before.getpixel((20, 20))
        assert d.blur_boxes(image, []) is image

    def test_a_box_outside_the_photo_is_clamped(self):
        blurred = d.blur_boxes(photo(), [mask(-50, -50, 2000, 2000)])

        assert blurred.size == (400, 300)
        beyond = photo()
        assert d.blur_boxes(beyond, [mask(500, 400, 600, 500)]).tobytes() == beyond.tobytes()

    def test_the_published_photo_is_a_jpeg_without_exif(self):
        out = d.encode(photo())

        with Image.open(io.BytesIO(out)) as image:
            assert image.format == "JPEG"
            assert not image.getexif()


class TestTheWords:
    def test_a_short_line_passes_the_gates(self):
        assert d.word_gates("la puerta verde de Gestido y Rivera") == ""

    def test_an_address_money_or_an_emoji_is_held(self):
        assert d.word_gates("Gestido 1234") != ""
        assert d.word_gates("en lo de Mirta") != ""
        assert d.word_gates("cuesta plata") != ""
        assert d.word_gates("la puerta \N{SMILING FACE WITH SMILING EYES}") != ""


class TestWhoCameClose:
    def test_counts_the_guesses_within_two_and_a_half_blocks(self):
        pin = {"lat": -34.8, "lng": -55.885}
        guesses = {
            "on-it": {"lat": -34.8, "lng": -55.885},
            "two-blocks": {"lat": -34.8018, "lng": -55.885},
            "far": {"lat": -34.81, "lng": -55.885},
        }

        assert d.came_close(pin, guesses) == (2, 3)
        assert d.came_close(pin, {}) == (0, 0)

    def test_the_area_is_the_barrio_around_its_centroid(self):
        centre = {"lat": -34.8, "lng": -55.885}

        assert d.within(centre, {"lat": -34.805, "lng": -55.89})
        assert not d.within(centre, {"lat": -34.83, "lng": -55.885})
        assert not d.within(centre, {"lat": "x", "lng": 1})
        assert not d.within(centre, None)
