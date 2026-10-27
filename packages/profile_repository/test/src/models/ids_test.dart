import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  group(AgeBand, () {
    test('uses the decade ids the solver reads', () {
      expect(
        AgeBand.values.map((band) => band.id),
        equals(['18-29', '30-39', '40-49', '50-59', '60-69', '70-79', '80+']),
      );
    });

    test('fromId reads every id back and returns null for unknown ones', () {
      for (final band in AgeBand.values) {
        expect(AgeBand.fromId(band.id), equals(band));
      }
      expect(AgeBand.fromId('65'), isNull);
      expect(AgeBand.fromId(null), isNull);
    });
  });

  group(Barrio, () {
    test('uses the solver fixture ids, none with an underscore', () {
      expect(
        Barrio.values.map((barrio) => barrio.id),
        equals([
          'shangrila',
          'san-jose-de-carrasco',
          'lagomar-sur',
          'lagomar-norte',
          'solymar-sur',
          'solymar-norte',
          'lomas-de-solymar',
          'el-pinar-sur',
          'el-pinar-norte',
        ]),
      );
      expect(Barrio.values.where((barrio) => barrio.id.contains('_')), isEmpty);
    });

    test('fromId reads every id back and returns null for unknown ones', () {
      for (final barrio in Barrio.values) {
        expect(Barrio.fromId(barrio.id), equals(barrio));
      }
      expect(Barrio.fromId('pocitos'), isNull);
      expect(Barrio.fromId(null), isNull);
    });
  });

  group(Pretext, () {
    test('uses the solver ids', () {
      expect(
        Pretext.values.map((pretext) => pretext.id),
        equals(['mate', 'truco', 'futbol5', 'caminata']),
      );
    });

    test('fromId reads every id back and returns null for unknown ones', () {
      for (final pretext in Pretext.values) {
        expect(Pretext.fromId(pretext.id), equals(pretext));
      }
      expect(Pretext.fromId('ajedrez'), isNull);
    });
  });

  group(Bring, () {
    test('uses kebab-case ids', () {
      expect(
        Bring.values.map((bring) => bring.id),
        equals([
          'pan',
          'yerba',
          'termo',
          'sillas',
          'enseno-truco',
          'tengo-ganas',
        ]),
      );
    });

    test('fromId reads every id back and returns null for unknown ones', () {
      for (final bring in Bring.values) {
        expect(Bring.fromId(bring.id), equals(bring));
      }
      expect(Bring.fromId('plata'), isNull);
    });
  });

  group(Slot, () {
    test('id joins the day and band ids with a hyphen', () {
      expect(
        const Slot(SlotDay.saturday, SlotBand.afternoon).id,
        equals('sat-afternoon'),
      );
      expect(
        const Slot(SlotDay.thursday, SlotBand.evening).id,
        equals('thu-evening'),
      );
    });

    test('covers seven days of three bands with distinct ids', () {
      expect(
        SlotDay.values.map((day) => day.id),
        equals(['mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun']),
      );
      expect(
        SlotBand.values.map((band) => band.id),
        equals(['morning', 'afternoon', 'evening']),
      );
    });

    test('fromId reads every id back and returns null for unknown ones', () {
      for (final day in SlotDay.values) {
        for (final band in SlotBand.values) {
          final slot = Slot(day, band);
          expect(Slot.fromId(slot.id), equals(slot));
        }
      }
      expect(Slot.fromId('sat_afternoon'), isNull);
      expect(Slot.fromId('sat-night'), isNull);
    });
  });
}
