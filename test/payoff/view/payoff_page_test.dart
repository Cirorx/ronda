import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/payoff/payoff.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockPayoffCubit extends MockCubit<PayoffState> implements PayoffCubit;

class _MockGoRouter extends Mock implements GoRouter;

class _MockProfileRepository extends Mock implements ProfileRepository;

class _MockRondaRepository extends Mock implements RondaRepository;

const _saturday = Slot(SlotDay.saturday, SlotBand.afternoon);

Finder _byId(String identifier) => find.bySemanticsIdentifier(identifier);

void main() {
  late GoRouter router;

  setUp(() {
    router = _MockGoRouter();
    when(() => router.go(any())).thenReturn(null);
  });

  group(PayoffPage, () {
    testWidgets("provides a $PayoffCubit that reads the held answers' "
        'barrio', (tester) async {
      final profileRepository = _MockProfileRepository();
      final rondaRepository = _MockRondaRepository();
      when(profileRepository.heldAnswers).thenAnswer(
        (_) async => Profile(
          firstName: 'Marta',
          ageBand: AgeBand.sixties,
          barrio: Barrio.elPinarSur,
          pretexts: const {Pretext.mate},
          slots: {_saturday},
          brings: const {Bring.termo},
        ),
      );
      when(() => rondaRepository.cerca('el-pinar-sur'))
          .thenAnswer((_) async => const Cerca(barrioId: 'el-pinar-sur'));

      await tester.pumpApp(
        InheritedGoRouter(
          goRouter: router,
          child: MultiRepositoryProvider(
            providers: [
              RepositoryProvider<ProfileRepository>.value(
                value: profileRepository,
              ),
              RepositoryProvider<RondaRepository>.value(value: rondaRepository),
            ],
            child: const PayoffPage(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(PayoffView), findsOneWidget);
      expect(
        find.text(
          'Sos de los primeros en tu zona: te avisamos cuando seamos cinco.',
        ),
        findsOneWidget,
      );
    });

    test('signs in under its own path', () {
      expect(PayoffPage.signInPath, equals('/lo-que-hay/entrar'));
    });
  });

  group(PayoffView, () {
    late PayoffCubit cubit;

    setUp(() {
      cubit = _MockPayoffCubit();
    });

    Future<void> pumpSubject(
      WidgetTester tester,
      PayoffState state, {
      Locale locale = rioplatense,
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        InheritedGoRouter(
          goRouter: router,
          child: BlocProvider.value(value: cubit, child: const PayoffView()),
        ),
        locale: locale,
      );
    }

    const demand = PayoffState(
      status: PayoffStatus.ready,
      barrio: Barrio.elPinarSur,
      demand: [
        PayoffDemand(pretext: Pretext.mate, slot: _saturday, count: 4),
        PayoffDemand(pretext: Pretext.truco, count: 1),
      ],
    );

    group('renders', () {
      testWidgets('the demand near them, never seats', (tester) async {
        await pumpSubject(tester, demand);

        expect(find.text('Esto es lo que hay para vos'), findsOneWidget);
        expect(
          find.text(
            'Hay 4 anotados para mate los sábados de tarde cerca tuyo.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('Hay 1 anotado para truco cerca tuyo.'),
          findsOneWidget,
        );
        expect(
          find.text('Te avisamos cuando se arme tu ronda.'),
          findsOneWidget,
        );
        expect(find.textContaining(' de 6'), findsNothing);
      });

      testWidgets('the demand in English', (tester) async {
        await pumpSubject(tester, demand, locale: const Locale('en'));

        expect(find.text("Here's what there is for you"), findsOneWidget);
        expect(
          find.text(
            '4 neighbours near you signed up for mate on Saturday afternoons.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('1 neighbour near you signed up for truco.'),
          findsOneWidget,
        );
        expect(find.text('Keep my place'), findsOneWidget);
      });

      for (final (pretext, slot, line) in [
        (
          Pretext.futbol5,
          const Slot(SlotDay.monday, SlotBand.morning),
          'Hay 2 anotados para fútbol 5 los lunes de mañana cerca tuyo.',
        ),
        (
          Pretext.caminata,
          const Slot(SlotDay.sunday, SlotBand.evening),
          'Hay 2 anotados para caminar los domingos de noche cerca tuyo.',
        ),
      ]) {
        testWidgets('"$line"', (tester) async {
          await pumpSubject(
            tester,
            PayoffState(
              status: PayoffStatus.ready,
              demand: [PayoffDemand(pretext: pretext, slot: slot, count: 2)],
            ),
          );

          expect(find.text(line), findsOneWidget);
        });
      }

      testWidgets('that they are among the first when nobody else signed '
          'up', (tester) async {
        await pumpSubject(
          tester,
          const PayoffState(
            status: PayoffStatus.ready,
            barrio: Barrio.elPinarSur,
          ),
        );

        expect(
          find.text(
            'Sos de los primeros en tu zona: te avisamos cuando seamos cinco.',
          ),
          findsOneWidget,
        );
      });

      testWidgets('that the counts could not be read, still leading to '
          'sign-in', (tester) async {
        await pumpSubject(
          tester,
          const PayoffState(status: PayoffStatus.unavailable),
        );

        expect(
          find.text(
            'Ahora no pudimos ver quién más se anotó cerca tuyo. Te avisamos '
            'cuando se arme tu ronda.',
          ),
          findsOneWidget,
        );
        expect(find.text('Guardame el lugar'), findsOneWidget);
      });

      testWidgets('a spinner while loading, with the button ready', (
        tester,
      ) async {
        await pumpSubject(tester, const PayoffState());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Guardame el lugar'), findsOneWidget);
      });

      testWidgets('the button Maestro finds by its identifier', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSubject(tester, demand);

        expect(
          tester.getSemantics(_byId(PayoffView.continueIdentifier)),
          isSemantics(
            label: 'Guardame el lugar',
            isButton: true,
            hasTapAction: true,
          ),
        );
        handle.dispose();
      });

      testWidgets('at 200% text without overflowing', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await pumpSubject(tester, demand);

        expect(tester.takeException(), isNull);
      });
    });

    group('goes', () {
      testWidgets('to sign-in on "Guardame el lugar"', (tester) async {
        await pumpSubject(tester, demand);

        await tester.tap(find.text('Guardame el lugar'));

        verify(() => router.go(PayoffPage.signInPath)).called(1);
      });

      testWidgets('back to the read-back with the back button', (tester) async {
        await pumpSubject(tester, demand);

        await tester.tap(find.byType(BackButton));

        verify(() => router.go(OnboardingPage.path)).called(1);
      });

      testWidgets('back to the read-back with the system back button', (
        tester,
      ) async {
        await pumpSubject(tester, demand);

        await tester.binding.handlePopRoute();
        await tester.pump();

        verify(() => router.go(OnboardingPage.path)).called(1);
      });

      testWidgets('to the questions when no answers are held', (tester) async {
        whenListen(
          cubit,
          Stream.value(const PayoffState(status: PayoffStatus.noAnswers)),
          initialState: const PayoffState(),
        );
        await tester.pumpApp(
          InheritedGoRouter(
            goRouter: router,
            child: BlocProvider.value(value: cubit, child: const PayoffView()),
          ),
        );
        await tester.pump();

        verify(() => router.go(OnboardingPage.path)).called(1);
      });
    });
  });
}
