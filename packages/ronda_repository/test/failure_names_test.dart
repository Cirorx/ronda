import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_repository/ronda_repository.dart';

void main() {
  group('failure names', () {
    test('read as their own name, whatever the build minifies', () {
      expect(const CercaFailure().toString(), equals('CercaFailure'));
      expect(
        const HostsFailure(HostsFailureReason.forbidden).toString(),
        equals('HostsFailure(forbidden)'),
      );
      expect(
        const ProposalsFailure(ProposalsFailureReason.forbidden).toString(),
        equals('ProposalsFailure(forbidden)'),
      );
      expect(
        const RsvpFailure(RsvpFailureReason.forbidden).toString(),
        equals('RsvpFailure(forbidden)'),
      );
      expect(
        const WelcomeFailure(WelcomeFailureReason.emoji).toString(),
        equals('WelcomeFailure(emoji)'),
      );
    });
  });
}
