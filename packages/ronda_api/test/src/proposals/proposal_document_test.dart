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
        expect(document.unseatedPeople, isEmpty);
        expect(document.rondaIds, isEmpty);
      });

      test('reads a manual proposal as not auto, with no setup', () {
        final document = ProposalDocument.fromJson('p1', json());

        expect(document.auto, isFalse);
        expect(document.approveAt, isNull);
        expect(document.stopped, isFalse);
        expect(document.autoBlocked, isNull);
        expect(document.groups.single.setup, isNull);
      });

      test("reads an auto proposal, its hold and each group's setup", () {
        final [group] = json()['groups']! as List<Object?>;
        final document = ProposalDocument.fromJson('p1', {
          ...json(
            groups: [
              {
                ...group! as Map<String, Object?>,
                'setup': {
                  'placeId': 'plaza-inventada',
                  'place': {'name': 'la Plaza Inventada'},
                  'hour': '16:30',
                  'anfitrion': 'demo-001',
                  'cola': 'demo-002',
                  'anfitrionName': 'Marta',
                  'colaName': 'Jorge',
                  'reason': 'Queda cerca de todos.',
                  'by': 'agent',
                  'runId': 'auto_p1_1',
                },
              },
            ],
          ),
          'auto': true,
          'approveAt': Timestamp.fromDate(DateTime.utc(2026, 10, 27, 16)),
          'stoppedAt': Timestamp.fromDate(DateTime.utc(2026, 10, 27, 15, 30)),
          'autoBlocked': 'stopped',
        });

        expect(document.auto, isTrue);
        expect(document.approveAt?.toUtc(), DateTime.utc(2026, 10, 27, 16));
        expect(document.stopped, isTrue);
        expect(document.autoBlocked, 'stopped');
        final setup = document.groups.single.setup!;
        expect(setup.placeName, 'la Plaza Inventada');
        expect(setup.hour, '16:30');
        expect(setup.anfitrionName, 'Marta');
        expect(setup.colaName, 'Jorge');
        expect(setup.reason, 'Queda cerca de todos.');
        expect(setup.by, 'agent');
      });

      test('reads who is left out and the rondas it became', () {
        final document = ProposalDocument.fromJson('p1', {
          ...json(unseated: ['demo-009']),
          'unseatedPeople': [
            {
              'uid': 'demo-009',
              'firstName': 'Eva',
              'barrio': 'el-pinar-norte',
              'slots': ['sat-afternoon', 'tue-evening'],
              'pretexts': ['mate'],
            },
          ],
          'rondaIds': ['r1'],
        });

        final person = document.unseatedPeople.single;
        expect(person.uid, 'demo-009');
        expect(person.firstName, 'Eva');
        expect(person.barrio, 'el-pinar-norte');
        expect(person.slots, ['sat-afternoon', 'tue-evening']);
        expect(person.pretexts, ['mate']);
        expect(document.rondaIds, ['r1']);
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
        'unseated people that are not a list': {
          ...json(),
          'unseatedPeople': 'Eva',
        },
        'an unseated person of another shape': {
          ...json(),
          'unseatedPeople': [<String, Object?>{}],
        },
        'an unseated person with a slot that is not an id': {
          ...json(),
          'unseatedPeople': [
            {
              'uid': 'u',
              'firstName': 'Eva',
              'barrio': 'b',
              'slots': [1],
              'pretexts': <Object?>[],
            },
          ],
        },
        'a ronda id that is not a string': {
          ...json(),
          'rondaIds': [1],
        },
        'an auto flag that is not a bool': {...json(), 'auto': 'yes'},
        'an approval time that is not a timestamp': {
          ...json(),
          'approveAt': '16:00',
        },
        'a blocker that is not a string': {...json(), 'autoBlocked': 1},
        'a setup of another shape': json(
          groups: [
            {
              'id': 's',
              'barrio': 'b',
              'pretext': 'p',
              'slot': 'sat-afternoon',
              'members': <Object?>[],
              'setup': {'hour': '16:00'},
            },
          ],
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
