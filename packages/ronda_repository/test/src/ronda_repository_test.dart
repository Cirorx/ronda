import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda_api/ronda_api.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockProposalsApi extends Mock implements ProposalsApi;

class _MockRondasApi extends Mock implements RondasApi;

void main() {
  group(RondaRepository, () {
    late ProposalsApi proposalsApi;
    late RondasApi rondasApi;
    late RondaRepository subject;

    setUp(() {
      proposalsApi = _MockProposalsApi();
      rondasApi = _MockRondasApi();
      subject = RondaRepository(
        proposalsApi: proposalsApi,
        rondasApi: rondasApi,
      );
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

      test('names who is left out and the ronda each group became', () {
        final approved = document(status: 'approved');
        when(proposalsApi.watchLatestProposal).thenAnswer(
          (_) => Stream.value(
            ProposalDocument(
              id: approved.id,
              status: approved.status,
              groups: approved.groups,
              unseated: approved.unseated,
              createdAt: createdAt,
              rondaIds: const ['r1'],
              unseatedPeople: const [
                UnseatedPersonDocument(
                  uid: 'demo-009',
                  firstName: 'Eva',
                  barrio: 'el-pinar-norte',
                  slots: ['sat-afternoon'],
                  pretexts: ['mate'],
                ),
              ],
            ),
          ),
        );

        expect(
          subject.watchLatestProposal(),
          emits(
            isA<Proposal>()
                .having((p) => p.rondas.single.rondaId, 'rondaId', 'r1')
                .having((p) => p.unseated, 'unseated', const [
                  UnseatedPerson(
                    uid: 'demo-009',
                    firstName: 'Eva',
                    barrioId: 'el-pinar-norte',
                    slotIds: ['sat-afternoon'],
                    pretextIds: ['mate'],
                  ),
                ]),
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

      test('reads a superseded proposal as superseded', () {
        when(proposalsApi.watchLatestProposal)
            .thenAnswer((_) => Stream.value(document(status: 'superseded')));

        expect(
          subject.watchLatestProposal().map((p) => p?.status),
          emits(ProposalStatus.superseded),
        );
      });

      test('reads a manual proposal as one that never approves itself', () {
        when(proposalsApi.watchLatestProposal)
            .thenAnswer((_) => Stream.value(document()));

        expect(
          subject.watchLatestProposal(),
          emits(
            isA<Proposal>()
                .having((p) => p.auto, 'auto', isFalse)
                .having((p) => p.approvesItself, 'approvesItself', isFalse)
                .having((p) => p.rondas.single.setup, 'setup', isNull),
          ),
        );
      });

      test('reads an auto proposal with its hold and setup', () {
        final approveAt = DateTime.utc(2026, 10, 27, 16);
        final base = document();
        when(proposalsApi.watchLatestProposal).thenAnswer(
          (_) => Stream.value(
            ProposalDocument(
              id: base.id,
              status: base.status,
              unseated: base.unseated,
              createdAt: base.createdAt,
              auto: true,
              approveAt: approveAt,
              groups: [
                ProposedGroupDocument(
                  seatId: 's',
                  barrio: 'lagomar-sur',
                  pretext: 'mate',
                  slot: 'sat-afternoon',
                  members: base.groups.single.members,
                  setup: const ProposedSetupDocument(
                    placeName: 'la Plaza Inventada',
                    hour: '16:30',
                    anfitrionName: 'Marta',
                    colaName: 'Jorge',
                    reason: 'Queda cerca.',
                    by: 'agent',
                  ),
                ),
              ],
            ),
          ),
        );

        expect(
          subject.watchLatestProposal(),
          emits(
            isA<Proposal>()
                .having((p) => p.approveAt, 'approveAt', approveAt)
                .having((p) => p.approvesItself, 'approvesItself', isTrue)
                .having(
                  (p) => p.rondas.single.setup,
                  'setup',
                  const ProposedSetup(
                    placeName: 'la Plaza Inventada',
                    hour: '16:30',
                    anfitrionName: 'Marta',
                    colaName: 'Jorge',
                    reason: 'Queda cerca.',
                    byAgent: true,
                  ),
                ),
          ),
        );
      });

      for (final (stopped, autoBlocked, blocked) in [
        (true, null, AutoBlock.stopped),
        (false, 'report', AutoBlock.report),
        (false, 'seated', AutoBlock.seated),
        (true, 'something-new', AutoBlock.other),
      ]) {
        test('reads $autoBlocked, stopped $stopped, as $blocked', () {
          final base = document();
          when(proposalsApi.watchLatestProposal).thenAnswer(
            (_) => Stream.value(
              ProposalDocument(
                id: base.id,
                status: base.status,
                groups: base.groups,
                unseated: base.unseated,
                createdAt: base.createdAt,
                auto: true,
                approveAt: createdAt,
                stopped: stopped,
                autoBlocked: autoBlocked,
              ),
            ),
          );

          expect(
            subject.watchLatestProposal(),
            emits(
              isA<Proposal>()
                  .having((p) => p.blocked, 'blocked', blocked)
                  .having((p) => p.approvesItself, 'approvesItself', isFalse),
            ),
          );
        });
      }

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

    group('stopProposal', () {
      test('stops it', () async {
        when(() => proposalsApi.stopProposal('p1')).thenAnswer((_) async {});

        await subject.stopProposal('p1');

        verify(() => proposalsApi.stopProposal('p1')).called(1);
      });
    });

    group('watchAutoForm', () {
      test('emits the switch and the hold', () {
        when(proposalsApi.watchAutoForm).thenAnswer(
          (_) => Stream.value(
            const AutoFormDocument(enabled: false, holdMinutes: 0),
          ),
        );

        expect(
          subject.watchAutoForm(),
          emits(const AutoFormSettings(enabled: false, holdMinutes: 0)),
        );
      });

      test('errors as forbidden when the rules refuse the read', () {
        when(proposalsApi.watchAutoForm).thenAnswer(
          (_) => Stream.error(
            FirebaseException(
              plugin: 'cloud_firestore',
              code: 'permission-denied',
            ),
          ),
        );

        expect(
          subject.watchAutoForm(),
          emitsError(
            isA<ProposalsFailure>().having(
              (f) => f.reason,
              'reason',
              ProposalsFailureReason.forbidden,
            ),
          ),
        );
      });
    });

    group('setAutoForm', () {
      test('sends the switch and the hold', () async {
        when(() => proposalsApi.setAutoForm(enabled: true, holdMinutes: 30))
            .thenAnswer((_) async {});

        await subject.setAutoForm(
          const AutoFormSettings(enabled: true, holdMinutes: 30),
        );

        verify(() => proposalsApi.setAutoForm(enabled: true, holdMinutes: 30))
            .called(1);
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
