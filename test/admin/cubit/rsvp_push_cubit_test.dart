import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(RsvpPushCubit, () {
    late RondaRepository rondaRepository;

    setUp(() => rondaRepository = _MockRondaRepository());

    RsvpPushCubit build() => RsvpPushCubit(rondaRepository: rondaRepository);

    const result = RsvpPushResult(pushed: 1, messages: 5, already: 0, held: 0);

    test('starts idle', () {
      expect(build().state, const RsvpPushState());
    });

    blocTest<RsvpPushCubit, RsvpPushState>(
      'sends it now and keeps what came of it',
      setUp: () =>
          when(rondaRepository.sendRsvpNow).thenAnswer((_) async => result),
      build: build,
      act: (cubit) => cubit.sendTapped(),
      expect: () => const [
        RsvpPushState(status: RsvpPushStatus.sending),
        RsvpPushState(status: RsvpPushStatus.sent, result: result),
      ],
    );

    blocTest<RsvpPushCubit, RsvpPushState>(
      'says it failed',
      setUp: () =>
          when(rondaRepository.sendRsvpNow)
              .thenThrow(const RsvpFailure(RsvpFailureReason.forbidden)),
      build: build,
      act: (cubit) => cubit.sendTapped(),
      expect: () => const [
        RsvpPushState(status: RsvpPushStatus.sending),
        RsvpPushState(status: RsvpPushStatus.failed),
      ],
      errors: () => [isA<RsvpFailure>()],
    );

    blocTest<RsvpPushCubit, RsvpPushState>(
      'ignores a second tap while it sends',
      build: build,
      seed: () => const RsvpPushState(status: RsvpPushStatus.sending),
      act: (cubit) => cubit.sendTapped(),
      expect: () => const <RsvpPushState>[],
      verify: (_) => verifyNever(rondaRepository.sendRsvpNow),
    );
  });
}
