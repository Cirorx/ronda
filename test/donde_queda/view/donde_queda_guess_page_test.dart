import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/donde_queda/cubit/donde_queda_guess_cubit.dart';
import 'package:ronda/donde_queda/donde_queda.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockDondeQuedaRepository extends Mock implements DondeQuedaRepository;

class _MockDondeQuedaGuessCubit extends MockCubit<DondeQuedaGuessState>
    implements DondeQuedaGuessCubit;

void main() {
  final game = DondeQuedaFixtures.open();

  setUpAll(() => registerFallbackValue(DondeQuedaFixtures.pin));

  group(DondeQuedaGuessPage, () {
    testWidgets('reads the game and its photo for the member', (tester) async {
      final AppBloc appBloc = _MockAppBloc();
      final DondeQuedaRepository repository = _MockDondeQuedaRepository();
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.authenticated,
          user: User(id: DondeQuedaFixtures.uid),
        ),
      );
      when(
        () => repository.watch(
          rondaId: DondeQuedaFixtures.rondaId,
          uid: DondeQuedaFixtures.uid,
        ),
      ).thenAnswer((_) => Stream.value(DondeQuedaWeek(game: game)));
      when(() => repository.photo(game.photoPath!))
          .thenAnswer((_) async => DondeQuedaFixtures.jpeg);

      await tester.pumpApp(
        RepositoryProvider<DondeQuedaRepository>.value(
          value: repository,
          child: BlocProvider.value(
            value: appBloc,
            child: const DondeQuedaGuessPage(
              rondaId: DondeQuedaFixtures.rondaId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Pista: cerca de la feria'), findsOneWidget);
    });

    test('puts the ronda in its location', () {
      expect(DondeQuedaGuessPage.location('ronda 1'), '/donde-queda/ronda%201');
    });
  });

  group(DondeQuedaGuessView, () {
    late DondeQuedaGuessCubit cubit;

    setUp(() {
      cubit = _MockDondeQuedaGuessCubit();
      when(cubit.confirmTapped).thenAnswer((_) async {});
    });

    void showing(DondeQuedaGuessState state) =>
        when(() => cubit.state).thenReturn(state);

    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      BlocProvider.value(value: cubit, child: const DondeQuedaGuessView()),
      size: const Size(400, 2400),
    );

    final ready = DondeQuedaGuessState(
      status: DondeQuedaGuessStatus.ready,
      game: game,
      photo: DondeQuedaFixtures.jpeg,
    );

    testWidgets('waits while it reads', (tester) async {
      showing(const DondeQuedaGuessState());
      await pump(tester);

      expect(find.text('Buscando la foto…'), findsOneWidget);
    });

    testWidgets('shows the photo, the hint and the map; a tap drops the '
        'pin', (tester) async {
      showing(ready);
      await pump(tester);

      expect(
        find.bySemanticsLabel(RegExp('La foto de esta semana')),
        findsOneWidget,
      );
      expect(find.text('Pista: cerca de la feria'), findsOneWidget);
      expect(
        find.text('Tocá el mapa donde creés que queda. Tenés un solo pin.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(InteractiveViewer));
      await tester.tap(find.text('Es acá'));

      verify(() => cubit.pinDropped(any())).called(1);
      verifyNever(cubit.confirmTapped);
    });

    testWidgets('sends the pin once dropped, and says when it failed', (
      tester,
    ) async {
      showing(
        DondeQuedaGuessState(
          status: DondeQuedaGuessStatus.ready,
          game: DondeQuedaFixtures.game(
            status: DondeQuedaStatus.open,
            isMyTurn: false,
            photoPath: 'p',
          ),
          photo: DondeQuedaFixtures.jpeg,
          pin: DondeQuedaFixtures.pin,
          sendFailed: true,
        ),
      );
      await pump(tester);

      expect(find.textContaining('Pista'), findsNothing);
      expect(
        find.text('No pudimos guardar tu pin. Probá de nuevo.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Es acá'));

      verify(cubit.confirmTapped).called(1);
    });

    testWidgets('holds the button while the pin is on its way', (tester) async {
      showing(
        ready.copyWith(
          status: DondeQuedaGuessStatus.sending,
          pin: DondeQuedaFixtures.pin,
        ),
      );
      await pump(tester);
      await tester.tap(find.text('Es acá'));
      verifyNever(cubit.confirmTapped);
    });

    for (final (status, message) in [
      (
        DondeQuedaGuessStatus.done,
        'Listo. La respuesta sale en la tarjeta de la semana que viene.',
      ),
      (DondeQuedaGuessStatus.closed, 'Esta foto ya cerró.'),
      (
        DondeQuedaGuessStatus.failure,
        'No pudimos abrir la foto. Probá de nuevo en un rato.',
      ),
    ]) {
      testWidgets('ends with a way back: $status', (tester) async {
        showing(DondeQuedaGuessState(status: status));
        await pump(tester);

        expect(find.text(message), findsOneWidget);
        expect(find.text('Volver a Mi ronda'), findsOneWidget);
      });
    }
  });
}
