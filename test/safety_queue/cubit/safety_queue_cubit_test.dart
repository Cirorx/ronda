import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/safety_queue/safety_queue.dart';
import 'package:safety_repository/safety_repository.dart';

import '../helpers.dart';

class _MockSafetyRepository extends Mock implements SafetyRepository;

void main() {
  group(SafetyQueueCubit, () {
    late SafetyRepository repository;
    late StreamController<SafetyQueue> queues;

    setUp(() {
      repository = _MockSafetyRepository();
      queues = StreamController<SafetyQueue>.broadcast();
      when(repository.watchQueue).thenAnswer((_) => queues.stream);
      for (final call in <Future<void> Function(String)>[
        repository.markRead,
        repository.archive,
        repository.reopen,
        repository.separate,
        repository.remove,
        repository.joinAgain,
        repository.letBackIn,
      ]) {
        when(() => call(any())).thenAnswer((_) async {});
      }
    });

    tearDown(() => queues.close());

    SafetyQueueCubit build() => SafetyQueueCubit(safetyRepository: repository);

    final ready = SafetyQueueState(
      status: SafetyQueueStatus.ready,
      queue: SafetyFixtures.queue,
    );

    group('subscribe', () {
      blocTest<SafetyQueueCubit, SafetyQueueState>(
        'follows the queue, marking each unread report read once',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          queues
            ..add(SafetyFixtures.queue)
            ..add(SafetyFixtures.queue);
        },
        expect: () => [
          const SafetyQueueState(),
          ready.copyWith(fresh: {'rep1'}),
        ],
        verify: (_) => verify(() => repository.markRead('rep1')).called(1),
      );

      blocTest<SafetyQueueCubit, SafetyQueueState>(
        'a report that could not be marked is tried again',
        setUp: () =>
            when(() => repository.markRead(any()))
                .thenThrow(const SafetyFailure(SafetyFailureReason.other)),
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          queues.add(SafetyFixtures.queue);
          await Future<void>.delayed(Duration.zero);
          queues.add(SafetyFixtures.queue);
        },
        verify: (_) => verify(() => repository.markRead('rep1')).called(2),
        errors: () => hasLength(2),
      );

      for (final (reason, status) in [
        (SafetyFailureReason.forbidden, SafetyQueueStatus.forbidden),
        (SafetyFailureReason.other, SafetyQueueStatus.failure),
      ]) {
        blocTest<SafetyQueueCubit, SafetyQueueState>(
          'a refused read as $reason is $status',
          build: build,
          act: (cubit) {
            cubit.subscribe();
            queues.addError(SafetyFailure(reason));
          },
          expect: () => [
            const SafetyQueueState(),
            SafetyQueueState(status: status),
          ],
          errors: () => [isA<SafetyFailure>()],
        );
      }
    });

    blocTest<SafetyQueueCubit, SafetyQueueState>(
      'changes tabs',
      build: build,
      seed: () => ready,
      act: (cubit) => cubit.tabChanged(SafetyQueueTab.archived),
      expect: () => [ready.copyWith(tab: SafetyQueueTab.archived)],
    );

    group('acts', () {
      final actions = <String, Future<void> Function(SafetyQueueCubit)>{
        'archive': (cubit) => cubit.archive('rep1'),
        'reopen': (cubit) => cubit.reopen('rep1'),
        'separate': (cubit) => cubit.separate('rep1'),
        'remove': (cubit) => cubit.remove('rep1'),
        'joinAgain': (cubit) => cubit.joinAgain('rep1'),
        'letBackIn': (cubit) => cubit.letBackIn('rep1'),
      };
      for (final MapEntry(key: name, value: act) in actions.entries) {
        blocTest<SafetyQueueCubit, SafetyQueueState>(
          '$name is busy while it goes',
          build: build,
          seed: () => ready,
          act: act,
          expect: () => [ready.copyWith(busy: () => 'rep1'), ready],
        );
      }

      blocTest<SafetyQueueCubit, SafetyQueueState>(
        'says when it failed',
        setUp: () =>
            when(() => repository.remove(any()))
                .thenThrow(const SafetyFailure(SafetyFailureReason.gone)),
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.remove('rep1'),
        expect: () => [
          ready.copyWith(busy: () => 'rep1'),
          ready.copyWith(actionFailed: true),
        ],
        errors: () => [isA<SafetyFailure>()],
      );
    });
  });

  group(SafetyQueueState, () {
    test('puts anyone told about by two or more people on top', () {
      final state = SafetyQueueState(queue: SafetyFixtures.queue);

      expect(state.reportersOf('beto'), equals(2));
      expect(state.reportersOf(''), equals(0));
      expect(state.shown.map((r) => r.id), equals(['rep1', 'rep2', 'rep3']));
      expect(state.openCount, equals(3));
      expect(
        state.copyWith(tab: SafetyQueueTab.archived).shown.map((r) => r.id),
        equals(['rep4']),
      );
    });

    test('finds the pair a report separated and who is out', () {
      final state = SafetyQueueState(
        queue: SafetyQueue(
          reports: SafetyFixtures.queue.reports,
          separated: const [
            SeparatedPair(id: 'ana_beto', uidA: 'ana', uidB: 'beto'),
          ],
          removed: [
            RemovedPerson(
              uid: 'beto',
              firstName: 'Beto',
              at: SafetyFixtures.at,
            ),
          ],
        ),
      );

      expect(state.separationOf(SafetyFixtures.beto)?.id, equals('ana_beto'));
      expect(state.separationOf(SafetyFixtures.cora), isNull);
      expect(state.separationOf(SafetyFixtures.outside), isNull);
      expect(state.isRemoved('beto'), isTrue);
      expect(state.isRemoved('cora'), isFalse);
    });
  });
}
