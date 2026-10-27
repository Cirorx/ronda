import 'package:flutter_test/flutter_test.dart';
import 'package:profile_repository/profile_repository.dart';

void main() {
  group(Profile, () {
    Profile build({String firstName = 'Marta'}) => Profile(
      firstName: firstName,
      ageBand: AgeBand.sixties,
      barrio: Barrio.solymarNorte,
      pretexts: const {Pretext.mate},
      slots: {const Slot(SlotDay.thursday, SlotBand.afternoon)},
      brings: const {Bring.termo},
    );

    test('compares by value', () {
      expect(build(), equals(build()));
      expect(build(), isNot(equals(build(firstName: 'Julio'))));
    });
  });

  group(TermsAcceptance, () {
    test('compares by value', () {
      final at = DateTime(2026, 10, 27, 18, 30);
      expect(
        TermsAcceptance(version: '2026-10-27', acceptedAt: at),
        equals(TermsAcceptance(version: '2026-10-27', acceptedAt: at)),
      );
      expect(
        TermsAcceptance(version: '2026-10-27', acceptedAt: at),
        isNot(equals(TermsAcceptance(version: '2026-11-01', acceptedAt: at))),
      );
    });
  });
}
