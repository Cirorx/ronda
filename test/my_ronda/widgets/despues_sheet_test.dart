import 'dart:async';

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
      final haptics = recordHaptics(tester);
      await save(tester);
      expect(find.text('Completá esto.'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, '¿Dónde?'))
            .decoration
            ?.errorText,
        'Completá esto.',
      );
      expect(haptics, isEmpty);
      verifyNever(
        () => repository.setDespues(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          kind: any(named: 'kind'),
          what: any(named: 'what'),
          where: any(named: 'where'),
          homeOfUid: any(named: 'homeOfUid'),
          address: any(named: 'address'),
        ),
      );

      await tester.enterText(
        find.widgetWithText(TextField, '¿Dónde?'),
        'el café de la esquina',
      );
      await tester.pump();
      expect(find.text('Completá esto.'), findsNothing);
      await save(tester);
      expect(haptics, [commitHaptic]);

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

    testWidgets('says a field is needed once it is left empty', (tester) async {
      await open(tester, week);
      await tester.tap(find.text('En lo de alguien del grupo'));
      await tester.pumpAndSettle();

      String? errorOf(String label) => tester
          .widget<TextField>(find.widgetWithText(TextField, label))
          .decoration
          ?.errorText;

      await tester.tap(find.widgetWithText(TextField, '¿Qué hay?'));
      await tester.pump();
      expect(find.text('Completá esto.'), findsNothing);
      await tester.ensureVisible(find.widgetWithText(TextField, 'Dirección'));
      await tester.tap(find.widgetWithText(TextField, 'Dirección'));
      await tester.pump();
      expect(errorOf('¿Qué hay?'), 'Completá esto.');
      expect(errorOf('Dirección'), isNull);

      await tester.enterText(
        find.widgetWithText(TextField, '¿Qué hay?'),
        'bizcochos',
      );
      await tester.pump();
      expect(errorOf('¿Qué hay?'), isNull);
      expect(errorOf('Dirección'), 'Completá esto.');
    });

    testWidgets('each kind gives under the finger as it is pressed', (
      tester,
    ) async {
      await open(tester, week);

      for (final label in [
        'Esta semana no',
        'Un lugar público cerca',
        'En lo de alguien del grupo',
      ]) {
        expect(
          find.ancestor(
            of: find.text(label),
            matching: find.byType(PressScale),
          ),
          findsOneWidget,
        );
      }
    });

    testWidgets('rings «Guardar» while it saves, and says so', (tester) async {
      final saved = Completer<void>();
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
      ).thenAnswer((_) => saved.future);
      final handle = tester.ensureSemantics();
      await open(tester, week);

      await tester.ensureVisible(find.text('Guardar'));
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      expect(progressIn(DespuesSheet.saveIdentifier), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Guardando…')),
        isSemantics(label: 'Guardando…', isLiveRegion: true),
      );
      await tester.tap(find.text('Guardando…'), warnIfMissed: false);
      saved.complete();
      await tester.pumpAndSettle();
      verify(
        () => repository.setDespues(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          kind: any(named: 'kind'),
          what: any(named: 'what'),
          where: any(named: 'where'),
          homeOfUid: any(named: 'homeOfUid'),
          address: any(named: 'address'),
        ),
      ).called(1);
      handle.dispose();
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

    testWidgets('closes from its close button without saving', (tester) async {
      await open(tester, week);

      await tester.tap(find.byType(CloseButton));
      await tester.pumpAndSettle();

      expect(find.byType(DespuesSheet), findsNothing);
      verifyNever(
        () => repository.setDespues(
          rondaId: any(named: 'rondaId'),
          week: any(named: 'week'),
          kind: any(named: 'kind'),
          what: any(named: 'what'),
          where: any(named: 'where'),
          homeOfUid: any(named: 'homeOfUid'),
          address: any(named: 'address'),
        ),
      );
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
      final handle = tester.ensureSemantics();
      await save(tester);
      expect(
        tester.getSemantics(find.text('No se guardó. Probá de nuevo.')),
        isSemantics(isLiveRegion: true),
      );
      handle.dispose();
    });
  });
}
