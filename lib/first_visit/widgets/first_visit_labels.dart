import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';

/// "15:50": ten minutes before [hour] (`16:00`), when the waiter (and
/// whoever opens) arrives; `null` without an hour.
String? arrivalTime(String? hour) {
  final parts = hour?.split(':').map(int.tryParse).toList();
  if (parts case [final int h, final int m]) {
    final early = h * 60 + m - 10;
    return '${(early ~/ 60).toString().padLeft(2, '0')}:'
        '${(early % 60).toString().padLeft(2, '0')}';
  }
  return null;
}

/// Así va a ser's words for a [Welcome], in the app's language.
extension FirstVisitLabels on AppLocalizations {
  /// "Te espera Jorge — tiene el termo verde.", or without a sign "Te
  /// espera Jorge."; `null` while nobody waits.
  String? waiterLine(String? waiterName, String? sign) =>
      switch ((waiterName, sign?.trim())) {
        (null, _) => null,
        (final name?, final sign?) when sign.isNotEmpty => firstVisitWaiterSign(
          name,
          sign,
        ),
        (final name?, _) => firstVisitWaiter(name),
      };

  /// "Nico viene por primera vez el jueves. ¿Quién espera a Nico en frente
  /// al quiosco a las 15:50?", with only what the ronda knows.
  String welcomeQuestion(Welcome welcome) {
    final name = welcome.newcomerName;
    final day = weekdayName(weekdayId(welcome.date));
    return switch ((welcome.placeName, arrivalTime(welcome.hour))) {
      (final place?, final time?) => welcomeAskQuestion(name, day, place, time),
      (final place?, null) => welcomeAskQuestionPlace(name, day, place),
      (null, final time?) => welcomeAskQuestionTime(name, day, time),
      (null, null) => welcomeAskQuestionBare(name, day),
    };
  }

  /// Who waits for [welcome]'s newcomer as the host [uid] reads it: the
  /// pick, or who waits while nobody picked, and who last couldn't.
  String welcomeWaiterLine(Welcome welcome, {required String uid}) {
    final waiter = welcome.waiter;
    final line = switch (waiter) {
      null => welcomeAskNobody,
      Host(uid: final id) when welcome.picked && id == uid =>
        welcomeAskPickedYou,
      Host(:final firstName) when welcome.picked => welcomeAskPicked(firstName),
      Host(uid: final id) when id == uid => welcomeAskDefaultYou,
      Host(:final firstName) => welcomeAskDefault(firstName),
    };
    return switch (welcome.declinedName) {
      final name? => '${welcomeAskDeclined(name)} $line',
      null => line,
    };
  }

  /// Why a pick or a "No puedo" wasn't saved.
  String welcomeFailure(WelcomeFailureReason reason) => switch (reason) {
    WelcomeFailureReason.emoji => welcomeHeldEmoji,
    WelcomeFailureReason.voseo => welcomeHeldVoseo,
    WelcomeFailureReason.money => welcomeHeldMoney,
    WelcomeFailureReason.notPublic => welcomeHeldNotPublic,
    WelcomeFailureReason.passed => welcomePassed,
    WelcomeFailureReason.other => welcomeSaveError,
  };
}
