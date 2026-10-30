import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';

const _weekdays = ['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun'];

/// The words of the bench's offer and the waiting-list card.
extension BenchLabels on AppLocalizations {
  /// "domingo 1/11": the weekday and the short date, for a sentence.
  String dayDate(DateTime date) =>
      dayWithDate(_weekdays[date.weekday - 1], shortDate(date));

  /// "17:00", in this device's time.
  String clock(DateTime at) {
    final local = at.toLocal();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(local.hour)}:${two(local.minute)}';
  }

  /// "Jueves 5/11 a las 16:00 · Mate en la rambla · frente al quiosco".
  String offerLine(BenchOffer offer) => rondaLineOf(
    slotDayId: offer.slotDayId,
    slotBandId: offer.slotBandId,
    pretextId: offer.pretextId,
    date: offer.date,
    hour: offer.hour,
    placeName: offer.placeName,
  );

  /// "Tenés hasta el miércoles 4/11 a las 12:00."
  String offerDeadline(BenchOffer offer) => benchOfferDeadline(
    dayDate(offer.deadline.toLocal()),
    clock(offer.deadline),
  );

  /// "Sábado a la tarde · Mate en la rambla": what the list is for.
  String waitingLine(Waiting waiting) => rondaLineOf(
    slotDayId: waiting.slotDayId,
    slotBandId: waiting.slotBandId,
    pretextId: waiting.pretextId,
  );
}
