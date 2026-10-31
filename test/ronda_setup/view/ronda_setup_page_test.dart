import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/attendance/attendance.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/ronda_setup/ronda_setup.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockRondaRepository extends Mock implements RondaRepository;

class _MockRondaSetupCubit extends MockCubit<RondaSetupState>
    implements RondaSetupCubit;

const _ready = RondaSetupState(
  status: RondaSetupStatus.ready,
  rondas: [SetupFixtures.bare],
);

void main() {
  group(RondaSetupPage, () {
    testWidgets('reads every ronda', (tester) async {
      final repository = _MockRondaRepository();
      when(repository.rondaSetups)
          .thenAnswer((_) async => const [SetupFixtures.bare]);

      await tester.pumpApp(
        RepositoryProvider<RondaRepository>.value(
          value: repository,
          child: const RondaSetupPage(),
        ),
      );
      await tester.pump();

      expect(find.text('Lugar, hora y anfitriones'), findsOneWidget);
      expect(
        find.text('Jueves a la tarde · Mate en la rambla'),
        findsOneWidget,
      );
    });
  });

  group(RondaSetupView, () {
    late RondaSetupCubit cubit;

    setUp(() {
      cubit = _MockRondaSetupCubit();
      when(cubit.load).thenAnswer((_) async {});
      when(
        () => cubit.save(
          rondaId: any(named: 'rondaId'),
          placeName: any(named: 'placeName'),
          placeLandmark: any(named: 'placeLandmark'),
          hour: any(named: 'hour'),
          anfitrionUid: any(named: 'anfitrionUid'),
          colaUid: any(named: 'colaUid'),
        ),
      ).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, RondaSetupState state) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpWidget(const SizedBox());
      await tester.pumpApp(
        BlocProvider.value(value: cubit, child: const RondaSetupView()),
      );
      tester.view.physicalSize = const Size(360, 2400);
      await tester.pump();
    }

    testWidgets('a ronda approval left bare says what is still to set', (
      tester,
    ) async {
      await pump(tester, _ready);

      expect(find.text('El Pinar Sur'), findsOneWidget);
      expect(find.text('Lugar y hora a confirmar'), findsOneWidget);
      expect(find.text('Abre: nadie · Cierra: nadie'), findsOneWidget);
      expect(find.textContaining('Quién vino'), findsNothing);
    });

    testWidgets('says how the upcoming "¿Abrís vos?" is going', (tester) async {
      RondaSetup withHandoff(String id, HandoffStep step) => RondaSetup(
        rondaId: id,
        pretextId: 'mate',
        barrioId: 'el-pinar-sur',
        slotDayId: 'thu',
        slotBandId: 'afternoon',
        members: const [],
        handoff: HandoffSummary(
          date: DateTime(2026, 11, 5),
          step: step,
          fromName: 'Mirta',
          takenName: step == HandoffStep.taken ? 'Facu' : null,
        ),
      );
      await pump(
        tester,
        RondaSetupState(
          status: RondaSetupStatus.ready,
          rondas: [
            withHandoff('a', HandoffStep.cola),
            withHandoff('b', HandoffStep.taken),
            withHandoff('c', HandoffStep.nobody),
            withHandoff('d', HandoffStep.back),
          ],
        ),
      );

      expect(
        find.text('Buscando quién abre el 5/11: Mirta no puede.'),
        findsOneWidget,
      );
      expect(find.text('El 5/11 abre Facu en lugar de Mirta.'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('Nadie confirmó que abre el 5/11: Mirta no puede.'),
        200,
      );
      expect(
        find.text('Nadie confirmó que abre el 5/11: Mirta no puede.'),
        findsOneWidget,
      );
    });

    testWidgets('a ronda set up shows all three and its latest roll', (
      tester,
    ) async {
      await pump(
        tester,
        RondaSetupState(
          status: RondaSetupStatus.ready,
          rondas: [
            SetupFixtures.set,
            const RondaSetup(
              rondaId: 'r2',
              pretextId: 'truco',
              barrioId: 'nowhere',
              slotDayId: 'tue',
              slotBandId: 'evening',
              members: [],
              hour: '19:30',
            ),
            const RondaSetup(
              rondaId: 'r3',
              pretextId: 'truco',
              barrioId: 'nowhere',
              slotDayId: 'tue',
              slotBandId: 'evening',
              members: [],
              placeName: 'Club Lagomar',
            ),
          ],
        ),
      );

      expect(
        find.text('Jueves a las 16:00 · Mate en la rambla'),
        findsOneWidget,
      );
      expect(
        find.text('Frente al quiosco · al lado de la parada'),
        findsOneWidget,
      );
      expect(find.text('Abre: Mirta · Cierra: Jorge'), findsOneWidget);
      expect(
        find.text('Quién vino el 5/11 · Anotaste a 1 de 3.'),
        findsOneWidget,
      );
      expect(find.text('nowhere'), findsNWidgets(2));
      expect(find.text('Lugar a confirmar'), findsOneWidget);
      expect(find.text('Club Lagomar'), findsOneWidget);
    });

    testWidgets('opens the latest roll under /admin', (tester) async {
      when(() => cubit.state).thenReturn(
        RondaSetupState(
          status: RondaSetupStatus.ready,
          rondas: [SetupFixtures.set],
        ),
      );
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                BlocProvider.value(value: cubit, child: const RondaSetupView()),
          ),
          GoRoute(
            path: '/admin/${AttendancePage.adminSegment}',
            builder: (_, state) => Text('roll ${state.pathParameters['week']}'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          locale: rioplatense,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );

      await tester.tap(find.textContaining('Quién vino el'));
      await tester.pumpAndSettle();

      expect(find.text('roll 2026-W45'), findsOneWidget);
    });

    testWidgets('waits, is forbidden, says when there are none, retries', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pump(tester, const RondaSetupState());
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(
        tester.getSemantics(find.text('Leyendo las rondas…')),
        isSemantics(isLiveRegion: true),
      );

      await pump(
        tester,
        const RondaSetupState(status: RondaSetupStatus.forbidden),
      );
      expect(find.text('Lugar, hora y anfitriones'), findsOneWidget);

      await pump(tester, const RondaSetupState(status: RondaSetupStatus.ready));
      expect(find.text('Todavía no hay rondas.'), findsOneWidget);

      await pump(
        tester,
        const RondaSetupState(status: RondaSetupStatus.failure),
      );
      expect(
        tester.getSemantics(
          find.text('No pudimos leer las rondas. Probá de nuevo.'),
        ),
        isSemantics(isLiveRegion: true),
      );
      await tester.tap(find.text('Probar de nuevo'));
      verify(cubit.load).called(1);
      semantics.dispose();
    });

    testWidgets('says where it is and goes back to the admin screen', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(_ready);
      await tester.pumpApp(
        Builder(
          builder: (context) => TextButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => BlocProvider.value(
                  value: cubit,
                  child: const RondaSetupView(),
                ),
              ),
            ),
            child: const Text('Propuestas'),
          ),
        ),
      );
      await tester.tap(find.text('Propuestas'));
      await tester.pumpAndSettle();

      expect(
        find.descendant(
          of: find.byType(AppBar),
          matching: find.text('Lugar, hora y anfitriones'),
        ),
        findsOneWidget,
      );
      await tester.tap(find.byType(BackButton));
      await tester.pumpAndSettle();
      expect(find.byType(RondaSetupView), findsNothing);
    });

    group(RondaSetupSheet, () {
      Future<void> open(WidgetTester tester, RondaSetupState state) async {
        await pump(tester, state);
        await tester.tap(find.text('Cambiar'));
        await tester.pumpAndSettle();
      }

      Future<void> pick(WidgetTester tester, String field, String item) async {
        await tester.tap(find.widgetWithText(InputDecorator, field));
        await tester.pumpAndSettle();
        await tester.tap(find.text(item).last);
        await tester.pumpAndSettle();
      }

      testWidgets('saves the place, the hour and the hosts, then closes', (
        tester,
      ) async {
        final states = StreamController<RondaSetupState>();
        addTearDown(states.close);
        whenListen(cubit, states.stream, initialState: _ready);
        when(
          () => cubit.save(
            rondaId: any(named: 'rondaId'),
            placeName: any(named: 'placeName'),
            placeLandmark: any(named: 'placeLandmark'),
            hour: any(named: 'hour'),
            anfitrionUid: any(named: 'anfitrionUid'),
            colaUid: any(named: 'colaUid'),
          ),
        ).thenAnswer((_) async {
          states
            ..add(
              const RondaSetupState(
                status: RondaSetupStatus.ready,
                rondas: [SetupFixtures.bare],
                saving: true,
              ),
            )
            ..add(_ready);
        });
        await tester.pumpWidget(const SizedBox());
        await tester.pumpApp(
          BlocProvider.value(value: cubit, child: const RondaSetupView()),
        );
        tester.view.physicalSize = const Size(360, 2400);
        await tester.pump();
        await tester.tap(find.text('Cambiar'));
        await tester.pumpAndSettle();

        await tester.enterText(
          find.widgetWithText(TextField, 'Lugar público'),
          '  Frente al quiosco ',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Cómo encontrarlo (si hace falta)'),
          ' ',
        );
        await pick(tester, 'Hora', '16:30');
        await pick(tester, 'Abre (llega primero)', 'Mirta');
        await pick(tester, 'Cierra (se queda al final)', 'Jorge');
        await tester.ensureVisible(find.text('Guardar'));
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        verify(
          () => cubit.save(
            rondaId: 'r1',
            placeName: 'Frente al quiosco',
            hour: '16:30',
            anfitrionUid: 'demo-101',
            colaUid: 'demo-102',
          ),
        ).called(1);
        expect(find.byType(RondaSetupSheet), findsNothing);
        verify(cubit.sheetClosed).called(1);
      });

      testWidgets('starts from what is set and can take it all away', (
        tester,
      ) async {
        await open(
          tester,
          RondaSetupState(
            status: RondaSetupStatus.ready,
            rondas: [SetupFixtures.set],
          ),
        );

        expect(find.text('Frente al quiosco'), findsWidgets);
        await tester.enterText(
          find.widgetWithText(TextField, 'Lugar público'),
          '',
        );
        await tester.enterText(
          find.widgetWithText(TextField, 'Cómo encontrarlo (si hace falta)'),
          '',
        );
        await pick(tester, 'Hora', 'Sin hora');
        await pick(tester, 'Abre (llega primero)', 'nadie');
        await pick(tester, 'Cierra (se queda al final)', 'nadie');
        await tester.ensureVisible(find.text('Guardar'));
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        verify(() => cubit.save(rondaId: 'r1')).called(1);
      });

      String? errorOn(WidgetTester tester, String label) => tester
          .widget<InputDecorator>(find.widgetWithText(InputDecorator, label))
          .decoration
          .errorText;

      testWidgets('one person can not open and close: said on both pickers', (
        tester,
      ) async {
        final haptics = recordHaptics(tester);
        await open(tester, _ready);

        await pick(tester, 'Abre (llega primero)', 'Ana');
        await pick(tester, 'Cierra (se queda al final)', 'Ana');

        const sameHost = 'Abre y cierra tienen que ser dos personas distintas.';
        expect(errorOn(tester, 'Abre (llega primero)'), sameHost);
        expect(errorOn(tester, 'Cierra (se queda al final)'), sameHost);
        expect(find.byType(NoteBanner), findsNothing);
        final save = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Guardar'),
        );
        expect(save.onPressed, isNull);
        await tester.ensureVisible(find.text('Guardar'));
        await tester.tap(find.text('Guardar'), warnIfMissed: false);
        expect(haptics, isEmpty);

        await pick(tester, 'Cierra (se queda al final)', 'nadie');
        expect(errorOn(tester, 'Abre (llega primero)'), isNull);
        expect(errorOn(tester, 'Cierra (se queda al final)'), isNull);
      });

      testWidgets('Guardar as a commit, with one light tap', (tester) async {
        final haptics = recordHaptics(tester);
        await open(tester, _ready);

        await tester.ensureVisible(find.text('Guardar'));
        await tester.tap(find.text('Guardar'));
        await tester.pump();

        expect(haptics, ['HapticFeedbackType.lightImpact']);
      });

      testWidgets('its title as a heading, and a way out', (tester) async {
        final semantics = tester.ensureSemantics();
        await open(tester, _ready);

        expect(
          tester.getSemantics(
            find.descendant(
              of: find.byType(RondaSetupSheet),
              matching: find.text('Jueves a la tarde · Mate en la rambla'),
            ),
          ),
          isSemantics(isHeader: true),
        );
        await tester.tap(find.byTooltip('Cerrar'));
        await tester.pumpAndSettle();
        expect(find.byType(RondaSetupSheet), findsNothing);
        verify(cubit.sheetClosed).called(1);
        semantics.dispose();
      });

      testWidgets('stays open and says why when it was not saved', (
        tester,
      ) async {
        when(
          () => cubit.save(
            rondaId: any(named: 'rondaId'),
            placeName: any(named: 'placeName'),
            placeLandmark: any(named: 'placeLandmark'),
            hour: any(named: 'hour'),
            anfitrionUid: any(named: 'anfitrionUid'),
            colaUid: any(named: 'colaUid'),
          ),
        ).thenAnswer((_) async {});
        await open(
          tester,
          const RondaSetupState(
            status: RondaSetupStatus.ready,
            rondas: [SetupFixtures.bare],
            saveFailure: HostsFailureReason.notPublic,
          ),
        );

        const notPublic =
            'Eso parece una casa o una dirección. La ronda se junta solo en '
            'lugares públicos: escribí el lugar, sin número de puerta.';
        expect(errorOn(tester, 'Lugar público'), notPublic);
        expect(find.byType(NoteBanner), findsNothing);

        await tester.enterText(
          find.widgetWithText(TextField, 'Lugar público'),
          'Frente al quiosco',
        );
        await tester.pump();
        expect(errorOn(tester, 'Lugar público'), isNull);

        await tester.ensureVisible(find.text('Guardar'));
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();
        expect(find.byType(RondaSetupSheet), findsOneWidget);
      });

      testWidgets('says a save failed for anything else, and while saving', (
        tester,
      ) async {
        await open(
          tester,
          const RondaSetupState(
            status: RondaSetupStatus.ready,
            rondas: [SetupFixtures.bare],
            saveFailure: HostsFailureReason.other,
            saving: true,
          ),
        );

        final semantics = tester.ensureSemantics();
        await tester.pump();
        expect(
          tester.getSemantics(find.text('No se guardó. Probá de nuevo.')),
          isSemantics(isLiveRegion: true),
        );
        expect(errorOn(tester, 'Lugar público'), isNull);
        expect(find.text('Guardando…'), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('drops a host who is no longer a member', (tester) async {
        await open(
          tester,
          const RondaSetupState(
            status: RondaSetupStatus.ready,
            rondas: [
              RondaSetup(
                rondaId: 'r1',
                pretextId: 'mate',
                barrioId: 'el-pinar-sur',
                slotDayId: 'thu',
                slotBandId: 'afternoon',
                members: SetupFixtures.members,
                hour: '13:00',
                anfitrionUid: 'demo-999',
              ),
            ],
          ),
        );

        await tester.ensureVisible(find.text('Guardar'));
        await tester.tap(find.text('Guardar'));
        await tester.pumpAndSettle();

        verify(() => cubit.save(rondaId: 'r1', hour: '13:00')).called(1);
      });
    });
  });

  group(RondaSetupLink, () {
    testWidgets('opens the setup screen', (tester) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) =>
                Scaffold(appBar: AppBar(actions: const [RondaSetupLink()])),
          ),
          GoRoute(
            path: RondaSetupPage.path,
            builder: (_, _) => const Text('setup'),
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          locale: rioplatense,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );

      await tester.tap(find.byTooltip('Lugar, hora y anfitriones'));
      await tester.pumpAndSettle();

      expect(find.text('setup'), findsOneWidget);
    });
  });
}
