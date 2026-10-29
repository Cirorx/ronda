import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_api/ronda_api.dart';

void main() {
  group(ProposalDocument, () {
    Map<String, Object?> member({Object? plusOneInGroup}) => {
      'uid': 'demo-001',
      'firstName': 'Marta',
      'ageBand': '60-69',
      'distanceBlocks': 2.5,
      'plusOneInGroup': ?plusOneInGroup,
    };

    Map<String, Object?> json({
      Object? alternative,
      List<Object?>? members,
      List<Object?> unseated = const [],
      List<Object?>? groups,
    }) => {
      'status': 'pending',
      'groups':
          groups ??
          [
            {
              'id': 'lagomar-sur_mate_sat-afternoon',
              'barrio': 'lagomar-sur',
              'pretext': 'mate',
              'slot': 'sat-afternoon',
              'members': members ?? [member()],
            },
          ],
      'unseated': unseated,
      'rejectedAlternative': alternative,
      'createdAt': Timestamp.fromDate(DateTime.utc(2026, 10, 27, 15)),
    };

    group('fromJson', () {
      test('reads a proposal with no alternative', () {
        final document = ProposalDocument.fromJson('p1', json());

        expect(document.rejectedReason, isNull);
        expect(document.createdAt.toUtc(), DateTime.utc(2026, 10, 27, 15));
        expect(document.groups.single.members.single.plusOneInGroup, isNull);
        expect(document.groups.single.members.single.distanceBlocks, 2.5);
      });

      test('reads whether a +1 is in the same group', () {
        final document = ProposalDocument.fromJson(
          'p1',
          json(members: [member(plusOneInGroup: false)]),
        );

        expect(document.groups.single.members.single.plusOneInGroup, isFalse);
      });

      final malformed = <String, Map<String, Object?>>{
        'a missing field': {'status': 'pending'},
        'an alternative without a reason': json(alternative: {'x': 1}),
        'an unseated entry that is not a uid': json(unseated: [1]),
        'a group of another shape': json(groups: [<String, Object?>{}]),
        'a member of another shape': json(members: [<String, Object?>{}]),
        'a +1 flag that is not a bool': json(
          members: [member(plusOneInGroup: 'yes')],
        ),
      };
      for (final MapEntry(key: name, value: data) in malformed.entries) {
        test('throws a $FormatException for $name', () {
          expect(
            () => ProposalDocument.fromJson('p1', data),
            throwsFormatException,
          );
        });
      }
    });
  });
}
