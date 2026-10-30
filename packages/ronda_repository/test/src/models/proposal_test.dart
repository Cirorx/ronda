import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_repository/ronda_repository.dart';

void main() {
  ProposedMember member(String ageBand, double blocks) => ProposedMember(
    uid: 'demo-$ageBand',
    firstName: 'Vecina',
    ageBandId: ageBand,
    distanceBlocks: blocks,
  );

  ProposedRonda ronda(List<ProposedMember> members) => ProposedRonda(
    seatId: 'lagomar-sur_mate_sat-afternoon',
    barrioId: 'lagomar-sur',
    pretextId: 'mate',
    slotId: 'sat-afternoon',
    members: members,
  );

  group(ProposedRonda, () {
    group('allWithinTenBlocks', () {
      test('is true when nobody walks more than ten blocks', () {
        expect(
          ronda([member('60-69', 0), member('30-39', 10)]).allWithinTenBlocks,
          isTrue,
        );
      });

      test('is false when someone walks further', () {
        expect(ronda([member('60-69', 10.5)]).allWithinTenBlocks, isFalse);
      });
    });

    group('ageChecks', () {
      test('checks every age group the solver compares, in order', () {
        final members = [
          for (final band in ['18-29', '50-59', '60-69', '70-79', '80+', '?'])
            member(band, 1),
        ];

        final checks = ronda(members).ageChecks;

        expect([for (final c in checks) c.group], AgeGroup.values);
        expect([for (final c in checks) c.count], [1, 1, 3]);
        expect([for (final c in checks) c.kept], [false, false, true]);
      });

      test('keeps a group nobody is in', () {
        final checks = ronda([member('30-39', 1), member('40-49', 1)])
            .ageChecks;

        expect(
          checks.first,
          const AgeGroupCheck(group: AgeGroup.under30, firstNames: []),
        );
        expect(checks.first.kept, isTrue);
        expect(checks[1].firstNames, ['Vecina', 'Vecina']);
      });
    });
  });

  group(ProposalsFailure, () {
    test('carries its reason', () {
      expect(
        const ProposalsFailure(ProposalsFailureReason.forbidden).reason,
        ProposalsFailureReason.forbidden,
      );
    });
  });
}
