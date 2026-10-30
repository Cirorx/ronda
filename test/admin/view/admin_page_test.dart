import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(AdminPage, () {
    late RondaRepository rondaRepository;

    setUp(() {
      rondaRepository = _MockRondaRepository();
      when(rondaRepository.watchLatestProposal)
          .thenAnswer((_) => Stream.value(AdminFixtures.proposal()));
      when(rondaRepository.watchSeguimosCounts)
          .thenAnswer((_) => Stream.value(const []));
      when(rondaRepository.pilotNumbers)
          .thenAnswer((_) async => PilotFixtures.numbers);
    });

    testWidgets('follows the newest proposal in $AdminView', (tester) async {
      await tester.pumpApp(
        RepositoryProvider.value(
          value: rondaRepository,
          child: const AdminPage(),
        ),
      );
      await tester.pump();

      expect(find.byType(AdminView), findsOneWidget);
      expect(
        tester.element(find.byType(AdminView)).read<RsvpPushCubit>().state,
        const RsvpPushState(),
      );
      expect(find.byType(AdminProposalCard), findsOneWidget);
      // Created when its section is first built, below the fold.
      final seguimos = tester
          .element(find.byType(AdminView))
          .read<SeguimosCountsCubit>();
      await tester.pump();
      expect(
        seguimos.state,
        const SeguimosCountsState(status: SeguimosCountsStatus.ready),
      );
      verify(rondaRepository.watchLatestProposal).called(1);
      verify(rondaRepository.watchSeguimosCounts).called(1);
      final numbers = tester
          .element(find.byType(AdminView))
          .read<PilotNumbersCubit>();
      await tester.pump();
      expect(numbers.state.numbers, PilotFixtures.numbers);
    });
  });
}
