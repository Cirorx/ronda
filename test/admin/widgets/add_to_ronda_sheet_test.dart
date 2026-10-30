import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(AddToRondaSheet, () {
    late RondaRepository repository;

    setUp(() {
      repository = _MockRondaRepository();
      when(() => repository.rondaCandidates('r1'))
          .thenAnswer((_) async => PilotFixtures.candidates());
    });

    const approved = ProposedRonda(
      seatId: 'el-pinar-sur_mate_sat-afternoon',
      barrioId: 'el-pinar-sur',
      pretextId: 'mate',
      slotId: 'sat-afternoon',
      rondaId: 'r1',
      members: [],
    );

    /// The approved ronda's card, its button tapped: the sheet is open.
    Future<void> open(WidgetTester tester) async {
      await tester.pumpApp(
        RepositoryProvider.value(
          value: repository,
          child: const Scaffold(
            body: SingleChildScrollView(
              child: AdminProposalCard(ronda: approved),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Sumar a esta ronda'));
      await tester.pumpAndSettle();
    }

    Finder button(String label) => find.widgetWithText(OutlinedButton, label);

    testWidgets('shows the ronda, who is in it and who could join', (
      tester,
    ) async {
      await open(tester);

      expect(
        find.text('Sumar a Sábado a la tarde · mate en la rambla'),
        findsOneWidget,
      );
      expect(
        find.text('3 de 6 lugares ocupados · Ana · Beto · Cora'),
        findsOneWidget,
      );
      expect(find.text('Eva'), findsOneWidget);
      expect(find.text('El Pinar Norte · Sábado a la tarde'), findsOneWidget);
      expect(find.text('Ya está en Martes a la noche · truco'), findsOneWidget);
      expect(find.text('No eligió este día y horario'), findsOneWidget);
      expect(find.text('Vive a más de 10 cuadras'), findsOneWidget);
      expect(button('Sumar'), findsOneWidget);
      expect(button('Pasar a esta ronda'), findsOneWidget);
    });

    testWidgets('adds someone and says what came of it', (tester) async {
      when(() => repository.addToRonda(rondaId: 'r1', uid: 'eva')).thenAnswer(
        (_) async => const AddedToRonda(
          rondaId: 'r1',
          uid: 'eva',
          warnings: [CandidateWarning.pretext, CandidateWarning.seat],
        ),
      );
      await open(tester);

      await tester.tap(button('Sumar'));
      await tester.pumpAndSettle();

      expect(
        find.text(
          'Listo: Eva está en la ronda. Lo ve en Mi ronda; no le mandamos '
          'ningún aviso. No eligió esta actividad. Su teléfono no marcó este '
          'lugar como posible.',
        ),
        findsOneWidget,
      );
      verify(() => repository.rondaCandidates('r1')).called(2);
    });

    testWidgets('moves someone only once the admin confirms', (tester) async {
      when(() => repository.addToRonda(rondaId: 'r1', uid: 'gabi', move: true))
          .thenAnswer(
            (_) async => const AddedToRonda(
              rondaId: 'r1',
              uid: 'gabi',
              warnings: [],
              movedFrom: 'r2',
            ),
          );
      await open(tester);

      await tester.ensureVisible(button('Pasar a esta ronda'));
      await tester.tap(button('Pasar a esta ronda'));
      await tester.pumpAndSettle();
      expect(find.text('¿Pasar a Gabi?'), findsOneWidget);
      expect(
        find.text(
          'Deja Martes a la noche · truco. No le llega ningún aviso a nadie.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();
      verifyNever(
        () => repository.addToRonda(
          rondaId: any(named: 'rondaId'),
          uid: any(named: 'uid'),
          move: any(named: 'move'),
        ),
      );

      await tester.tap(button('Pasar a esta ronda'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Pasar'));
      await tester.pumpAndSettle();

      verify(
        () => repository.addToRonda(rondaId: 'r1', uid: 'gabi', move: true),
      ).called(1);
    });

    final refusals = {
      ProposalsFailureReason.full: 'No se sumó: la ronda ya está completa.',
      ProposalsFailureReason.alreadyIn: 'Eva ya está en esta ronda.',
      ProposalsFailureReason.other: 'No se pudo. Probá de nuevo.',
    };
    for (final MapEntry(key: reason, value: message) in refusals.entries) {
      testWidgets('says why when the server refuses: $reason', (tester) async {
        when(() => repository.addToRonda(rondaId: 'r1', uid: 'eva'))
            .thenThrow(ProposalsFailure(reason));
        await open(tester);

        await tester.tap(button('Sumar'));
        await tester.pumpAndSettle();

        expect(find.text(message), findsOneWidget);
      });
    }

    testWidgets('a full ronda says so and adds nobody', (tester) async {
      when(() => repository.rondaCandidates('r1'))
          .thenAnswer((_) async => PilotFixtures.candidates(taken: 6));
      await open(tester);

      expect(
        find.text('No queda lugar: es el máximo para esta actividad.'),
        findsOneWidget,
      );
      expect(tester.widget<OutlinedButton>(button('Sumar')).onPressed, isNull);
    });

    testWidgets('says when nobody else signed up', (tester) async {
      when(() => repository.rondaCandidates('r1'))
          .thenAnswer((_) async => PilotFixtures.candidates(people: const []));
      await open(tester);

      expect(find.text('No hay nadie más anotado para sumar.'), findsOneWidget);
    });

    testWidgets('offers to try again when the read fails', (tester) async {
      when(() => repository.rondaCandidates('r1'))
          .thenThrow(const ProposalsFailure(ProposalsFailureReason.other));
      await open(tester);

      expect(
        find.text('No pudimos leer los anotados. Probá de nuevo.'),
        findsOneWidget,
      );
      when(() => repository.rondaCandidates('r1'))
          .thenAnswer((_) async => PilotFixtures.candidates());
      await tester.tap(find.text('Probar de nuevo'));
      await tester.pumpAndSettle();

      expect(find.text('Eva'), findsOneWidget);
    });

    testWidgets('shows a spinner while reading', (tester) async {
      when(() => repository.rondaCandidates('r1')).thenAnswer(
        (_) => Future.delayed(
          const Duration(seconds: 1),
          PilotFixtures.candidates,
        ),
      );
      await tester.pumpApp(
        RepositoryProvider.value(
          value: repository,
          child: const Scaffold(body: AdminProposalCard(ronda: approved)),
        ),
      );
      await tester.tap(find.text('Sumar a esta ronda'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();
    });

    testWidgets('shows Sumando… on the one being added', (tester) async {
      when(() => repository.addToRonda(rondaId: 'r1', uid: 'eva')).thenAnswer(
        (_) => Future.delayed(
          const Duration(seconds: 1),
          () => const AddedToRonda(rondaId: 'r1', uid: 'eva', warnings: []),
        ),
      );
      await open(tester);

      await tester.tap(button('Sumar'));
      await tester.pump();

      expect(find.text('Sumando…'), findsOneWidget);
      await tester.pump(const Duration(seconds: 1));
      await tester.pumpAndSettle();
    });
  });
}
