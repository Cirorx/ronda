import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/widgets/onboarding_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';

/// The Mi ronda card's words for a [ThisWeek], in the app's language.
extension ThisWeekLabels on AppLocalizations {
  /// "31/10".
  String shortDate(DateTime date) =>
      thisWeekDate(date.day.toString(), date.month.toString());

  /// "Sábado 31/10 a la tarde · Mate en la rambla", and the place's name
  /// once a host set one. Without a date yet: "Sábado a la tarde · …".
  String rondaLine(ThisWeek week) => rondaLineOf(
    slotDayId: week.slotDayId,
    slotBandId: week.slotBandId,
    pretextId: week.pretextId,
    date: week.date,
    placeName: week.placeName,
  );

  /// A ronda's line from its ids: "Jueves a la tarde · Truco", with [date]
  /// after the day and [placeName] at the end when given.
  String rondaLineOf({
    required String slotDayId,
    required String slotBandId,
    required String pretextId,
    DateTime? date,
    String? placeName,
  }) {
    final slot = Slot.fromId('$slotDayId-$slotBandId');
    final pretextValue = Pretext.fromId(pretextId);
    final pretextLabel = pretextValue == null
        ? pretextId
        : pretext(pretextValue);
    final String when;
    if (slot == null) {
      when = date == null ? '' : shortDate(date);
    } else {
      final day = switch (date) {
        final date? => '${slotDay(slot.day)} ${shortDate(date)}',
        null => slotDay(slot.day),
      };
      when = switch (slot.band) {
        SlotBand.morning => slotMorning(day),
        SlotBand.afternoon => slotAfternoon(day),
        SlotBand.evening => slotEvening(day),
      };
    }
    final line = when.isEmpty ? pretextLabel : thisWeekLine(when, pretextLabel);
    return switch (placeName) {
      final place? => thisWeekLine(line, place),
      null => line,
    };
  }

  /// "el pan": the first thing the member brings that can be carried, or
  /// `null` ("Tengo ganas", "Enseño truco").
  String? bringItem(List<String> brings) {
    for (final id in brings) {
      final item = switch (Bring.fromId(id)) {
        Bring.pan => bringItemPan,
        Bring.yerba => bringItemYerba,
        Bring.termo => bringItemTermo,
        Bring.sillas => bringItemSillas,
        Bring.ensenoTruco || Bring.tengoGanas || null => null,
      };
      if (item != null) return item;
    }
    return null;
  }

  /// "Pan · Termo": what a neighbour brings, by its labels.
  String bringsDetail(List<String> brings) => [
    for (final id in brings)
      if (Bring.fromId(id) case final item?) bring(item),
  ].join(' · ');

  /// "Va 1 · 1 no puede · falta tu respuesta": counts, never names.
  String counts(ThisWeek week, {required bool answered}) {
    final unanswered = (week.unansweredCount ?? 0) - (answered ? 0 : 1);
    return [
      thisWeekGoingCount(week.going.length),
      if ((week.noCount ?? 0) > 0) thisWeekNoCount(week.noCount!),
      if (unanswered > 0) thisWeekUnansweredCount(unanswered),
      if (!answered) thisWeekYourAnswerMissing,
    ].join(' · ');
  }
}
