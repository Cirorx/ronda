import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/small_plan/small_plan.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

import '../../helpers/helpers.dart';

class _MockSmallPlanCubit extends MockCubit<SmallPlanState>
    implements SmallPlanCubit;

class _MockSharedPlansCubit extends MockCubit<SharedPlansState>
    implements SharedPlansCubit;

class _MockSmallPlanRepository extends Mock implements SmallPlanRepository;

void main() {
  group(SmallPlanSection, () {
    late SmallPlanCubit cubit;
    late SharedPlansCubit sharedCubit;
    final walk = SmallPlan(
      kind: SmallPlanKind.walk,
      at: DateTime(2026, 11, 3, 19),
      place: 'la Rambla',
    );

    setUpAll(() {
      registerFallbackValue(
        SmallPlan(kind: SmallPlanKind.walk, at: DateTime(2026)),
      );
    });

    setUp(() {
      cubit = _MockSmallPlanCubit();
      sharedCubit = _MockSharedPlansCubit();
      when(() => sharedCubit.state).thenReturn(const SharedPlansState());
      when(() => sharedCubit.planChanged()).thenAnswer((_) async {});
      when(() => cubit.notThisWeek()).thenAnswer((_) async {});
      when(() => cubit.followUpAnswered()).thenAnswer((_) async {});
      when(() => cubit.calendarTapped(any())).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester,
      SmallPlanState state, {
      Locale locale = rioplatense,
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: cubit),
            BlocProvider.value(value: sharedCubit),
          ],
          child: const Scaffold(body: SmallPlanSection(uid: 'uid')),
        ),
        locale: locale,
      );
    }

    testWidgets('shows nothing while the phone is read, or when the offer '
        'was put off', (tester) async {
      await pump(tester, const SmallPlanState());
      expect(find.byType(Card), findsNothing);

      await pump(tester, const SmallPlanState(status: SmallPlanStatus.ready));
      expect(find.byType(Card), findsNothing);
    });

    testWidgets('says when the phone could not be read', (tester) async {
      await pump(tester, const SmallPlanState(status: SmallPlanStatus.failure));

      expect(
        find.text('No pudimos leer tu plan en este teléfono.'),
        findsOneWidget,
      );
    });

    group('the offer', () {
      const offer = SmallPlanState(
        status: SmallPlanStatus.ready,
        card: SmallPlanOffer(),
      );

      testWidgets('asks once a week, in voseo', (tester) async {
        await pump(tester, offer);

        expect(
          find.text('¿Querés proponerte algo chico para esta semana?'),
          findsOneWidget,
        );
        expect(find.text('Elegir algo'), findsOneWidget);
        expect(find.text('Esta semana no'), findsOneWidget);
      });

      testWidgets('puts it off for the week', (tester) async {
        await pump(tester, offer);

        await tester.tap(find.text('Esta semana no'));

        verify(() => cubit.notThisWeek()).called(1);
      });

      testWidgets('replies plainly after the follow-up', (tester) async {
        await pump(tester, offer.copyWith(replied: true));

        expect(find.text('Anotado. Gracias por contarnos.'), findsOneWidget);
      });

      testWidgets('says when the plan could not be kept', (tester) async {
        await pump(tester, offer.copyWith(saveFailed: true));

        expect(
          find.text('No pudimos guardar tu plan en este teléfono.'),
          findsOneWidget,
        );
      });

      testWidgets('opens the choice, and keeps the plan it closes with', (
        tester,
      ) async {
        final repository = _MockSmallPlanRepository();
        when(repository.suggestions).thenAnswer(
          (_) async => [
            SmallPlanSuggestion(
              id: 'call-1',
              kind: SmallPlanKind.call,
              at: DateTime(2026, 11, 3, 18),
              outdoor: false,
            ),
          ],
        );
        when(() => cubit.planChosen(any())).thenAnswer((_) async {});
        when(() => cubit.state).thenReturn(offer);
        await tester.pumpApp(
          RepositoryProvider<SmallPlanRepository>.value(
            value: repository,
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: cubit),
                BlocProvider.value(value: sharedCubit),
              ],
              child: const Scaffold(body: SmallPlanSection(uid: 'uid')),
            ),
          ),
        );

        await tester.tap(find.text('Elegir algo'));
        await tester.pumpAndSettle();
        await tester.tap(
          find.text('Llamar a alguien con quien hace tiempo no hablás'),
        );
        await tester.pumpAndSettle();

        verify(
          () => cubit.planChosen(
            SmallPlan(kind: SmallPlanKind.call, at: DateTime(2026, 11, 3, 18)),
          ),
        ).called(1);
        // What was opened to the ronda was the old plan.
        verify(() => sharedCubit.planChanged()).called(1);
      });

      testWidgets('keeps nothing when the sheet closes without a plan', (
        tester,
      ) async {
        final repository = _MockSmallPlanRepository();
        when(repository.suggestions).thenAnswer((_) async => const []);
        when(() => cubit.state).thenReturn(offer);
        await tester.pumpApp(
          RepositoryProvider<SmallPlanRepository>.value(
            value: repository,
            child: MultiBlocProvider(
              providers: [
                BlocProvider.value(value: cubit),
                BlocProvider.value(value: sharedCubit),
              ],
              child: const Scaffold(body: SmallPlanSection(uid: 'uid')),
            ),
          ),
        );

        await tester.tap(find.text('Elegir algo'));
        await tester.pumpAndSettle();
        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        verifyNever(() => cubit.planChosen(any()));
        verifyNever(() => sharedCubit.planChanged());
      });
    });

    group('for a member still waiting for a group', () {
      // No ronda, so no SharedPlansCubit above the section.
      Future<void> pumpWaiting(
        WidgetTester tester,
        SmallPlanState state, {
        Locale locale = rioplatense,
      }) {
        when(() => cubit.state).thenReturn(state);
        return tester.pumpApp(
          BlocProvider.value(
            value: cubit,
            child: const Scaffold(
              body: SmallPlanSection(uid: 'uid', waiting: true),
            ),
          ),
          locale: locale,
        );
      }

      testWidgets('offers it with its own title, in voseo', (tester) async {
        await pumpWaiting(
          tester,
          const SmallPlanState(
            status: SmallPlanStatus.ready,
            card: SmallPlanOffer(),
          ),
        );

        expect(
          find.text(
            'Mientras armamos tu grupo, ¿te proponés algo chico para esta '
            'semana?',
          ),
          findsOneWidget,
        );
        expect(find.text('Elegir algo'), findsOneWidget);
      });

      testWidgets('offers it in English', (tester) async {
        await pumpWaiting(
          tester,
          const SmallPlanState(
            status: SmallPlanStatus.ready,
            card: SmallPlanOffer(),
          ),
          locale: const Locale('en'),
        );

        expect(
          find.text(
            'While we put your group together, how about something small '
            'this week?',
          ),
          findsOneWidget,
        );
      });

      testWidgets('shows the plan without a switch to tell the ronda', (
        tester,
      ) async {
        await pumpWaiting(
          tester,
          SmallPlanState(
            status: SmallPlanStatus.ready,
            card: SmallPlanSet(walk),
          ),
        );

        expect(find.text('Agregar al calendario'), findsOneWidget);
        expect(find.text('Avisarle a la ronda'), findsNothing);
      });
    });

    group("this week's plan", () {
      late SmallPlanState planned;

      setUp(() {
        planned = SmallPlanState(
          status: SmallPlanStatus.ready,
          card: SmallPlanSet(walk),
        );
      });

      testWidgets('shows the plan as a sentence', (tester) async {
        await pump(tester, planned);

        expect(find.text('Tu algo chico de esta semana'), findsOneWidget);
        expect(
          find.text('Caminar 30 minutos por la Rambla, el martes a las 19:00.'),
          findsOneWidget,
        );
        expect(find.text('Agregar al calendario'), findsOneWidget);
        expect(find.text('Cambiar'), findsOneWidget);
      });

      testWidgets('adds it to the calendar under the words of the '
          'plan', (tester) async {
        await pump(tester, planned);

        await tester.tap(find.text('Agregar al calendario'));

        verify(() => cubit.calendarTapped('Caminar 30 minutos por la Rambla'))
            .called(1);
      });

      for (final MapEntry(:key, :value) in {
        SmallPlanCalendar.opened:
            'Se abrió tu calendario con el plan. Guardalo ahí.',
        SmallPlanCalendar.downloaded:
            'Bajamos un archivo para tu calendario. '
            'Abrilo para agregar el plan.',
        SmallPlanCalendar.failed: 'No pudimos abrir tu calendario.',
      }.entries) {
        testWidgets('says what the calendar did: $key', (tester) async {
          await pump(tester, planned.copyWith(calendar: key));

          expect(find.text(value), findsOneWidget);
        });
      }

      testWidgets('offers "Avisarle a la ronda" under the plan', (
        tester,
      ) async {
        when(
          () => sharedCubit.state,
        ).thenReturn(const SharedPlansState(status: SharedPlansStatus.ready));
        final ahead = SmallPlan(
          kind: SmallPlanKind.walk,
          at: DateTime.now().add(const Duration(days: 1)),
          place: 'la Rambla',
        );

        await pump(
          tester,
          SmallPlanState(
            status: SmallPlanStatus.ready,
            card: SmallPlanSet(ahead),
          ),
        );

        expect(find.text('Avisarle a la ronda'), findsOneWidget);
      });

      testWidgets('gives Maestro a handle on both buttons', (tester) async {
        final handle = tester.ensureSemantics();
        await pump(tester, planned);

        expect(
          find.bySemanticsIdentifier(SmallPlanSection.calendarIdentifier),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(SmallPlanSection.changeIdentifier),
          findsOneWidget,
        );
        handle.dispose();
      });
    });

    group("last week's question", () {
      late SmallPlanState asked;

      setUp(() {
        asked = SmallPlanState(
          status: SmallPlanStatus.ready,
          card: SmallPlanFollowUp(
            SmallPlan(kind: SmallPlanKind.walk, at: DateTime(2026, 11, 3, 19)),
          ),
        );
      });

      testWidgets('asks about the plan once', (tester) async {
        await pump(tester, asked);

        expect(find.text('¿Saliste a caminar el martes?'), findsOneWidget);
      });

      testWidgets('answers both ways the same', (tester) async {
        await pump(tester, asked);

        await tester.tap(find.text('Sí'));
        await tester.tap(find.text('Esta vez no'));

        verify(() => cubit.followUpAnswered()).called(2);
      });

      testWidgets('asks in English on an English phone', (tester) async {
        await pump(tester, asked, locale: const Locale('en'));

        expect(find.text('Did you go for a walk on Tuesday?'), findsOneWidget);
        expect(find.text('Not this time'), findsOneWidget);
      });
    });
  });
}
