import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(ProposalsCubit, () {
    late RondaRepository rondaRepository;
    late StreamController<Proposal?> proposals;

    setUp(() {
      rondaRepository = _MockRondaRepository();
      proposals = StreamController<Proposal?>.broadcast();
      addTearDown(proposals.close);
      when(rondaRepository.watchLatestProposal)
          .thenAnswer((_) => proposals.stream);
    });

    ProposalsCubit build() => ProposalsCubit(rondaRepository: rondaRepository);

    final pending = AdminFixtures.proposal();
    final approved = AdminFixtures.proposal(status: ProposalStatus.approved);

    ProposalsState ready(
      Proposal? proposal, {
      ProposalsAction action = ProposalsAction.none,
      bool actionFailed = false,
    }) => ProposalsState(
      status: ProposalsStatus.ready,
      proposal: proposal,
      action: action,
      actionFailed: actionFailed,
    );

    test('starts loading', () {
      expect(build().state, const ProposalsState());
    });

    group('subscribe', () {
      blocTest<ProposalsCubit, ProposalsState>(
        'emits ready with each newest proposal',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          proposals
            ..add(null)
            ..add(pending);
        },
        expect: () => [const ProposalsState(), ready(null), ready(pending)],
      );

      blocTest<ProposalsCubit, ProposalsState>(
        'emits forbidden when the account is not admin',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          proposals.addError(
            const ProposalsFailure(ProposalsFailureReason.forbidden),
          );
        },
        expect: () => [
          const ProposalsState(),
          const ProposalsState(status: ProposalsStatus.forbidden),
        ],
      );

      blocTest<ProposalsCubit, ProposalsState>(
        'emits failure when the read fails for another reason',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          proposals.addError(
            const ProposalsFailure(ProposalsFailureReason.other),
          );
        },
        expect: () => [
          const ProposalsState(),
          const ProposalsState(status: ProposalsStatus.failure),
        ],
      );
    });

    group('propose', () {
      blocTest<ProposalsCubit, ProposalsState>(
        'runs the solver and goes back to idle',
        setUp: () =>
            when(rondaRepository.proposeGroups).thenAnswer((_) async => 'p2'),
        build: build,
        seed: () => ready(null),
        act: (cubit) => cubit.propose(),
        expect: () => [
          ready(null, action: ProposalsAction.proposing),
          ready(null),
        ],
        verify: (_) => verify(rondaRepository.proposeGroups).called(1),
      );

      blocTest<ProposalsCubit, ProposalsState>(
        'says the step failed when the server fails',
        setUp: () => when(rondaRepository.proposeGroups)
            .thenThrow(const ProposalsFailure(ProposalsFailureReason.other)),
        build: build,
        seed: () => ready(pending),
        act: (cubit) => cubit.propose(),
        expect: () => [
          ready(pending, action: ProposalsAction.proposing),
          ready(pending, actionFailed: true),
        ],
      );

      blocTest<ProposalsCubit, ProposalsState>(
        'emits forbidden when the callable refuses the account',
        setUp: () => when(
          rondaRepository.proposeGroups,
        ).thenThrow(const ProposalsFailure(ProposalsFailureReason.forbidden)),
        build: build,
        seed: () => ready(null),
        act: (cubit) => cubit.propose(),
        expect: () => [
          ready(null, action: ProposalsAction.proposing),
          const ProposalsState(status: ProposalsStatus.forbidden),
        ],
      );

      blocTest<ProposalsCubit, ProposalsState>(
        'does nothing while another step runs',
        build: build,
        seed: () => ready(pending, action: ProposalsAction.approving),
        act: (cubit) => cubit.propose(),
        expect: () => <ProposalsState>[],
        verify: (_) => verifyNever(rondaRepository.proposeGroups),
      );

      blocTest<ProposalsCubit, ProposalsState>(
        'does nothing before the proposals are read',
        build: build,
        act: (cubit) => cubit.propose(),
        expect: () => <ProposalsState>[],
      );
    });

    group('approve', () {
      blocTest<ProposalsCubit, ProposalsState>(
        'approves the pending proposal',
        setUp: () =>
            when(() => rondaRepository.approveProposal('p1'))
                .thenAnswer((_) async {}),
        build: build,
        seed: () => ready(pending),
        act: (cubit) => cubit.approve(),
        expect: () => [
          ready(pending, action: ProposalsAction.approving),
          ready(pending),
        ],
        verify: (_) =>
            verify(() => rondaRepository.approveProposal('p1')).called(1),
      );

      blocTest<ProposalsCubit, ProposalsState>(
        'does nothing for an approved proposal',
        build: build,
        seed: () => ready(approved),
        act: (cubit) => cubit.approve(),
        expect: () => <ProposalsState>[],
      );
    });

    group('undo', () {
      blocTest<ProposalsCubit, ProposalsState>(
        'takes the approval back',
        setUp: () =>
            when(() => rondaRepository.undoApproval('p1'))
                .thenAnswer((_) async {}),
        build: build,
        seed: () => ready(approved),
        act: (cubit) => cubit.undo(),
        expect: () => [
          ready(approved, action: ProposalsAction.undoing),
          ready(approved),
        ],
      );

      blocTest<ProposalsCubit, ProposalsState>(
        'does nothing for a pending proposal',
        build: build,
        seed: () => ready(pending),
        act: (cubit) => cubit.undo(),
        expect: () => <ProposalsState>[],
      );
    });

    group('busy', () {
      test('is true only while a step runs', () {
        expect(ready(null).busy, isFalse);
        expect(ready(null, action: ProposalsAction.undoing).busy, isTrue);
      });
    });
  });
}
