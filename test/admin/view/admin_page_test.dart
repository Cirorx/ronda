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
      verify(rondaRepository.watchLatestProposal).called(1);
    });
  });
}
