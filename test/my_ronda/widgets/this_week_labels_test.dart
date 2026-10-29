import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_ronda/widgets/this_week_labels.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

void main() {
  group('ThisWeekLabels', () {
    final es = lookupAppLocalizations(const Locale('es'));

    ThisWeek week({
      String day = 'sat',
      String band = 'afternoon',
      String pretext = 'mate',
      bool withView = true,
    }) {
      final base = MyRondaFixtures.week(withView: withView);
      return ThisWeek(
        rondaId: base.rondaId,
        pretextId: pretext,
        barrioId: base.barrioId,
        slotDayId: day,
        slotBandId: band,
        myBrings: base.myBrings,
        week: base.week,
        date: base.date,
      );
    }

    test('names each time band', () {
      expect(
        es.rondaLine(week(band: 'morning')),
        startsWith('Sábado 31/10 a la mañana'),
      );
      expect(
        es.rondaLine(week(band: 'evening')),
        startsWith('Sábado 31/10 a la noche'),
      );
    });

    test('keeps an unknown pretext id, and a date without a known slot', () {
      expect(es.rondaLine(week(pretext: 'bochas')), endsWith('· bochas'));
      expect(es.rondaLine(week(day: 'x')), '31/10 · Mate en la rambla');
      expect(
        es.rondaLine(week(day: 'x', withView: false)),
        'Mate en la rambla',
      );
    });

    test('names the first thing that can be carried', () {
      expect(
        es.bringItem(['tengo-ganas', 'enseno-truco', 'sillas']),
        'las sillas',
      );
      expect(es.bringItem(['yerba']), 'la yerba');
      expect(es.bringItem(['termo']), 'el termo');
      expect(es.bringItem(['nada']), isNull);
    });

    test('lists what a neighbour brings by its labels', () {
      expect(
        es.bringsDetail(['pan', 'enseno-truco', 'x']),
        'Pan · Enseño truco',
      );
    });
  });
}
