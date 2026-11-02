import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/first_visit/widgets/first_visit_labels.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

void main() {
  group('arrivalTime', () {
    test('is ten minutes before the hour', () {
      expect(arrivalTime('16:00'), '15:50');
      expect(arrivalTime('09:05'), '08:55');
    });

    test('is null without an hour', () {
      expect(arrivalTime(null), isNull);
      expect(arrivalTime('soon'), isNull);
    });
  });

  group('FirstVisitLabels', () {
    final l10n = lookupAppLocalizations(const Locale('es'));

    test('waiterLine drops an empty sign and nobody', () {
      expect(l10n.waiterLine('Jorge', '  '), 'Te espera Jorge.');
      expect(l10n.waiterLine('Jorge', null), 'Te espera Jorge.');
      expect(l10n.waiterLine(null, 'tiene el termo verde'), isNull);
    });

    test('welcomeQuestion says only what the ronda knows', () {
      final open = FirstVisitFixtures.open;
      Welcome without({bool place = false, bool hour = false}) => Welcome(
        rondaId: open.rondaId,
        newcomerUid: open.newcomerUid,
        newcomerName: open.newcomerName,
        week: open.week,
        date: open.date,
        placeName: place ? open.placeName : null,
        hour: hour ? open.hour : null,
      );

      expect(
        l10n.welcomeQuestion(without(hour: true)),
        'Nico viene por primera vez el jueves. ¿Quién espera a Nico a las '
        '15:50?',
      );
      expect(
        l10n.welcomeQuestion(without()),
        'Nico viene por primera vez el jueves. ¿Quién espera a Nico?',
      );
    });
  });
}
