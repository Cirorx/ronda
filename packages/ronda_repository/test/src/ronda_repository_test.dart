import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockProposalsApi extends Mock implements ProposalsApi;

void main() {
  group(RondaRepository, () {
    late ProposalsApi proposalsApi;
    late RondaRepository subject;

    setUp(() {
      proposalsApi = _MockProposalsApi();
      subject = RondaRepository(proposalsApi: proposalsApi);
    });

    final createdAt = DateTime.utc(2026, 10, 27, 15);

    ProposalDocument document({String status = 'pending'}) => ProposalDocument(
      id: 'p1',
      status: status,
      groups: const [
        ProposedGroupDocument(
          seatId: 'lagomar-sur_mate_sat-afternoon',
          barrio: 'lagomar-sur',
          pretext: 'mate',
          slot: 'sat-afternoon',
          members: [
            ProposedMemberDocument(
              uid: 'demo-001',
              firstName: 'Marta',
              ageBand: '60-69',
              distanceBlocks: 2,
              plusOneInGroup: true,
            ),
          ],
        ),
      ],
      unseated: const ['demo-009', 'demo-010'],
      createdAt: createdAt,
      rejectedReason: 'Alternativa B rechazada: hace caminar 18 cuadras más.',
    );

    Matcher failsWith(ProposalsFailureReason reason) => throwsA(
      isA<ProposalsFailure>().having((f) => f.reason, 'reason', reason),
    );

    group('watchLatestProposal', () {
      test('emits the newest proposal as a $Proposal', () {
        when(proposalsApi.watchLatestProposal)
            .thenAnswer((_) => Stream.value(document()));

        expect(
          subject.watchLatestProposal(),
          emits(
            Proposal(
              id: 'p1',
              status: ProposalStatus.pending,
              rondas: const [
                ProposedRonda(
                  seatId: 'lagomar-sur_mate_sat-afternoon',
                  barrioId: 'lagomar-sur',
                  pretextId: 'mate',
                  slotId: 'sat-afternoon',
                  members: [
                    ProposedMember(
                      uid: 'demo-001',
                      firstName: 'Marta',
                      ageBandId: '60-69',
                      distanceBlocks: 2,
                      plusOneInGroup: true,
                    ),
                  ],
                ),
              ],
              unseatedCount: 2,
              createdAt: createdAt,
              rejectedReason:
                  'Alternativa B rechazada: hace caminar 18 cuadras más.',
            ),
          ),
        );
      });

      test('reads an approved proposal as approved', () {
        when(proposalsApi.watchLatestProposal)
            .thenAnswer((_) => Stream.value(document(status: 'approved')));

        expect(
          subject.watchLatestProposal().map((p) => p?.status),
          emits(ProposalStatus.approved),
        );
      });

      test('emits null while there is none', () {
        when(proposalsApi.watchLatestProposal)
            .thenAnswer((_) => Stream.value(null));

        expect(subject.watchLatestProposal(), emits(isNull));
      });

      test('errors as forbidden when the rules refuse the read', () {
        when(proposalsApi.watchLatestProposal).thenAnswer(
          (_) => Stream.error(
            FirebaseException(plugin: 'firestore', code: 'permission-denied'),
          ),
        );

        expect(
          subject.watchLatestProposal(),
          emitsError(
            isA<ProposalsFailure>().having(
              (f) => f.reason,
              'reason',
              ProposalsFailureReason.forbidden,
            ),
          ),
        );
      });

      test('errors as other for a document of another shape', () {
        when(proposalsApi.watchLatestProposal)
            .thenAnswer((_) => Stream.error(const FormatException('shape')));

        expect(
          subject.watchLatestProposal(),
          emitsError(
            isA<ProposalsFailure>().having(
              (f) => f.reason,
              'reason',
              ProposalsFailureReason.other,
            ),
          ),
        );
      });
    });

    group('proposeGroups', () {
      test('returns the new proposal id', () async {
        when(proposalsApi.proposeGroups).thenAnswer((_) async => 'p2');

        expect(await subject.proposeGroups(), 'p2');
      });

      test('throws forbidden without the admin claim', () {
        when(proposalsApi.proposeGroups).thenThrow(
          FirebaseFunctionsException(
            code: 'permission-denied',
            message: 'admins only',
          ),
        );

        expect(
          subject.proposeGroups,
          failsWith(ProposalsFailureReason.forbidden),
        );
      });

      test('throws forbidden when signed out', () {
        when(proposalsApi.proposeGroups).thenThrow(
          FirebaseFunctionsException(code: 'unauthenticated', message: ''),
        );

        expect(
          subject.proposeGroups,
          failsWith(ProposalsFailureReason.forbidden),
        );
      });

      test('throws other when the server fails', () {
        when(
          proposalsApi.proposeGroups,
        ).thenThrow(FirebaseFunctionsException(code: 'internal', message: ''));

        expect(subject.proposeGroups, failsWith(ProposalsFailureReason.other));
      });
    });

    group('approveProposal', () {
      test('approves the proposal', () async {
        when(() => proposalsApi.approveProposal('p1')).thenAnswer((_) async {});

        await subject.approveProposal('p1');

        verify(() => proposalsApi.approveProposal('p1')).called(1);
      });

      test('throws other when it was already approved', () {
        when(() => proposalsApi.approveProposal('p1')).thenThrow(
          FirebaseFunctionsException(code: 'failed-precondition', message: ''),
        );

        expect(
          () => subject.approveProposal('p1'),
          failsWith(ProposalsFailureReason.other),
        );
      });
    });

    group('undoApproval', () {
      test('takes the approval back', () async {
        when(() => proposalsApi.undoApproval('p1')).thenAnswer((_) async {});

        await subject.undoApproval('p1');

        verify(() => proposalsApi.undoApproval('p1')).called(1);
      });
    });
  });
}
