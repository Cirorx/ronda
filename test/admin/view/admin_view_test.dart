import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockProposalsCubit extends MockCubit<ProposalsState>
    implements ProposalsCubit;

class _MockRsvpPushCubit extends MockCubit<RsvpPushState>
    implements RsvpPushCubit;

class _MockSeguimosCountsCubit extends MockCubit<SeguimosCountsState>
    implements SeguimosCountsCubit;

class _MockPilotNumbersCubit extends MockCubit<PilotNumbersState>
    implements PilotNumbersCubit;

void main() {
  group(AdminView, () {
    late ProposalsCubit cubit;
    late RsvpPushCubit rsvpPushCubit;
    late SeguimosCountsCubit seguimosCountsCubit;
    late PilotNumbersCubit pilotNumbersCubit;

    setUp(() {
      seguimosCountsCubit = _MockSeguimosCountsCubit();
      when(() => seguimosCountsCubit.state).thenReturn(
        const SeguimosCountsState(status: SeguimosCountsStatus.ready),
      );
      pilotNumbersCubit = _MockPilotNumbersCubit();
      when(() => pilotNumbersCubit.state).thenReturn(const PilotNumbersState());
      cubit = _MockProposalsCubit();
      rsvpPushCubit = _MockRsvpPushCubit();
      when(() => rsvpPushCubit.state).thenReturn(const RsvpPushState());
      when(cubit.propose).thenAnswer((_) async {});
      when(cubit.approve).thenAnswer((_) async {});
      when(cubit.undo).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      ProposalsState state, {
      bool reduced = false,
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        reducedMotion(
          reduced: reduced,
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: rsvpPushCubit),
              BlocProvider.value(value: seguimosCountsCubit),
              BlocProvider.value(value: pilotNumbersCubit),
            ],
            child: const AdminView(),
          ),
        ),
      );
    }

    ProposalsState ready(
      Proposal? proposal, {
      ProposalsAction action = ProposalsAction.none,
      bool actionFailed = false,
    }) => ProposalsState(
      status: ProposalsStatus.ready,
      proposal: proposal,
      action: action,
      actionFailed: actionFailed,
    );

    Finder button(String text) => find.ancestor(
      of: find.text(text),
      matching: find.bySubtype<ButtonStyleButton>(),
    );

    group('renders', () {
      testWidgets('a spinner and what it is reading while loading', (
        tester,
      ) async {
        await pump(tester, const ProposalsState());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Leyendo las propuestas…'), findsOneWidget);
      });

      testWidgets('its title in the app bar', (tester) async {
        await pump(tester, ready(null));

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Propuestas'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('its sections spaced and titled, with no rules between', (
        tester,
      ) async {
        await pump(tester, ready(null));

        expect(find.byType(Divider), findsNothing);
      });

      testWidgets('that the screen is for the admin only', (tester) async {
        await pump(
          tester,
          const ProposalsState(status: ProposalsStatus.forbidden),
        );

        expect(
          find.text('Esta pantalla es solo para quien arma las rondas.'),
          findsOneWidget,
        );
        expect(find.bySubtype<ButtonStyleButton>(), findsNothing);
      });

      testWidgets('the empty state with one button', (tester) async {
        await pump(tester, ready(null));

        expect(find.textContaining('Todavía no hay propuesta'), findsOneWidget);
        expect(button('Armar las rondas'), findsOneWidget);
        expect(button('Aprobar y avisarles'), findsNothing);
      });

      testWidgets('a pending proposal: banner, rondas, reason and Aprobar', (
        tester,
      ) async {
        await pump(tester, ready(AdminFixtures.proposal()));

        expect(
          find.text('Nadie recibe nada hasta que lo aprobás.'),
          findsOneWidget,
        );
        expect(find.byType(AdminProposalCard), findsOneWidget);
        await tester.scrollUntilVisible(button('Armarlas de nuevo'), 200);
        expect(
          find.text('2 personas quedan sin lugar por ahora.'),
          findsOneWidget,
        );
        expect(find.text('Por qué no otra opción'), findsOneWidget);
        expect(
          find.text('Alternativa B rechazada: hace caminar 18 cuadras más.'),
          findsOneWidget,
        );
        expect(button('Aprobar y avisarles'), findsOneWidget);
        expect(button('Deshacer'), findsNothing);
      });

      testWidgets('who is left out by name, barrio and slots', (tester) async {
        await pump(
          tester,
          ready(
            AdminFixtures.proposal(
              unseated: const [
                UnseatedPerson(
                  uid: 'eva',
                  firstName: 'Eva',
                  barrioId: 'el-pinar-norte',
                  slotIds: ['sat-afternoon', 'tue-evening'],
                  pretextIds: ['mate'],
                ),
                UnseatedPerson(
                  uid: 'x',
                  firstName: 'Xime',
                  barrioId: 'pocitos',
                  slotIds: ['someday'],
                  pretextIds: [],
                ),
              ],
            ),
          ),
        );
        await tester.scrollUntilVisible(find.text('Eva'), 200);

        expect(
          find.text('El Pinar Norte · Sábado a la tarde, Martes a la noche'),
          findsOneWidget,
        );
        expect(find.text('pocitos · someday'), findsOneWidget);
      });

      testWidgets("the pilot's numbers at the bottom", (tester) async {
        await pump(tester, ready(AdminFixtures.proposal()));

        await tester.scrollUntilVisible(find.byType(PilotNumbersSection), 200);

        expect(find.byType(PilotNumbersSection), findsOneWidget);
      });

      testWidgets('no Aprobar and no reason when nobody could be seated', (
        tester,
      ) async {
        await pump(
          tester,
          ready(AdminFixtures.proposal(rondas: const [], rejectedReason: null)),
        );

        expect(find.text('Por qué no otra opción'), findsNothing);
        expect(button('Aprobar y avisarles'), findsNothing);
        expect(button('Armarlas de nuevo'), findsOneWidget);
      });

      testWidgets('an approved proposal with Deshacer and no Aprobar', (
        tester,
      ) async {
        await pump(
          tester,
          ready(AdminFixtures.proposal(status: ProposalStatus.approved)),
        );

        expect(
          find.text('Aprobado. Les llega el martes a las 19.'),
          findsOneWidget,
        );
        expect(
          find.text('Nadie recibe nada hasta que lo aprobás.'),
          findsNothing,
        );
        expect(button('Deshacer'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('Por qué no otra opción'),
          200,
        );
        expect(button('Aprobar y avisarles'), findsNothing);
        expect(button('Armarlas de nuevo'), findsNothing);
      });

      testWidgets('that the solver is running', (tester) async {
        await pump(tester, ready(null, action: ProposalsAction.proposing));

        final proposing = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Armando las rondas…'),
        );
        expect(proposing.onPressed, isNull);
      });

      testWidgets('that the last step failed', (tester) async {
        await pump(tester, ready(null, actionFailed: true));

        expect(find.text('No se pudo. Probá de nuevo.'), findsOneWidget);
      });
    });

    group('calls', () {
      testWidgets('propose from the empty state', (tester) async {
        await pump(tester, ready(null));

        await tester.tap(button('Armar las rondas'));

        verify(cubit.propose).called(1);
      });

      testWidgets('approve on Aprobar y avisarles', (tester) async {
        await pump(tester, ready(AdminFixtures.proposal()));

        final approve = button('Aprobar y avisarles');
        await tester.scrollUntilVisible(approve, 200);
        await tester.tap(approve);

        verify(cubit.approve).called(1);
      });

      testWidgets('undo on Deshacer', (tester) async {
        await pump(
          tester,
          ready(AdminFixtures.proposal(status: ProposalStatus.approved)),
        );

        await tester.tap(button('Deshacer'));

        verify(cubit.undo).called(1);
      });

      testWidgets('subscribe again after a failed read', (tester) async {
        await pump(
          tester,
          const ProposalsState(status: ProposalsStatus.failure),
        );
        expect(
          find.text('No pudimos leer las propuestas. Probá de nuevo.'),
          findsOneWidget,
        );

        await tester.tap(button('Probar de nuevo'));

        verify(cubit.subscribe).called(1);
      });
    });

    group('feels', () {
      late StreamController<ProposalsState> states;

      setUp(() => states = StreamController<ProposalsState>());

      // Not awaited: a stream nobody listened to never reports it closed.
      tearDown(() => unawaited(states.close()));

      Future<void> pumpListening(
        WidgetTester tester,
        ProposalsState initial, {
        bool reduced = false,
      }) {
        whenListen(cubit, states.stream, initialState: initial);
        return pump(tester, initial, reduced: reduced);
      }

      Finder settlingIn(String text) => find.ancestor(
        of: find.text(text),
        matching: find.byType(ScaleTransition),
      );

      const nobodyYet = 'Nadie recibe nada hasta que lo aprobás.';
      const approved = 'Aprobado. Les llega el martes a las 19.';

      for (final (label, state, scroll) in [
        ('Armar las rondas', ready(null), false),
        ('Aprobar y avisarles', ready(AdminFixtures.proposal()), true),
        (
          'Deshacer',
          ready(AdminFixtures.proposal(status: ProposalStatus.approved)),
          false,
        ),
      ]) {
        testWidgets('$label as a commit, with one light tap', (tester) async {
          final haptics = recordHaptics(tester);
          await pump(tester, state);

          if (scroll) await tester.scrollUntilVisible(button(label), 200);
          await tester.tap(button(label));

          expect(haptics, ['HapticFeedbackType.lightImpact']);
        });
      }

      testWidgets('nothing while a step runs and the buttons wait', (
        tester,
      ) async {
        final haptics = recordHaptics(tester);
        await pump(
          tester,
          ready(
            AdminFixtures.proposal(status: ProposalStatus.approved),
            action: ProposalsAction.undoing,
          ),
        );

        await tester.tap(button('Deshacer'), warnIfMissed: false);

        expect(haptics, isEmpty);
        verifyNever(cubit.undo);
      });

      testWidgets('the approval settling in over the pending note', (
        tester,
      ) async {
        await pumpListening(tester, ready(AdminFixtures.proposal()));

        states.add(
          ready(AdminFixtures.proposal(status: ProposalStatus.approved)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text(nobodyYet), findsOneWidget);
        expect(settlingIn(approved), findsWidgets);
        await tester.pumpAndSettle();
        expect(find.text(nobodyYet), findsNothing);
        expect(button('Deshacer'), findsOneWidget);
      });

      testWidgets('only a cross-fade with reduced motion', (tester) async {
        await pumpListening(
          tester,
          ready(AdminFixtures.proposal(status: ProposalStatus.approved)),
          reduced: true,
        );

        states.add(ready(AdminFixtures.proposal()));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text(approved), findsOneWidget);
        expect(settlingIn(nobodyYet), findsNothing);
        expect(
          find.ancestor(
            of: find.text(nobodyYet),
            matching: find.byType(FadeTransition),
          ),
          findsWidgets,
        );
        await tester.pumpAndSettle();
        expect(find.text(approved), findsNothing);
      });

      testWidgets('the approval read out once it lands', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpListening(tester, ready(AdminFixtures.proposal()));

        states.add(
          ready(AdminFixtures.proposal(status: ProposalStatus.approved)),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          tester.getSemantics(find.text(approved)),
          isSemantics(isLiveRegion: true),
        );
        expect(find.semantics.byLabel(nobodyYet), findsNothing);
        await tester.pumpAndSettle();
        semantics.dispose();
      });

      for (final (what, state, text) in [
        ('the loading line', const ProposalsState(), 'Leyendo las propuestas…'),
        (
          'a failed read',
          const ProposalsState(status: ProposalsStatus.failure),
          'No pudimos leer las propuestas. Probá de nuevo.',
        ),
        (
          'a failed step',
          ready(null, actionFailed: true),
          'No se pudo. Probá de nuevo.',
        ),
      ]) {
        testWidgets('$what read out as it appears', (tester) async {
          final semantics = tester.ensureSemantics();
          await pump(tester, state);

          expect(
            tester.getSemantics(find.text(text)),
            isSemantics(isLiveRegion: true),
          );
          semantics.dispose();
        });
      }

      testWidgets('each section title as a heading', (tester) async {
        final semantics = tester.ensureSemantics();
        await pump(tester, ready(null));

        expect(
          tester.getSemantics(find.text('El ¿Venís? de esta semana')),
          isSemantics(isHeader: true),
        );
        semantics.dispose();
      });
    });

    testWidgets('reads in English', (tester) async {
      when(() => cubit.state).thenReturn(ready(AdminFixtures.proposal()));
      await tester.pumpApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: rsvpPushCubit),
            BlocProvider.value(value: seguimosCountsCubit),
          ],
          child: const AdminView(),
        ),
        locale: const Locale('en'),
      );

      expect(
        find.text('Nobody gets anything until you approve it.'),
        findsOneWidget,
      );
      expect(find.text('Marta and their guest go together'), findsOneWidget);
    });

    testWidgets('ends with the weekly RSVP and the ¿seguimos? counts', (
      tester,
    ) async {
      await pump(tester, ready(null));

      expect(find.byType(RsvpPushSection), findsOneWidget);
      await tester.dragUntilVisible(
        find.byType(SeguimosCountsSection),
        find.byType(ListView),
        const Offset(0, -200),
      );
      expect(find.byType(SeguimosCountsSection), findsOneWidget);
    });
  });
}
