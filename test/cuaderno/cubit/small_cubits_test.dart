import 'dart:async';

import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/cuaderno/cuaderno.dart';

class _MockCuadernoRepository extends Mock implements CuadernoRepository;

const _uid = 'demo-001';

void main() {
  late CuadernoRepository repository;
  late StreamController<void> changes;

  setUp(() {
    repository = _MockCuadernoRepository();
    changes = StreamController<void>.broadcast();
    addTearDown(changes.close);
    when(() => repository.changes).thenAnswer((_) => changes.stream);
  });

  group(CuadernoCardCubit, () {
    final entry = CuadernoEntry(day: DateTime(2026, 10, 29), text: 'uno');

    CuadernoCardCubit build() {
      final cubit = CuadernoCardCubit(
        uid: _uid,
        cuadernoRepository: repository,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('shows no line until one is chosen', () async {
      when(() => repository.read(_uid))
          .thenAnswer((_) async => Cuaderno(entries: [entry]));
      final cubit = build();

      await cubit.started();

      expect(cubit.state, isNull);
    });

    test('shows the line chosen to bring, and follows the cuaderno', () async {
      when(() => repository.read(_uid)).thenAnswer(
        (_) async => Cuaderno(entries: [entry], bringDay: entry.day),
      );
      final cubit = build();

      await cubit.started();
      expect(cubit.state, equals('uno'));

      when(() => repository.read(_uid)).thenAnswer((_) async => Cuaderno.empty);
      changes.add(null);
      await Future<void>.delayed(Duration.zero);
      expect(cubit.state, isNull);
    });

    test("shows nothing when the phone's store fails", () async {
      when(() => repository.read(_uid)).thenThrow(Exception('x'));
      final cubit = build();

      await cubit.started();

      expect(cubit.state, isNull);
    });

    test('says nothing once closed', () async {
      final read = Completer<Cuaderno>();
      when(() => repository.read(_uid)).thenAnswer((_) => read.future);
      final cubit = build();
      final reading = cubit.started();
      await cubit.close();
      read.complete(Cuaderno(entries: [entry], bringDay: entry.day));

      await reading;

      expect(cubit.state, isNull);
    });

    test('says nothing of a failure once closed', () async {
      final read = Completer<Cuaderno>();
      when(() => repository.read(_uid)).thenAnswer((_) => read.future);
      final cubit = build();
      final reading = cubit.started();
      await cubit.close();
      read.completeError(Exception('x'));

      await expectLater(reading, completes);
    });
  });

  group(EraseCuadernoCubit, () {
    EraseCuadernoCubit build() {
      final cubit = EraseCuadernoCubit(
        uid: _uid,
        cuadernoRepository: repository,
      );
      addTearDown(cubit.close);
      return cubit;
    }

    test('starts idle', () {
      expect(build().state, equals(EraseCuadernoStatus.idle));
    });

    test('deletes the whole cuaderno in one action', () async {
      when(() => repository.clear(_uid)).thenAnswer((_) async {});
      final cubit = build();

      await cubit.erase();

      verify(() => repository.clear(_uid)).called(1);
      expect(cubit.state, equals(EraseCuadernoStatus.erased));
    });

    test('says when it could not', () async {
      when(() => repository.clear(_uid)).thenThrow(Exception('x'));
      final cubit = build();

      await runZonedGuarded(cubit.erase, (_, _) {});

      expect(cubit.state, equals(EraseCuadernoStatus.failed));
    });

    test('asks once while it is deleting', () async {
      final deleting = Completer<void>();
      when(() => repository.clear(_uid)).thenAnswer((_) => deleting.future);
      final cubit = build();

      final first = cubit.erase();
      await cubit.erase();
      deleting.complete();
      await first;

      verify(() => repository.clear(_uid)).called(1);
    });
  });
}
