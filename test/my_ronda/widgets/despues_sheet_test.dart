import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/my_ronda/widgets/despues_sheet.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  setUpAll(() => registerFallbackValue(DespuesKind.none));

  group(DespuesSheet, () {
    late RondaRepository repository;

    setUp(() {
      repository = _MockRondaRepository();
      when(
        () => repository.setDespues(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          kind: any(named: 'kind'),
          what: any(named: 'what'),
          where: any(named: 'where'),
          homeOfUid: any(named: 'homeOfUid'),
          address: any(named: 'address'),
        ),
      ).thenAnswer((_) async {});
    });

    final week = MyRondaFixtures.week(
      anfitrion: MyRondaFixtures.me,
      going: const [
        GoingNeighbour(uid: 'demo-002', firstName: 'Raúl', brings: []),
        GoingNeighbour(uid: MyRondaFixtures.uid, firstName: 'Ana', brings: []),
        GoingNeighbour(
          uid: 'demo-900',
          firstName: 'Leo',
          brings: [],
          guest: true,
        ),
      ],
    );

    Future<void> open(WidgetTester tester, ThisWeek week) async {
      await tester.pumpApp(
        RepositoryProvider.value(
          value: repository,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => DespuesSheet.show(
                  context,
                  uid: MyRondaFixtures.uid,
                  week: week,
                ),
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    Future<void> save(WidgetTester tester) async {
      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pumpAndSettle();
    }

    testWidgets('"Esta semana no" saves and closes', (tester) async {
      await open(tester, week);

      expect(find.text('¿Qué hay?'), findsNothing);
      await save(tester);

      verify(
        () => repository.setDespues(
          rondaId: 'r1',
          week: '2026-W44',
          kind: DespuesKind.none,
        ),
      ).called(1);
      expect(find.byType(DespuesSheet), findsNothing);
    });

    testWidgets('a public place needs what and where', (tester) async {
      await open(tester, week);
      await tester.tap(find.text('Un lugar público cerca'));
      await tester.pumpAndSettle();

      await tester.enterText(
        find.widgetWithText(TextField, '¿Qué hay?'),
        'bizcochos',
      );
      await save(tester);
      expect(find.text('Completá lo que falta.'), findsOneWidget);

      await tester.enterText(
        find.widgetWithText(TextField, '¿Dónde?'),
        'el café de la esquina',
      );
      await save(tester);

      verify(
        () => repository.setDespues(
          rondaId: 'r1',
          week: '2026-W44',
          kind: DespuesKind.place,
          what: 'bizcochos',
          where: 'el café de la esquina',
        ),
      ).called(1);
    });

    testWidgets("someone else's home goes with whose it is and the address", (
      tester,
    ) async {
      await open(tester, week);
      await tester.tap(find.text('En lo de alguien del grupo'));
      await tester.pumpAndSettle();

      expect(find.text('En mi casa'), findsOneWidget);
      await tester.tap(find.text('En mi casa'));
      await tester.pumpAndSettle();
      expect(find.text('Leo'), findsNothing);
      await tester.tap(find.text('Raúl').last);
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, '¿Qué hay?'),
        'bizcochos',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Dirección'),
        'Av. Central 1234',
      );
      await save(tester);

      verify(
        () => repository.setDespues(
          rondaId: 'r1',
          week: '2026-W44',
          kind: DespuesKind.home,
          what: 'bizcochos',
          homeOfUid: 'demo-002',
          address: 'Av. Central 1234',
        ),
      ).called(1);
    });

    testWidgets('opens on the después already set', (tester) async {
      await open(
        tester,
        MyRondaFixtures.week(
          anfitrion: MyRondaFixtures.me,
          despues: MyRondaFixtures.homeDespues,
        ),
      );

      expect(find.text('Av. Central 1234'), findsWidgets);
      expect(find.text('En mi casa'), findsOneWidget);
    });

    testWidgets('says why the server refused it, and when it failed', (
      tester,
    ) async {
      when(
        () => repository.setDespues(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          kind: any(named: 'kind'),
          what: any(named: 'what'),
          where: any(named: 'where'),
          homeOfUid: any(named: 'homeOfUid'),
          address: any(named: 'address'),
        ),
      ).thenThrow(const HostsFailure(HostsFailureReason.notPublic));
      await open(tester, week);
      await save(tester);
      expect(find.textContaining('Revisá lo que escribiste'), findsOneWidget);

      when(
        () => repository.setDespues(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          kind: any(named: 'kind'),
          what: any(named: 'what'),
          where: any(named: 'where'),
          homeOfUid: any(named: 'homeOfUid'),
          address: any(named: 'address'),
        ),
      ).thenThrow(const HostsFailure(HostsFailureReason.other));
      await save(tester);
      expect(find.text('No se guardó. Probá de nuevo.'), findsOneWidget);
    });
  });
}
