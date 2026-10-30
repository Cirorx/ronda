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

    test('says the hour in place of the band once set', () {
      expect(
        es.rondaLineOf(
          slotDayId: 'thu',
          slotBandId: 'evening',
          pretextId: 'truco',
          hour: '19:30',
          placeName: 'Club Lagomar',
        ),
        'Jueves a las 19:30 · Truco · Club Lagomar',
      );
    });

    test('a place without a landmark, and with no hour yet', () {
      expect(
        es.placeLine(
          MyRondaFixtures.week(placeName: 'La plaza', hour: '16:00'),
        ),
        'La plaza',
      );
      expect(
        es.placeLine(MyRondaFixtures.week(placeName: 'La plaza')),
        'La plaza · Hora a confirmar',
      );
    });

    test('names who opens and closes, and only their roles', () {
      final both = MyRondaFixtures.week(
        anfitrion: const Host(uid: 'demo-002', firstName: 'Raúl'),
        cola: const Host(uid: MyRondaFixtures.uid, firstName: 'Marta'),
      );
      expect(
        es.hostsLine(both, uid: MyRondaFixtures.uid),
        'Abre Raúl. Cerrás vos: te quedás hasta el final.',
      );
      expect(
        es.hostsLine(MyRondaFixtures.week(), uid: MyRondaFixtures.uid),
        isNull,
      );
      expect(
        es.roleAndBrings(
          both,
          const GoingNeighbour(uid: 'demo-002', firstName: 'Raúl', brings: []),
        ),
        'Llega primero',
      );
      expect(
        es.roleAndBrings(
          both,
          const GoingNeighbour(uid: 'demo-009', firstName: 'Ana', brings: []),
        ),
        '',
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
