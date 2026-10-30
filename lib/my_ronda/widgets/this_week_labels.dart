import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/onboarding/widgets/onboarding_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';

/// How long a después lasts, as the card says it.
const despuesMinutes = 20;

/// The weekday id (`thu`) of [date], for [AppLocalizations.weekdayName].
String weekdayId(DateTime date) =>
    const ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'][date.weekday - 1];

/// The Mi ronda card's words for a [ThisWeek], in the app's language.
extension ThisWeekLabels on AppLocalizations {
  /// "31/10".
  String shortDate(DateTime date) =>
      thisWeekDate(date.day.toString(), date.month.toString());

  /// "Sábado 31/10 a las 16:00 · Mate en la rambla" once the admin set the
  /// hour, "Sábado 31/10 a la tarde · …" until then; without a date yet:
  /// "Sábado a la tarde · …". The place has a line of its own
  /// ([placeLine]).
  String rondaLine(ThisWeek week) => rondaLineOf(
    slotDayId: week.slotDayId,
    slotBandId: week.slotBandId,
    pretextId: week.pretextId,
    date: week.date,
    hour: week.hour,
  );

  /// Where the ronda meets, "Frente al quiosco · al lado de la parada", or
  /// what is still to confirm ("Lugar y hora a confirmar"): never invented.
  String placeLine(ThisWeek week) => switch ((week.placeName, week.hour)) {
    (null, null) => thisWeekToConfirmBoth,
    (null, _) => thisWeekToConfirmPlace,
    (final place?, final hour) => [
      switch (week.placeLandmark) {
        final landmark? => thisWeekPlaceLandmark(place, landmark),
        null => place,
      },
      if (hour == null) thisWeekToConfirmHour,
    ].join(' · '),
  };

  /// "Abre Mirta. Cierra Jorge.", or "Abrís vos: …" for the host reading
  /// it, and "Esta semana abre Facu." when someone took over opening this
  /// week ("¿Abrís vos?"); `null` while the ronda has no host.
  String? hostsLine(ThisWeek week, {required String uid}) {
    final parts = [
      if (week.opener case final host? when host.uid == uid)
        thisWeekOpenerYou
      else if (week.opener case final host?)
        thisWeekOpenerOpens(host.firstName)
      else if (week.anfitrion case final host? when host.uid == uid)
        thisWeekYouOpen
      else if (week.anfitrion case final host?)
        thisWeekHostOpens(host.firstName),
      if (week.cola case final host? when host.uid == uid)
        thisWeekYouClose
      else if (week.cola case final host?)
        thisWeekHostCloses(host.firstName),
    ];
    return parts.isEmpty ? null : parts.join(' ');
  }

  /// "Este mes abre Jorge y cierra Ana. Los próximos turnos: diciembre,
  /// abre Ana y cierra Facu; …": the monthly turns; `null` without them.
  String? turnsLine(ThisWeek week) {
    if (week.turns case [final now, ...final ahead]) {
      return [
        thisWeekMonthHosts(now.anfitrion.firstName, now.cola.firstName),
        if (ahead.isNotEmpty)
          thisWeekTurnsAhead(
            ahead
                .map(
                  (turn) => thisWeekTurn(
                    monthName('m${turn.month.month}'),
                    turn.anfitrion.firstName,
                    turn.cola.firstName,
                  ),
                )
                .join('; '),
          ),
      ].join(' ');
    }
    return null;
  }

  /// "Después, si querés: bizcochos en lo de Mirta, Av. Central 1234 (20
  /// min)": the week's después once it is set; `null` with none.
  String? despuesLine(Despues? despues) => switch (despues) {
    Despues(
      status: DespuesStatus.set,
      kind: DespuesKind.place,
      :final what?,
      :final where?,
    ) =>
      despuesLinePlace(what, where, despuesMinutes),
    Despues(
      status: DespuesStatus.set,
      kind: DespuesKind.home,
      :final what?,
      :final homeOf?,
      :final address?,
    ) =>
      despuesLineHome(what, homeOf.firstName, address, despuesMinutes),
    Despues(
      status: DespuesStatus.set,
      kind: DespuesKind.home,
      :final what?,
      :final homeOf?,
    ) =>
      despuesLineHomeNoAddress(what, homeOf.firstName, despuesMinutes),
    _ => null,
  };

  /// "Mirta no puede el jueves. ¿Abrís vos?": to the cola it names the
  /// anfitrión, to the others nobody.
  String handoffQuestion(HandoffAsk ask) {
    final day = weekdayName(weekdayId(ask.date));
    return switch ((ask.fromName, ask.reason)) {
      (final name?, HandoffReason.unanswered) => handoffUnanswered(name, day),
      (final name?, _) => handoffCantCome(name, day),
      (null, _) => handoffNobody(day),
    };
  }

  /// "Abrir es llegar diez minutos antes, a las 15:50, …": the time only
  /// when the ronda has an [hour].
  String openingWords(String? hour) {
    final parts = hour?.split(':').map(int.tryParse).toList();
    if (parts case [final int h, final int m]) {
      final early = h * 60 + m - 10;
      final time =
          '${(early ~/ 60).toString().padLeft(2, '0')}:'
          '${(early % 60).toString().padLeft(2, '0')}';
      return handoffOpeningAt(time);
    }
    return handoffOpening;
  }

  /// "Llega primero · Pan": a neighbour's role, when they have one, and
  /// what they bring.
  String roleAndBrings(ThisWeek week, GoingNeighbour person) => [
    if (week.anfitrion?.uid == person.uid) thisWeekRoleOpens,
    if (week.cola?.uid == person.uid) thisWeekRoleCloses,
    if (bringsDetail(person.brings) case final brings when brings.isNotEmpty)
      brings,
  ].join(' · ');

  /// A ronda's line from its ids: "Jueves a la tarde · Truco", with [date]
  /// after the day, [hour] ("a las 16:00") in place of the band, and
  /// [placeName] at the end when given.
  String rondaLineOf({
    required String slotDayId,
    required String slotBandId,
    required String pretextId,
    DateTime? date,
    String? hour,
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
      when = switch ((slot.band, hour)) {
        (_, final hour?) => slotAt(day, hour),
        (SlotBand.morning, _) => slotMorning(day),
        (SlotBand.afternoon, _) => slotAfternoon(day),
        (SlotBand.evening, _) => slotEvening(day),
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
