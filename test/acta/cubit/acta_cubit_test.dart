import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:ronda/acta/acta.dart';

class _MockOrganiserRepository extends Mock implements OrganiserRepository;

final _acta = Acta(
  week: '2026-W45',
  lines: [
    ActaLine(
      id: 'a',
      at: DateTime(2026, 11, 4, 18),
      summary: 'Miró el pronóstico.',
      byHost: false,
    ),
  ],
);

void main() {
  group(ActaCubit, () {
    late OrganiserRepository repository;

    setUp(() {
      repository = _MockOrganiserRepository();
      when(() => repository.watchActa('r1'))
          .thenAnswer((_) => Stream.value(_acta));
    });

    ActaCubit build() => ActaCubit(
      uid: 'demo-1',
      rondaId: 'r1',
      organiserRepository: repository,
    );

    test('starts loading', () {
      expect(build().state, const ActaState());
    });

    blocTest<ActaCubit, ActaState>(
      "follows the ronda's acta",
      build: build,
      act: (cubit) => cubit.subscribe(),
      expect: () => [
        const ActaState(),
        ActaState(status: ActaStatus.ready, acta: _acta),
      ],
    );

    blocTest<ActaCubit, ActaState>(
      'fails when it cannot be read',
      setUp: () => when(() => repository.watchActa('r1')).thenAnswer(
        (_) =>
            Stream.error(const OrganiserFailure(OrganiserFailureReason.other)),
      ),
      build: build,
      act: (cubit) => cubit.subscribe(),
      expect: () => const [ActaState(), ActaState(status: ActaStatus.failure)],
      errors: () => [isA<OrganiserFailure>()],
    );

    group('Algo estuvo mal', () {
      final ready = ActaState(status: ActaStatus.ready, acta: _acta);

      blocTest<ActaCubit, ActaState>(
        'records the tap on the shown week, once',
        setUp: () => when(
          () => repository.reportActa(
            rondaId: 'r1',
            uid: 'demo-1',
            week: '2026-W45',
          ),
        ).thenAnswer((_) async {}),
        build: build,
        seed: () => ready,
        act: (cubit) async {
          await cubit.reportTapped();
          await cubit.reportTapped();
        },
        expect: () => [
          ActaState(
            status: ActaStatus.ready,
            acta: _acta,
            report: ActaReport.sending,
          ),
          ActaState(
            status: ActaStatus.ready,
            acta: _acta,
            report: ActaReport.sent,
          ),
        ],
        verify: (_) => verify(
          () => repository.reportActa(
            rondaId: 'r1',
            uid: 'demo-1',
            week: '2026-W45',
          ),
        ).called(1),
      );

      blocTest<ActaCubit, ActaState>(
        'says it was not saved',
        setUp: () => when(
          () => repository.reportActa(
            rondaId: any(named: 'rondaId'),
            uid: any(named: 'uid'),
            week: any(named: 'week'),
          ),
        ).thenThrow(const OrganiserFailure(OrganiserFailureReason.forbidden)),
        build: build,
        seed: () => ready,
        act: (cubit) => cubit.reportTapped(),
        expect: () => [
          ActaState(
            status: ActaStatus.ready,
            acta: _acta,
            report: ActaReport.sending,
          ),
          ActaState(
            status: ActaStatus.ready,
            acta: _acta,
            report: ActaReport.failed,
          ),
        ],
        errors: () => [isA<OrganiserFailure>()],
      );

      blocTest<ActaCubit, ActaState>(
        'does nothing on an empty acta or while it sends',
        build: build,
        act: (cubit) async {
          await cubit.reportTapped();
          cubit.emit(ready.copyWithReport(ActaReport.sending));
          await cubit.reportTapped();
        },
        expect: () => [ready.copyWithReport(ActaReport.sending)],
        verify: (_) => verifyNever(
          () => repository.reportActa(
            rondaId: any(named: 'rondaId'),
            uid: any(named: 'uid'),
            week: any(named: 'week'),
          ),
        ),
      );
    });
  });
}

extension on ActaState {
  ActaState copyWithReport(ActaReport report) =>
      ActaState(status: status, acta: acta, report: report);
}
