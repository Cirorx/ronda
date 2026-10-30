import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/attendance/attendance.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(AttendanceCubit, () {
    late RondaRepository repository;
    late StreamController<AttendanceRoll?> rolls;

    setUp(() {
      repository = _MockRondaRepository();
      rolls = StreamController<AttendanceRoll?>();
      when(() => repository.watchRoll('r1', '2026-W45'))
          .thenAnswer((_) => rolls.stream);
      when(
        () => repository.recordAttendance(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          uid: any(named: 'uid'),
          came: any(named: 'came'),
        ),
      ).thenAnswer((_) async {});
    });

    tearDown(() => unawaited(rolls.close()));

    AttendanceCubit build() => AttendanceCubit(
      rondaId: 'r1',
      week: '2026-W45',
      rondaRepository: repository,
    );

    final roll = AttendanceFixtures.roll();

    blocTest<AttendanceCubit, AttendanceState>(
      'follows the roll, and says when there is none',
      build: build,
      act: (cubit) async {
        cubit.subscribe();
        rolls
          ..add(roll)
          ..add(null);
      },
      expect: () => [
        const AttendanceState(),
        AttendanceState(status: AttendanceStatus.ready, roll: roll),
        const AttendanceState(status: AttendanceStatus.none),
      ],
    );

    blocTest<AttendanceCubit, AttendanceState>(
      'shows a tap at once and lets the roll take over once it has it',
      build: build,
      seed: () => AttendanceState(status: AttendanceStatus.ready, roll: roll),
      act: (cubit) async {
        cubit.subscribe();
        rolls.add(roll);
        await Future<void>.delayed(Duration.zero);
        await cubit.marked('demo-103', came: false);
        rolls.add(
          AttendanceFixtures.roll(
            marks: const {'demo-102': true, 'demo-103': false},
          ),
        );
      },
      skip: 2,
      expect: () => [
        AttendanceState(
          status: AttendanceStatus.ready,
          roll: roll,
          pending: const {'demo-103': false},
        ),
        AttendanceState(
          status: AttendanceStatus.ready,
          roll: AttendanceFixtures.roll(
            marks: const {'demo-102': true, 'demo-103': false},
          ),
        ),
      ],
      verify: (cubit) {
        verify(
          () => repository.recordAttendance(
            rondaId: 'r1',
            week: '2026-W45',
            uid: 'demo-103',
            came: false,
          ),
        ).called(1);
        expect(cubit.state.markOf('demo-103'), isFalse);
        expect(cubit.state.markOf('demo-101'), isNull);
        expect(cubit.state.markedCount, 2);
      },
    );

    blocTest<AttendanceCubit, AttendanceState>(
      'takes a tap back with why when it fails',
      setUp: () => when(
        () => repository.recordAttendance(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          uid: any(named: 'uid'),
          came: any(named: 'came'),
        ),
      ).thenThrow(const HostsFailure(HostsFailureReason.passed)),
      build: build,
      seed: () => AttendanceState(status: AttendanceStatus.ready, roll: roll),
      act: (cubit) => cubit.marked('demo-101', came: true),
      expect: () => [
        AttendanceState(
          status: AttendanceStatus.ready,
          roll: roll,
          pending: const {'demo-101': true},
        ),
        AttendanceState(
          status: AttendanceStatus.ready,
          roll: roll,
          tapFailure: HostsFailureReason.passed,
        ),
      ],
      errors: () => [isA<HostsFailure>()],
    );

    blocTest<AttendanceCubit, AttendanceState>(
      'is forbidden for anyone but the hosts and the admin',
      build: build,
      act: (cubit) {
        cubit.subscribe();
        rolls.addError(const HostsFailure(HostsFailureReason.forbidden));
      },
      expect: () => [
        const AttendanceState(),
        const AttendanceState(status: AttendanceStatus.forbidden),
      ],
      errors: () => [isA<HostsFailure>()],
    );

    blocTest<AttendanceCubit, AttendanceState>(
      'fails on anything else',
      build: build,
      act: (cubit) {
        cubit.subscribe();
        rolls.addError(Exception('x'));
      },
      expect: () => [
        const AttendanceState(),
        const AttendanceState(status: AttendanceStatus.failure),
      ],
      errors: () => [isA<Exception>()],
    );

    test('a failed tap after closing emits nothing', () async {
      final done = Completer<void>();
      when(
        () => repository.recordAttendance(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          uid: any(named: 'uid'),
          came: any(named: 'came'),
        ),
      ).thenAnswer((_) async {
        await done.future;
        throw const HostsFailure(HostsFailureReason.other);
      });
      final cubit = build();
      final tap = cubit.marked('demo-101', came: true);
      await cubit.close();
      done.complete();

      await expectLater(tap, completes);
    });
  });
}
