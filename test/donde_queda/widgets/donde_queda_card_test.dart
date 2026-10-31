import 'package:bloc_test/bloc_test.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/donde_queda/cubit/donde_queda_cubit.dart';
import 'package:ronda/donde_queda/donde_queda.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockDondeQuedaCubit extends MockCubit<DondeQuedaState>
    implements DondeQuedaCubit;

class _MockDondeQuedaRepository extends Mock implements DondeQuedaRepository;

void main() {
  group(DondeQuedaCard, () {
    testWidgets('follows the game of its ronda', (tester) async {
      final repository = _MockDondeQuedaRepository();
      when(
        () => repository.watch(
          rondaId: DondeQuedaFixtures.rondaId,
          uid: DondeQuedaFixtures.uid,
        ),
      ).thenAnswer(
        (_) => Stream.value(
          const DondeQuedaWeek(reveal: DondeQuedaFixtures.reveal),
        ),
      );

      await tester.pumpApp(
        RepositoryProvider<DondeQuedaRepository>.value(
          value: repository,
          child: const Scaffold(
            body: DondeQuedaCard(
              rondaId: DondeQuedaFixtures.rondaId,
              uid: DondeQuedaFixtures.uid,
            ),
          ),
        ),
      );
      await tester.pump();

      expect(
        find.text('Era la puerta verde de Gestido y Rivera.'),
        findsOneWidget,
      );
    });
  });

  group(DondeQuedaView, () {
    late DondeQuedaCubit cubit;
    late GoRouter router;

    setUp(() {
      cubit = _MockDondeQuedaCubit();
      when(cubit.passTapped).thenAnswer((_) async {});
    });

    void showing(
      DondeQuedaWeek week, {
      bool passing = false,
      bool failed = false,
    }) => when(() => cubit.state).thenReturn(
      DondeQuedaState(
        status: DondeQuedaLoad.ready,
        week: week,
        passing: passing,
        passFailed: failed,
      ),
    );

    Future<void> pump(WidgetTester tester) async {
      router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: BlocProvider.value(
                value: cubit,
                child: const DondeQuedaView(
                  rondaId: DondeQuedaFixtures.rondaId,
                ),
              ),
            ),
          ),
          GoRoute(
            path: DondeQuedaPhotoPage.path,
            builder: (_, state) =>
                Text('photo ${state.pathParameters['rondaId']}'),
          ),
          GoRoute(
            path: DondeQuedaGuessPage.path,
            builder: (_, state) =>
                Text('guess ${state.pathParameters['rondaId']}'),
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
    }

    testWidgets('shows nothing while there is no game and no answer', (
      tester,
    ) async {
      when(() => cubit.state).thenReturn(const DondeQuedaState());
      await pump(tester);

      expect(find.byType(Card), findsNothing);
    });

    testWidgets('shows nothing while someone else is asked', (tester) async {
      showing(DondeQuedaWeek(game: DondeQuedaFixtures.game(isMyTurn: false)));
      await pump(tester);

      expect(find.byType(Card), findsNothing);
    });

    testWidgets("shows last week's answer with how many came close, and no "
        'names', (tester) async {
      showing(const DondeQuedaWeek(reveal: DondeQuedaFixtures.reveal));
      await pump(tester);

      expect(find.text('¿Dónde queda?'), findsOneWidget);
      expect(find.text('La de la semana pasada'), findsOneWidget);
      expect(
        find.text('Era la puerta verde de Gestido y Rivera.'),
        findsOneWidget,
      );
      expect(find.text('Cerca: 3 de 5'), findsOneWidget);
      expect(find.byType(Divider), findsNothing);
    });

    testWidgets('says nobody guessed', (tester) async {
      showing(
        const DondeQuedaWeek(
          reveal: DondeQuedaReveal(line: 'el ceibo', close: 0, guessed: 0),
        ),
      );
      await pump(tester);

      expect(find.text('Nadie puso su pin.'), findsOneWidget);
    });

    testWidgets('asks for the photo on their turn, and opens it', (
      tester,
    ) async {
      showing(
        DondeQuedaWeek(
          game: DondeQuedaFixtures.game(),
          reveal: DondeQuedaFixtures.reveal,
        ),
      );
      await pump(tester);

      expect(find.text('Esta semana te toca a vos.'), findsOneWidget);
      expect(
        find.text(
          'Sacale una foto a algo del barrio: una puerta, un mural, un árbol.',
        ),
        findsOneWidget,
      );
      expect(find.byType(Divider), findsOneWidget);
      await tester.tap(find.text('Sacar la foto'));
      await tester.pumpAndSettle();

      expect(find.text('photo ronda-1'), findsOneWidget);
    });

    testWidgets('passes the turn on «Esta semana no»', (tester) async {
      showing(DondeQuedaWeek(game: DondeQuedaFixtures.game()));
      await pump(tester);

      await tester.tap(find.text('Esta semana no'));

      verify(cubit.passTapped).called(1);
    });

    testWidgets('holds the buttons while passing, and says when it '
        'failed', (tester) async {
      showing(
        DondeQuedaWeek(game: DondeQuedaFixtures.game()),
        passing: true,
        failed: true,
      );
      await pump(tester);

      expect(
        find.text('No pudimos pasar el turno. Probá de nuevo.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Sacar la foto'));
      await tester.pump();

      expect(find.text('photo ronda-1'), findsNothing);
      verifyNever(cubit.passTapped);
    });

    testWidgets('offers the photo to guess, and opens it', (tester) async {
      showing(DondeQuedaWeek(game: DondeQuedaFixtures.open()));
      await pump(tester);

      expect(
        find.text('Hay una foto del barrio. ¿Sabés dónde queda?'),
        findsOneWidget,
      );
      await tester.tap(find.text('Poner mi pin'));
      await tester.pumpAndSettle();

      expect(find.text('guess ronda-1'), findsOneWidget);
    });

    testWidgets('tells the photographer the photo is up', (tester) async {
      showing(DondeQuedaWeek(game: DondeQuedaFixtures.open(posted: true)));
      await pump(tester);

      expect(
        find.text(
          'Tu foto ya está. La respuesta sale en la tarjeta de la semana que '
          'viene.',
        ),
        findsOneWidget,
      );
    });

    testWidgets('tells a member who guessed that the answer comes next '
        'week', (tester) async {
      showing(DondeQuedaWeek(game: DondeQuedaFixtures.open(guessed: true)));
      await pump(tester);

      expect(
        find.text(
          'Ya pusiste tu pin. La respuesta sale en la tarjeta de la semana '
          'que viene.',
        ),
        findsOneWidget,
      );
      expect(find.text('Poner mi pin'), findsNothing);
    });
  });
}
