import 'package:bloc_test/bloc_test.dart';
import 'package:calendar_client/calendar_client.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/small_plan/cubit/small_plan_cubit.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

class _MockSmallPlanRepository extends Mock implements SmallPlanRepository;

void main() {
  group(SmallPlanCubit, () {
    late SmallPlanRepository repository;
    final walk = SmallPlan(
      kind: SmallPlanKind.walk,
      at: DateTime(2026, 11, 3, 19),
      place: 'la Rambla',
    );
    const failure = SmallPlanFailure(SmallPlanFailureKind.storageFailed);

    setUp(() {
      repository = _MockSmallPlanRepository();
      when(() => repository.current('uid'))
          .thenAnswer((_) async => const SmallPlanOffer());
      when(() => repository.save('uid', any())).thenAnswer((_) async {});
      when(() => repository.answerFollowUp('uid')).thenAnswer((_) async {});
      when(() => repository.skipThisWeek('uid')).thenAnswer((_) async {});
    });

    SmallPlanCubit build() =>
        SmallPlanCubit(uid: 'uid', smallPlanRepository: repository);

    setUpAll(() {
      registerFallbackValue(
        SmallPlan(kind: SmallPlanKind.walk, at: DateTime(1)),
      );
    });

    test('starts loading, showing nothing', () {
      expect(build().state, equals(const SmallPlanState()));
    });

    group('load', () {
      blocTest<SmallPlanCubit, SmallPlanState>(
        'shows what the phone decides',
        build: build,
        act: (cubit) => cubit.load(),
        expect: () => const [
          SmallPlanState(),
          SmallPlanState(status: SmallPlanStatus.ready, card: SmallPlanOffer()),
        ],
      );

      blocTest<SmallPlanCubit, SmallPlanState>(
        'fails when the phone cannot be read',
        setUp: () => when(() => repository.current('uid')).thenThrow(failure),
        build: build,
        act: (cubit) => cubit.load(),
        errors: () => [failure],
        expect: () => const [
          SmallPlanState(),
          SmallPlanState(status: SmallPlanStatus.failure),
        ],
      );
    });

    group('planChosen', () {
      blocTest<SmallPlanCubit, SmallPlanState>(
        'keeps the plan and shows it',
        build: build,
        act: (cubit) => cubit.planChosen(walk),
        verify: (_) => verify(() => repository.save('uid', walk)).called(1),
        expect: () => [SmallPlanState(card: SmallPlanSet(walk))],
      );

      blocTest<SmallPlanCubit, SmallPlanState>(
        'says so when the phone cannot keep it',
        setUp: () =>
            when(() => repository.save('uid', any())).thenThrow(failure),
        build: build,
        act: (cubit) => cubit.planChosen(walk),
        errors: () => [failure],
        expect: () => const [SmallPlanState(saveFailed: true)],
      );
    });

    group('calendarTapped', () {
      final withPlan = SmallPlanState(
        status: SmallPlanStatus.ready,
        card: SmallPlanSet(walk),
      );

      blocTest<SmallPlanCubit, SmallPlanState>(
        'opens the calendar with the title the screen worded',
        setUp: () =>
            when(() => repository.addToCalendar(walk, title: 'Caminar'))
                .thenAnswer((_) async => CalendarOutcome.opened),
        build: build,
        seed: () => withPlan,
        act: (cubit) => cubit.calendarTapped('Caminar'),
        expect: () => [withPlan.copyWith(calendar: SmallPlanCalendar.opened)],
      );

      blocTest<SmallPlanCubit, SmallPlanState>(
        'downloads the file on web',
        setUp: () =>
            when(() => repository.addToCalendar(walk, title: 'Caminar'))
                .thenAnswer((_) async => CalendarOutcome.downloaded),
        build: build,
        seed: () => withPlan,
        act: (cubit) => cubit.calendarTapped('Caminar'),
        expect: () => [
          withPlan.copyWith(calendar: SmallPlanCalendar.downloaded),
        ],
      );

      blocTest<SmallPlanCubit, SmallPlanState>(
        'says so when there is no calendar',
        setUp: () =>
            when(
              () => repository.addToCalendar(walk, title: 'Caminar'),
            ).thenThrow(
              const SmallPlanFailure(SmallPlanFailureKind.calendarUnavailable),
            ),
        build: build,
        seed: () => withPlan,
        act: (cubit) => cubit.calendarTapped('Caminar'),
        expect: () => [withPlan.copyWith(calendar: SmallPlanCalendar.failed)],
      );

      blocTest<SmallPlanCubit, SmallPlanState>(
        'does nothing without a plan',
        build: build,
        act: (cubit) => cubit.calendarTapped('Caminar'),
        expect: () => const <SmallPlanState>[],
      );
    });

    group('followUpAnswered', () {
      blocTest<SmallPlanCubit, SmallPlanState>(
        'forgets the plan, replies, and offers a new one',
        build: build,
        seed: () => SmallPlanState(
          status: SmallPlanStatus.ready,
          card: SmallPlanFollowUp(walk),
        ),
        act: (cubit) => cubit.followUpAnswered(),
        verify: (_) => verify(() => repository.answerFollowUp('uid')).called(1),
        expect: () => const [
          SmallPlanState(
            status: SmallPlanStatus.ready,
            card: SmallPlanOffer(),
            replied: true,
          ),
        ],
      );

      blocTest<SmallPlanCubit, SmallPlanState>(
        'replies even when the phone cannot forget',
        setUp: () =>
            when(() => repository.answerFollowUp('uid')).thenThrow(failure),
        build: build,
        act: (cubit) => cubit.followUpAnswered(),
        errors: () => [failure],
        expect: () => const [
          SmallPlanState(card: SmallPlanOffer(), replied: true),
        ],
      );
    });

    group('notThisWeek', () {
      blocTest<SmallPlanCubit, SmallPlanState>(
        'hides the offer until next week',
        build: build,
        seed: () => const SmallPlanState(
          status: SmallPlanStatus.ready,
          card: SmallPlanOffer(),
        ),
        act: (cubit) => cubit.notThisWeek(),
        verify: (_) => verify(() => repository.skipThisWeek('uid')).called(1),
        expect: () => const [SmallPlanState(status: SmallPlanStatus.ready)],
      );

      blocTest<SmallPlanCubit, SmallPlanState>(
        'hides it for now even when the phone cannot remember',
        setUp: () =>
            when(() => repository.skipThisWeek('uid')).thenThrow(failure),
        build: build,
        seed: () => const SmallPlanState(card: SmallPlanOffer()),
        act: (cubit) => cubit.notThisWeek(),
        errors: () => [failure],
        expect: () => const [SmallPlanState()],
      );
    });
  });
}
