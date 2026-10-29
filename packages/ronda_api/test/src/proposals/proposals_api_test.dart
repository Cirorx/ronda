import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';

class _MockFirebaseFunctions extends Mock implements FirebaseFunctions;

class _MockHttpsCallable extends Mock implements HttpsCallable;

class _MockHttpsCallableResult<T> extends Mock
    implements HttpsCallableResult<T>;

void main() {
  group(ProposalsApi, () {
    late FakeFirebaseFirestore firestore;
    late FirebaseFunctions functions;
    late HttpsCallable callable;
    late ProposalsApi subject;

    setUp(() {
      firestore = FakeFirebaseFirestore();
      functions = _MockFirebaseFunctions();
      callable = _MockHttpsCallable();
      when(() => functions.httpsCallable(any(), options: any(named: 'options')))
          .thenReturn(callable);
      subject = ProposalsApi(firestore: firestore, functions: functions);
    });

    Map<String, Object?> proposal(DateTime createdAt, {String reason = 'B'}) =>
        {
          'status': 'pending',
          'groups': [
            {
              'id': 'lagomar-sur_mate_sat-afternoon',
              'barrio': 'lagomar-sur',
              'pretext': 'mate',
              'slot': 'sat-afternoon',
              'members': [
                {
                  'uid': 'demo-001',
                  'firstName': 'Marta',
                  'ageBand': '60-69',
                  'distanceBlocks': 2,
                  'plusOneInGroup': true,
                },
              ],
            },
          ],
          'unseated': ['demo-009'],
          'rejectedAlternative': {'reason': reason, 'brokenRule': 'x'},
          'createdAt': Timestamp.fromDate(createdAt),
        };

    group('watchLatestProposal', () {
      test('emits null while there is no proposal', () {
        expect(subject.watchLatestProposal(), emits(isNull));
      });

      test('emits the newest proposal only', () async {
        final proposals = firestore.collection('proposals');
        await proposals.doc('old').set(proposal(DateTime(2026, 10, 27)));
        await proposals.doc('new').set(proposal(DateTime(2026, 10, 28)));

        final latest = await subject.watchLatestProposal().first;

        expect(latest?.id, 'new');
        expect(latest?.status, 'pending');
        expect(latest?.unseated, ['demo-009']);
        expect(latest?.rejectedReason, 'B');
        final group = latest!.groups.single;
        expect(group.seatId, 'lagomar-sur_mate_sat-afternoon');
        expect(group.barrio, 'lagomar-sur');
        expect(group.pretext, 'mate');
        expect(group.slot, 'sat-afternoon');
        final member = group.members.single;
        expect(member.uid, 'demo-001');
        expect(member.firstName, 'Marta');
        expect(member.ageBand, '60-69');
        expect(member.distanceBlocks, 2.0);
        expect(member.plusOneInGroup, isTrue);
      });
    });

    group('proposeGroups', () {
      test('calls propose_groups and returns the proposal id', () async {
        final result = _MockHttpsCallableResult<Map<Object?, Object?>>();
        when(() => result.data).thenReturn({'proposalId': 'p1', 'groups': 3});
        when(() => callable.call<Map<Object?, Object?>>())
            .thenAnswer((_) async => result);

        expect(await subject.proposeGroups(), 'p1');
        verify(() => functions.httpsCallable('propose_groups')).called(1);
      });

      test('throws a $FormatException when no id comes back', () async {
        final result = _MockHttpsCallableResult<Map<Object?, Object?>>();
        when(() => result.data).thenReturn({});
        when(() => callable.call<Map<Object?, Object?>>())
            .thenAnswer((_) async => result);

        expect(subject.proposeGroups(), throwsFormatException);
      });
    });

    group('approveProposal', () {
      test('calls approve_proposal with the id', () async {
        when(() => callable.call<Object?>(any<Object?>()))
            .thenAnswer((_) async => _MockHttpsCallableResult<Object?>());

        await subject.approveProposal('p1');

        verify(() => functions.httpsCallable('approve_proposal')).called(1);
        verify(() => callable.call<Object?>({'proposalId': 'p1'})).called(1);
      });
    });

    group('undoApproval', () {
      test('calls approve_proposal with undo', () async {
        when(() => callable.call<Object?>(any<Object?>()))
            .thenAnswer((_) async => _MockHttpsCallableResult<Object?>());

        await subject.undoApproval('p1');

        verify(() => callable.call<Object?>({'proposalId': 'p1', 'undo': true}))
            .called(1);
      });
    });
  });
}
