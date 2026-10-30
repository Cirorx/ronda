import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

const _counts = SeguimosCounts(
  rondaId: 'r1',
  line: 'Sábado a la tarde · mate en la rambla',
  status: SeguimosStatus.open,
  yes: 2,
  no: 1,
  unanswered: 3,
);

void main() {
  group(SeguimosCountsCubit, () {
    late RondaRepository rondaRepository;
    late StreamController<List<SeguimosCounts>> counts;

    setUp(() {
      rondaRepository = _MockRondaRepository();
      counts = StreamController<List<SeguimosCounts>>.broadcast();
      addTearDown(counts.close);
      when(rondaRepository.watchSeguimosCounts)
          .thenAnswer((_) => counts.stream);
    });

    SeguimosCountsCubit build() =>
        SeguimosCountsCubit(rondaRepository: rondaRepository);

    test('starts loading', () {
      expect(build().state, const SeguimosCountsState());
    });

    blocTest<SeguimosCountsCubit, SeguimosCountsState>(
      "follows every ronda's counts",
      build: build,
      act: (cubit) {
        cubit.subscribe();
        counts.add(const [_counts]);
      },
      expect: () => [
        const SeguimosCountsState(
          status: SeguimosCountsStatus.ready,
          rondas: [_counts],
        ),
      ],
    );

    blocTest<SeguimosCountsCubit, SeguimosCountsState>(
      'fails when they cannot be read, as for anyone but the admin',
      build: build,
      act: (cubit) {
        cubit.subscribe();
        counts.addError(const RsvpFailure(RsvpFailureReason.forbidden));
      },
      expect: () => [
        const SeguimosCountsState(status: SeguimosCountsStatus.failure),
      ],
      errors: () => [isA<RsvpFailure>()],
    );
  });
}
