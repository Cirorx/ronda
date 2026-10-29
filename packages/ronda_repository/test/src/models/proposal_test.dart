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

    group('sixtyPlusCount', () {
      test('counts the 60-69, 70-79 and 80+ bands', () {
        final members = [
          for (final band in ['18-29', '50-59', '60-69', '70-79', '80+'])
            member(band, 1),
        ];

        expect(ronda(members).sixtyPlusCount, 3);
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
