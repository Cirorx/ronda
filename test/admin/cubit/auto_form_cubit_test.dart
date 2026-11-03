import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(AutoFormCubit, () {
    late RondaRepository rondaRepository;
    late StreamController<AutoFormSettings> settings;

    const on = AutoFormSettings(enabled: true, holdMinutes: 60);
    const off = AutoFormSettings(enabled: false, holdMinutes: 60);
    const ready = AutoFormState(status: AutoFormStatus.ready, settings: on);

    setUpAll(() => registerFallbackValue(on));

    setUp(() {
      rondaRepository = _MockRondaRepository();
      settings = StreamController<AutoFormSettings>.broadcast();
      addTearDown(settings.close);
      when(rondaRepository.watchAutoForm).thenAnswer((_) => settings.stream);
      when(() => rondaRepository.setAutoForm(any())).thenAnswer((_) async {});
    });

    AutoFormCubit build() => AutoFormCubit(rondaRepository: rondaRepository);

    test('starts loading', () {
      expect(build().state, const AutoFormState());
    });

    group('subscribe', () {
      blocTest<AutoFormCubit, AutoFormState>(
        'shows the switch and the hold, and each change',
        build: build,
        act: (cubit) async {
          cubit.subscribe();
          settings.add(on);
          await Future<void>.delayed(Duration.zero);
          settings.add(off);
        },
        expect: () => [ready, ready.copyWith(settings: off)],
      );

      blocTest<AutoFormCubit, AutoFormState>(
        'fails when the read fails',
        build: build,
        act: (cubit) {
          cubit.subscribe();
          settings.addError(
            const ProposalsFailure(ProposalsFailureReason.forbidden),
          );
        },
        expect: () => [const AutoFormState(status: AutoFormStatus.failure)],
      );
    });

    group('enabledToggled', () {
      blocTest<AutoFormCubit, AutoFormState>(
        'saves the switch with the same hold',
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.enabledToggled(enabled: false),
        expect: () => [ready.copyWith(saving: true), ready],
        verify: (_) => verify(() => rondaRepository.setAutoForm(off)).called(1),
      );

      blocTest<AutoFormCubit, AutoFormState>(
        'does nothing before the setting is read',
        build: build,
        act: (cubit) => cubit.enabledToggled(enabled: false),
        expect: () => <AutoFormState>[],
      );

      blocTest<AutoFormCubit, AutoFormState>(
        'says so when saving fails',
        setUp: () => when(() => rondaRepository.setAutoForm(any()))
            .thenThrow(const ProposalsFailure(ProposalsFailureReason.other)),
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.enabledToggled(enabled: false),
        expect: () => [
          ready.copyWith(saving: true),
          ready.copyWith(saveFailed: true),
        ],
        errors: () => [isA<ProposalsFailure>()],
      );

      blocTest<AutoFormCubit, AutoFormState>(
        'waits for the save on its way',
        build: build,
        seed: () => ready.copyWith(saving: true),
        act: (cubit) => cubit.enabledToggled(enabled: false),
        expect: () => <AutoFormState>[],
      );
    });

    group('hold', () {
      blocTest<AutoFormCubit, AutoFormState>(
        'saves the typed minutes and shows the saved hold again',
        build: build,
        seed: () => ready,
        act: (cubit) async {
          cubit.holdChanged('0');
          await cubit.holdSaved();
        },
        expect: () => [
          ready.copyWith(holdDraft: '0'),
          ready.copyWith(holdDraft: '0', saving: true),
          ready,
        ],
        verify: (_) => verify(
          () => rondaRepository.setAutoForm(
            const AutoFormSettings(enabled: true, holdMinutes: 0),
          ),
        ).called(1),
      );

      for (final typed in ['', '1441', 'x']) {
        blocTest<AutoFormCubit, AutoFormState>(
          'does not save "$typed"',
          build: build,
          seed: () => ready.copyWith(holdDraft: typed),
          act: (cubit) => cubit.holdSaved(),
          expect: () => <AutoFormState>[],
        );
      }
    });

    test('reads the field as the saved hold until something is typed', () {
      expect(ready.holdText, '60');
      expect(ready.draftMinutes, 60);
      expect(ready.copyWith(holdDraft: ' 15 ').draftMinutes, 15);
      expect(const AutoFormState().holdText, '');
    });
  });
}
