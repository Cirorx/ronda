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

void main() {
  group(AdminView, () {
    late ProposalsCubit cubit;
    late RsvpPushCubit rsvpPushCubit;
    late SeguimosCountsCubit seguimosCountsCubit;

    setUp(() {
      seguimosCountsCubit = _MockSeguimosCountsCubit();
      when(() => seguimosCountsCubit.state).thenReturn(
        const SeguimosCountsState(status: SeguimosCountsStatus.ready),
      );
      cubit = _MockProposalsCubit();
      rsvpPushCubit = _MockRsvpPushCubit();
      when(() => rsvpPushCubit.state).thenReturn(const RsvpPushState());
      when(cubit.propose).thenAnswer((_) async {});
      when(cubit.approve).thenAnswer((_) async {});
      when(cubit.undo).thenAnswer((_) async {});
    });

    Future<void> pump(WidgetTester tester, ProposalsState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: rsvpPushCubit),
            BlocProvider.value(value: seguimosCountsCubit),
          ],
          child: const AdminView(),
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
      testWidgets('a spinner while loading', (tester) async {
        await pump(tester, const ProposalsState());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
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
