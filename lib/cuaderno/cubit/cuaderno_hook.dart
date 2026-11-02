/// The question that heads Mi ronda's way in to the cuaderno: what to
/// write there, and what for (`docs/PRODUCT.md` § El cuaderno del barrio).
/// It turns with the day of the week, so a day always asks the same thing.
enum CardHook {
  sunset,
  bizcochos,
  postcard,
  corner,
  learned,
  talk,
  bring;

  /// The hook for [day]: Monday the first, Sunday the last.
  static CardHook on(DateTime day) => values[day.weekday - 1];
}

/// The question over today's line inside the cuaderno, the prompt for the
/// next entry. The day after a meeting (and the one after that) it asks
/// about the meeting; a week with [postcardLines] lines or more and a ronda
/// to meet asks for one more for the postcard; any other day it turns with
/// the day of the week through [rotation].
enum EntryHook {
  afterMeeting,
  postcard,
  rambla,
  corner,
  learned,
  bizcochos,
  bring;

  /// The hooks a plain day turns through, Monday first.
  static const List<EntryHook> rotation = [
    rambla,
    corner,
    learned,
    bizcochos,
    bring,
  ];

  /// The week's lines from which the postcard hook is asked.
  static const postcardLines = 3;

  /// The hook for [today], a date at midnight, given the ronda's next
  /// meeting ([meetingDate], `null` with no ronda) and how many lines the
  /// last seven days hold.
  static EntryHook pick({
    required DateTime today,
    required DateTime? meetingDate,
    required int weekLines,
  }) {
    if (meetingDate != null) {
      // Rondas meet weekly: an upcoming meeting puts the last one a week
      // before it.
      final last = meetingDate.isAfter(today)
          ? DateTime(meetingDate.year, meetingDate.month, meetingDate.day - 7)
          : meetingDate;
      final since = _day(today).difference(_day(last)).inDays;
      if (since == 1 || since == 2) return afterMeeting;
      if (weekLines >= postcardLines) return postcard;
    }
    return rotation[(today.weekday - 1) % rotation.length];
  }

  // Days counted in UTC, so a clock change doesn't shorten one.
  static DateTime _day(DateTime date) =>
      DateTime.utc(date.year, date.month, date.day);
}
