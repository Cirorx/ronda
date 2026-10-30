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

    group('the weekly loop', () {
      final en = lookupAppLocalizations(const Locale('en'));

      test('whoever took over opening this week replaces the anfitrión', () {
        final taken = MyRondaFixtures.week(
          anfitrion: MyRondaFixtures.mirta,
          cola: MyRondaFixtures.jorge,
          opener: const Host(uid: 'demo-104', firstName: 'Facu'),
        );
        final mine = MyRondaFixtures.week(opener: MyRondaFixtures.me);

        expect(
          es.hostsLine(taken, uid: MyRondaFixtures.uid),
          'Esta semana abre Facu. Cierra Jorge.',
        );
        expect(
          es.hostsLine(mine, uid: MyRondaFixtures.uid),
          startsWith('Esta semana abrís vos: llegás diez minutos antes'),
        );
      });

      test('the monthly turns name this month and the months ahead', () {
        HostTurn turn(int month, Host anfitrion, Host cola) => HostTurn(
          month: DateTime(2026, month),
          anfitrion: anfitrion,
          cola: cola,
        );
        const ana = Host(uid: 'demo-103', firstName: 'Ana');
        final turns = MyRondaFixtures.week(
          turns: [
            turn(11, MyRondaFixtures.jorge, ana),
            turn(12, ana, MyRondaFixtures.mirta),
          ],
        );

        expect(
          es.turnsLine(turns),
          'Este mes abre Jorge y cierra Ana. Los próximos turnos: diciembre, '
          'abre Ana y cierra Mirta.',
        );
        expect(
          en.turnsLine(turns),
          'This month Jorge opens and Ana closes. Next turns: December, Ana '
          'opens and Mirta closes.',
        );
        expect(
          es.turnsLine(
            MyRondaFixtures.week(turns: [turn(11, MyRondaFixtures.jorge, ana)]),
          ),
          'Este mes abre Jorge y cierra Ana.',
        );
        expect(es.turnsLine(MyRondaFixtures.week()), isNull);
      });

      test(
        'the después reads once it is set, with the address while it lasts',
        () {
          expect(
            es.despuesLine(MyRondaFixtures.homeDespues),
            'Después, si querés: bizcochos en lo de Mirta, Av. Central 1234 '
            '(20 min)',
          );
          expect(
            es.despuesLine(
              const Despues(
                kind: DespuesKind.home,
                status: DespuesStatus.set,
                setBy: MyRondaFixtures.mirta,
                what: 'bizcochos',
                homeOf: MyRondaFixtures.mirta,
              ),
            ),
            'Después, si querés: bizcochos en lo de Mirta (20 min)',
          );
          expect(
            es.despuesLine(
              const Despues(
                kind: DespuesKind.place,
                status: DespuesStatus.set,
                setBy: MyRondaFixtures.mirta,
                what: 'bizcochos',
                where: 'el café de la esquina',
              ),
            ),
            'Después, si querés: bizcochos en el café de la esquina (20 min)',
          );
          expect(
            es.despuesLine(
              const Despues(
                kind: DespuesKind.home,
                status: DespuesStatus.asking,
                setBy: MyRondaFixtures.mirta,
                what: 'bizcochos',
                homeOf: MyRondaFixtures.jorge,
              ),
            ),
            isNull,
          );
          expect(es.despuesLine(null), isNull);
        },
      );

      test('"¿Abrís vos?" names the anfitrión to the cola only', () {
        final ask = MyRondaFixtures.handoffAsk;

        expect(
          es.handoffQuestion(ask),
          'Mirta no puede el sábado. ¿Abrís vos?',
        );
        expect(
          es.handoffQuestion(
            HandoffAsk(
              week: ask.week,
              date: ask.date,
              fromName: 'Mirta',
              reason: HandoffReason.unanswered,
            ),
          ),
          'Mirta no confirmó que viene el sábado. ¿Abrís vos?',
        );
        expect(
          es.handoffQuestion(HandoffAsk(week: ask.week, date: ask.date)),
          'Todavía nadie abre el sábado. ¿Abrís vos?',
        );
      });

      test('opening is ten minutes before the hour, when there is one', () {
        expect(es.openingWords('16:00'), contains('a las 15:50'));
        expect(es.openingWords('09:05'), contains('a las 08:55'));
        expect(
          es.openingWords(null),
          'Abrir es llegar diez minutos antes y saludar a los que van '
          'llegando. Nada más.',
        );
        expect(es.openingWords('soon'), es.openingWords(null));
      });

      test('names every weekday and month', () {
        expect(
          [
            for (var day = 26; day <= 32; day++)
              es.weekdayName(weekdayId(DateTime(2026, 10, day))),
          ],
          [
            'lunes',
            'martes',
            'miércoles',
            'jueves',
            'viernes',
            'sábado',
            'domingo',
          ],
        );
        expect(es.monthName('m1'), 'enero');
        expect(es.monthName('m13'), '');
      });
    });
  });
}
