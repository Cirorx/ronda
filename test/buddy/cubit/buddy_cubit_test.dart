import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/buddy/buddy.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

class _MockContactRepository extends Mock implements ContactRepository;

const _mirta = SetupMember(uid: 'demo-101', firstName: 'Mirta');
const _jorge = SetupMember(uid: 'demo-102', firstName: 'Jorge');
const _open = BuddyOptions(due: true, chosen: false, choices: [_mirta, _jorge]);
const _ask = BuddyAsk(
  rondaId: 'r1',
  misses: [BuddyMiss(firstName: 'Graciela', dayId: 'thu')],
);

void main() {
  group(BuddyCubit, () {
    late RondaRepository rondaRepository;
    late ContactRepository contactRepository;
    late StreamController<BuddyAsk?> asks;

    setUp(() {
      rondaRepository = _MockRondaRepository();
      contactRepository = _MockContactRepository();
      asks = StreamController<BuddyAsk?>.broadcast();
      addTearDown(() => unawaited(asks.close()));
      when(() => rondaRepository.watchBuddyAsk('demo-001'))
          .thenAnswer((_) => asks.stream);
      when(() => rondaRepository.buddyOptions('r1'))
          .thenAnswer((_) async => _open);
      when(
        () => rondaRepository.setBuddy(
          rondaId: any(named: 'rondaId'),
          buddyUid: any(named: 'buddyUid'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => rondaRepository.closeBuddyAsk(
          rondaId: any(named: 'rondaId'),
          uid: any(named: 'uid'),
        ),
      ).thenAnswer((_) async {});
      when(contactRepository.canOpenWhatsApp).thenAnswer((_) async => true);
      when(contactRepository.openWhatsApp).thenAnswer((_) async {});
    });

    BuddyCubit build() => BuddyCubit(
      rondaId: 'r1',
      uid: 'demo-001',
      rondaRepository: rondaRepository,
      contactRepository: contactRepository,
    );

    const ready = BuddyState(
      status: BuddyStatus.ready,
      options: _open,
      canWhatsApp: true,
    );

    test('starts loading', () {
      expect(build().state, const BuddyState());
    });

    blocTest<BuddyCubit, BuddyState>(
      'load reads the options and follows the buddy card',
      build: build,
      act: (cubit) async {
        await cubit.load();
        asks.add(_ask);
        await Future<void>.delayed(Duration.zero);
      },
      expect: () => [ready, ready.copyWith(ask: () => _ask)],
    );

    blocTest<BuddyCubit, BuddyState>(
      'load says when the options could not be read',
      setUp: () =>
          when(() => rondaRepository.buddyOptions('r1'))
              .thenThrow(const HostsFailure(HostsFailureReason.other)),
      build: build,
      act: (cubit) => cubit.load(),
      expect: () => [const BuddyState(status: BuddyStatus.failure)],
      errors: () => [isA<HostsFailure>()],
    );

    blocTest<BuddyCubit, BuddyState>(
      'picking and "Elegir" save the buddy',
      build: build,
      seed: () => ready,
      act: (cubit) async {
        cubit.picked('demo-102');
        await cubit.chooseTapped();
      },
      expect: () => [
        ready.copyWith(selected: () => 'demo-102'),
        ready.copyWith(
          selected: () => 'demo-102',
          saving: () => BuddySaving.choose,
        ),
        ready.copyWith(
          selected: () => 'demo-102',
          options: const BuddyOptions(
            due: true,
            chosen: true,
            choices: [_mirta, _jorge],
            buddy: _jorge,
          ),
        ),
      ],
      verify: (_) => verify(
        () => rondaRepository.setBuddy(rondaId: 'r1', buddyUid: 'demo-102'),
      ).called(1),
    );

    blocTest<BuddyCubit, BuddyState>(
      '"Elegir" with nobody picked does nothing',
      build: build,
      seed: () => ready,
      act: (cubit) => cubit.chooseTapped(),
      expect: () => <BuddyState>[],
    );

    blocTest<BuddyCubit, BuddyState>(
      '"Ahora no" saves nobody, and "Cambiar" shows the list again',
      build: build,
      seed: () => ready,
      act: (cubit) async {
        await cubit.notNowTapped();
        cubit.changeTapped();
      },
      skip: 1,
      expect: () => [
        ready.copyWith(
          options: const BuddyOptions(
            due: true,
            chosen: true,
            choices: [_mirta, _jorge],
          ),
        ),
        ready.copyWith(
          changing: true,
          options: const BuddyOptions(
            due: true,
            chosen: true,
            choices: [_mirta, _jorge],
          ),
        ),
      ],
      verify: (_) =>
          verify(() => rondaRepository.setBuddy(rondaId: 'r1')).called(1),
    );

    blocTest<BuddyCubit, BuddyState>(
      'says when the choice was not saved, and saves once at a time',
      setUp: () => when(
        () => rondaRepository.setBuddy(
          rondaId: any(named: 'rondaId'),
          buddyUid: any(named: 'buddyUid'),
        ),
      ).thenThrow(const HostsFailure(HostsFailureReason.other)),
      build: build,
      seed: () => ready,
      act: (cubit) async {
        await cubit.notNowTapped();
        cubit.emit(ready.copyWith(saving: () => BuddySaving.notNow));
        await cubit.notNowTapped();
      },
      expect: () => [
        ready.copyWith(saving: () => BuddySaving.notNow),
        ready.copyWith(saveFailed: true),
        ready.copyWith(saving: () => BuddySaving.notNow),
      ],
      errors: () => [isA<HostsFailure>()],
    );

    blocTest<BuddyCubit, BuddyState>(
      '"Le escribo" opens WhatsApp and closes the card',
      build: build,
      seed: () => ready.copyWith(ask: () => _ask),
      act: (cubit) => cubit.writeTapped(),
      expect: () => [ready],
      verify: (_) {
        verify(contactRepository.openWhatsApp).called(1);
        verify(
          () => rondaRepository.closeBuddyAsk(rondaId: 'r1', uid: 'demo-001'),
        ).called(1);
      },
    );

    blocTest<BuddyCubit, BuddyState>(
      'the card closes even when WhatsApp or the server fails',
      setUp: () {
        when(contactRepository.openWhatsApp).thenThrow(const ContactFailure());
        when(
          () => rondaRepository.closeBuddyAsk(
            rondaId: any(named: 'rondaId'),
            uid: any(named: 'uid'),
          ),
        ).thenThrow(const HostsFailure(HostsFailureReason.other));
      },
      build: build,
      seed: () => ready.copyWith(ask: () => _ask),
      act: (cubit) => cubit.writeTapped(),
      expect: () => [ready],
      errors: () => [isA<ContactFailure>(), isA<HostsFailure>()],
    );

    test('a choice or options finishing after close emit nothing', () async {
      final options = Completer<BuddyOptions>();
      when(() => rondaRepository.buddyOptions('r1'))
          .thenAnswer((_) => options.future);
      final saving = Completer<void>();
      when(
        () => rondaRepository.setBuddy(
          rondaId: any(named: 'rondaId'),
          buddyUid: any(named: 'buddyUid'),
        ),
      ).thenAnswer((_) => saving.future);
      final failing = Completer<BuddyOptions>();
      final loading = build();
      final choosing = build()..emit(ready);

      final loaded = loading.load();
      final chosen = choosing.notNowTapped();
      await Future<void>.delayed(Duration.zero);
      await loading.close();
      await choosing.close();
      options.complete(_open);
      saving.complete();
      await loaded;
      await chosen;

      expect(loading.state, const BuddyState());
      expect(choosing.state.saving, BuddySaving.notNow);

      when(() => rondaRepository.buddyOptions('r1'))
          .thenAnswer((_) => failing.future);
      final failed = build();
      final failedLoad = failed.load();
      await Future<void>.delayed(Duration.zero);
      await failed.close();
      failing.completeError(const HostsFailure(HostsFailureReason.other));
      await failedLoad;
      expect(failed.state, const BuddyState());

      final failingSave = Completer<void>();
      when(
        () => rondaRepository.setBuddy(
          rondaId: any(named: 'rondaId'),
          buddyUid: any(named: 'buddyUid'),
        ),
      ).thenAnswer((_) => failingSave.future);
      final refused = build()..emit(ready);
      final refusedSave = refused.notNowTapped();
      await refused.close();
      failingSave.completeError(const HostsFailure(HostsFailureReason.other));
      await refusedSave;
      expect(refused.state.saving, BuddySaving.notNow);
    });
  });
}
