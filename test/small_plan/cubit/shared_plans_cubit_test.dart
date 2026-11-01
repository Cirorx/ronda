import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/small_plan/cubit/shared_plans_cubit.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

class _MockSmallPlanRepository extends Mock implements SmallPlanRepository;

void main() {
  group(SharedPlansCubit, () {
    late SmallPlanRepository repository;
    late StreamController<SharedPlans> plans;
    final walk = SmallPlan(
      kind: SmallPlanKind.walk,
      at: DateTime(2026, 11, 5, 19),
      place: 'por la rambla',
      activity: 'Caminar',
    );
    final mine = SharedPlans(
      mine: SharedPlanMine(at: DateTime(2026, 11, 5, 19), joined: const []),
    );
    const failure = SmallPlanFailure(SmallPlanFailureKind.shareFailed);

    setUpAll(() {
      registerFallbackValue(
        SmallPlan(kind: SmallPlanKind.walk, at: DateTime(1)),
      );
    });

    setUp(() {
      repository = _MockSmallPlanRepository();
      plans = StreamController<SharedPlans>.broadcast();
      when(() => repository.watchShared(rondaId: 'r1', uid: 'u1'))
          .thenAnswer((_) => plans.stream);
      when(() => repository.withdraw('r1')).thenAnswer((_) async {});
    });

    tearDown(() => plans.close());

    SharedPlansCubit build() => SharedPlansCubit(
      rondaId: 'r1',
      uid: 'u1',
      smallPlanRepository: repository,
    );

    void answerShare([Exception? error]) =>
        when(
          () => repository.share(
            rondaId: 'r1',
            plan: any(named: 'plan'),
            what: any(named: 'what'),
          ),
        ).thenAnswer((_) async {
          if (error != null) throw error;
        });

    void answerJoin(Future<void> Function() answer) {
      when(
        () => repository.join(
          rondaId: any(named: 'rondaId'),
          authorUid: any(named: 'authorUid'),
        ),
      ).thenAnswer((_) => answer());
      when(
        () => repository.leave(
          rondaId: any(named: 'rondaId'),
          authorUid: any(named: 'authorUid'),
        ),
      ).thenAnswer((_) => answer());
    }

    test('starts loading, with nothing', () {
      expect(build().state, equals(const SharedPlansState()));
    });

    group('subscribe', () {
      blocTest<SharedPlansCubit, SharedPlansState>(
        'follows the ronda, and starts over when asked again',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          plans.add(mine);
          await pumpEventQueue();
          cubit.subscribe();
          plans.add(const SharedPlans());
        },
        expect: () => [
          SharedPlansState(status: SharedPlansStatus.ready, plans: mine),
          const SharedPlansState(status: SharedPlansStatus.ready),
        ],
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'shows nothing when the plans cannot be read',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          plans.addError(
            const SmallPlanFailure(SmallPlanFailureKind.watchFailed),
          );
        },
        errors: () => [isA<SmallPlanFailure>()],
        expect: () => const [
          SharedPlansState(status: SharedPlansStatus.failure),
        ],
      );
    });

    group('shareTapped', () {
      blocTest<SharedPlansCubit, SharedPlansState>(
        'opens the plan to the ronda',
        setUp: answerShare,
        build: build,
        act: (cubit) => cubit.shareTapped(walk, 'Caminar'),
        expect: () => const [
          SharedPlansState(sharing: true),
          SharedPlansState(),
        ],
        verify: (_) => verify(
          () => repository.share(rondaId: 'r1', plan: walk, what: 'Caminar'),
        ).called(1),
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'says why a plan was held, and keeps it private',
        setUp: () => answerShare(const SharedPlanHeld(ShareHoldReason.time)),
        build: build,
        act: (cubit) => cubit.shareTapped(walk, 'Caminar'),
        expect: () => const [
          SharedPlansState(sharing: true),
          SharedPlansState(held: ShareHoldReason.time),
        ],
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'says when it could not be sent',
        setUp: () => answerShare(failure),
        build: build,
        act: (cubit) => cubit.shareTapped(walk, 'Caminar'),
        errors: () => [failure],
        expect: () => const [
          SharedPlansState(sharing: true),
          SharedPlansState(problem: SharedPlansProblem.shareFailed),
        ],
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'ignores a second tap while one is on its way',
        setUp: answerShare,
        build: build,
        seed: () => const SharedPlansState(sharing: true),
        act: (cubit) => cubit.shareTapped(walk, 'Caminar'),
        expect: () => const <SharedPlansState>[],
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'does not emit once closed',
        build: build,
        act: (cubit) async {
          final sent = Completer<void>();
          when(
            () => repository.share(
              rondaId: 'r1',
              plan: any(named: 'plan'),
              what: any(named: 'what'),
            ),
          ).thenAnswer((_) => sent.future);
          final sharing = cubit.shareTapped(walk, 'Caminar');
          await cubit.close();
          sent.complete();
          await sharing;
        },
        expect: () => const [SharedPlansState(sharing: true)],
      );
    });

    group('withdrawTapped', () {
      blocTest<SharedPlansCubit, SharedPlansState>(
        'takes the plan back',
        build: build,
        act: (cubit) => cubit.withdrawTapped(),
        expect: () => const [
          SharedPlansState(sharing: true),
          SharedPlansState(),
        ],
        verify: (_) => verify(() => repository.withdraw('r1')).called(1),
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'says when it could not',
        setUp: () => when(() => repository.withdraw('r1')).thenThrow(failure),
        build: build,
        act: (cubit) => cubit.withdrawTapped(),
        errors: () => [failure],
        expect: () => const [
          SharedPlansState(sharing: true),
          SharedPlansState(problem: SharedPlansProblem.shareFailed),
        ],
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'ignores a tap while one is on its way',
        build: build,
        seed: () => const SharedPlansState(sharing: true),
        act: (cubit) => cubit.withdrawTapped(),
        expect: () => const <SharedPlansState>[],
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'does not emit once closed',
        build: build,
        act: (cubit) async {
          final taken = Completer<void>();
          when(() => repository.withdraw('r1')).thenAnswer((_) => taken.future);
          final withdrawing = cubit.withdrawTapped();
          await cubit.close();
          taken.complete();
          await withdrawing;
        },
        expect: () => const [SharedPlansState(sharing: true)],
      );
    });

    group('planChanged', () {
      blocTest<SharedPlansCubit, SharedPlansState>(
        'takes back what was opened',
        build: build,
        seed: () =>
            SharedPlansState(status: SharedPlansStatus.ready, plans: mine),
        act: (cubit) => cubit.planChanged(),
        expect: () => const <SharedPlansState>[],
        verify: (_) => verify(() => repository.withdraw('r1')).called(1),
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'does nothing when nothing was opened',
        build: build,
        act: (cubit) => cubit.planChanged(),
        expect: () => const <SharedPlansState>[],
        verify: (_) => verifyNever(() => repository.withdraw(any())),
      );
    });

    group('joining', () {
      blocTest<SharedPlansCubit, SharedPlansState>(
        '[Me sumo] and "Ya no voy" go through the repository',
        setUp: () => answerJoin(() async {}),
        build: build,
        act: (cubit) async {
          await cubit.joinTapped('u2');
          await cubit.leaveTapped('u2');
        },
        expect: () => const [
          SharedPlansState(joining: 'u2'),
          SharedPlansState(),
          SharedPlansState(joining: 'u2'),
          SharedPlansState(),
        ],
        verify: (_) {
          verify(() => repository.join(rondaId: 'r1', authorUid: 'u2'))
              .called(1);
          verify(() => repository.leave(rondaId: 'r1', authorUid: 'u2'))
              .called(1);
        },
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'says when the plan is gone, without logging it',
        setUp: () => answerJoin(
          () async =>
              throw const SmallPlanFailure(SmallPlanFailureKind.planGone),
        ),
        build: build,
        act: (cubit) => cubit.joinTapped('u2'),
        expect: () => const [
          SharedPlansState(joining: 'u2'),
          SharedPlansState(problem: SharedPlansProblem.planGone),
        ],
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'says when it did not go through',
        setUp: () => answerJoin(
          () async =>
              throw const SmallPlanFailure(SmallPlanFailureKind.joinFailed),
        ),
        build: build,
        act: (cubit) => cubit.joinTapped('u2'),
        errors: () => [isA<SmallPlanFailure>()],
        expect: () => const [
          SharedPlansState(joining: 'u2'),
          SharedPlansState(problem: SharedPlansProblem.joinFailed),
        ],
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'ignores a tap while another is on its way',
        setUp: () => answerJoin(() async {}),
        build: build,
        seed: () => const SharedPlansState(joining: 'u3'),
        act: (cubit) => cubit.joinTapped('u2'),
        expect: () => const <SharedPlansState>[],
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'does not emit once closed',
        build: build,
        act: (cubit) async {
          final answered = Completer<void>();
          answerJoin(() => answered.future);
          final joining = cubit.joinTapped('u2');
          await cubit.close();
          answered.complete();
          await joining;
        },
        expect: () => const [SharedPlansState(joining: 'u2')],
      );

      blocTest<SharedPlansCubit, SharedPlansState>(
        'does not emit a failure once closed',
        build: build,
        act: (cubit) async {
          final answered = Completer<void>();
          answerJoin(() => answered.future);
          final joining = cubit.joinTapped('u2');
          await cubit.close();
          answered.completeError(
            const SmallPlanFailure(SmallPlanFailureKind.joinFailed),
          );
          await joining;
        },
        errors: () => [isA<SmallPlanFailure>()],
        expect: () => const [SharedPlansState(joining: 'u2')],
      );
    });
  });
}
