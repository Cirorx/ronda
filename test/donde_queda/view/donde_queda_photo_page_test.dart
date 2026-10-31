import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/donde_queda/cubit/donde_queda_photo_cubit.dart';
import 'package:ronda/donde_queda/donde_queda.dart';
import 'package:ronda/donde_queda/models/game_text.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockDondeQuedaRepository extends Mock implements DondeQuedaRepository;

class _MockDondeQuedaPhotoCubit extends MockCubit<DondeQuedaPhotoState>
    implements DondeQuedaPhotoCubit;

void main() {
  final photo = BlurredPhoto.test(width: 400, height: 300, blurredFaces: 1);
  final game = DondeQuedaFixtures.game();

  setUpAll(() {
    registerFallbackValue(PhotoSource.camera);
    registerFallbackValue(DondeQuedaFixtures.pin);
  });

  group(DondeQuedaPhotoPage, () {
    testWidgets('reads the game of its ronda for the member', (tester) async {
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
      when(() => repository.canBlurFaces).thenReturn(true);
      when(repository.retrieveLostPhoto).thenAnswer((_) async => null);

      await tester.pumpApp(
        RepositoryProvider<DondeQuedaRepository>.value(
          value: repository,
          child: BlocProvider.value(
            value: appBloc,
            child: const DondeQuedaPhotoPage(
              rondaId: DondeQuedaFixtures.rondaId,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Sacar una foto'), findsOneWidget);
    });

    test('puts the ronda in its location', () {
      expect(
        DondeQuedaPhotoPage.location('ronda 1'),
        '/donde-queda/ronda%201/foto',
      );
    });
  });

  group(DondeQuedaPhotoView, () {
    late DondeQuedaPhotoCubit cubit;

    setUp(() {
      cubit = _MockDondeQuedaPhotoCubit();
      when(() => cubit.photoRequested(any())).thenAnswer((_) async {});
      when(
        () => cubit.faceTapped(
          x: any(named: 'x'),
          y: any(named: 'y'),
        ),
      ).thenAnswer((_) async {});
      when(cubit.sendTapped).thenAnswer((_) async {});
    });

    void showing(DondeQuedaPhotoState state) =>
        when(() => cubit.state).thenReturn(state);

    Future<void> pump(WidgetTester tester) => tester.pumpApp(
      BlocProvider.value(value: cubit, child: const DondeQuedaPhotoView()),
      // Tall enough that every step fits without scrolling.
      size: const Size(400, 2400),
    );

    testWidgets('waits while it reads the game', (tester) async {
      showing(const DondeQuedaPhotoState());
      await pump(tester);

      expect(find.text('Buscando la foto…'), findsOneWidget);
    });

    testWidgets('says to use the phone on web', (tester) async {
      showing(
        DondeQuedaPhotoState(
          status: DondeQuedaPhotoStatus.unsupported,
          game: game,
        ),
      );
      await pump(tester);

      expect(find.text('Hacelo desde la app del teléfono'), findsOneWidget);
    });

    testWidgets('opens the camera or the gallery, and says what to avoid', (
      tester,
    ) async {
      showing(
        DondeQuedaPhotoState(
          status: DondeQuedaPhotoStatus.choosing,
          game: game,
          failure: DondeQuedaPhotoFailure.houseNumber,
        ),
      );
      await pump(tester);

      expect(
        find.text(
          'Se ve el número de una casa. Sacala desde otro lado, sin el número.',
        ),
        findsOneWidget,
      );
      await tester.tap(find.text('Sacar una foto'));
      await tester.tap(find.text('Elegir una de la galería'));

      verify(() => cubit.photoRequested(PhotoSource.camera)).called(1);
      verify(() => cubit.photoRequested(PhotoSource.gallery)).called(1);
    });

    for (final (failure, message) in [
      (
        DondeQuedaPhotoFailure.photo,
        'No pudimos abrir la foto. Probá de nuevo.',
      ),
      (
        DondeQuedaPhotoFailure.person,
        'La foto es de una persona. Buscá algo del barrio: una puerta, un '
            'mural, un árbol.',
      ),
      (
        DondeQuedaPhotoFailure.empty,
        'La foto salió vacía o muy oscura. Probá de nuevo.',
      ),
    ]) {
      testWidgets('says why: $failure', (tester) async {
        showing(
          DondeQuedaPhotoState(
            status: DondeQuedaPhotoStatus.choosing,
            game: game,
            failure: failure,
          ),
        );
        await pump(tester);

        expect(find.text(message), findsOneWidget);
      });
    }

    testWidgets('waits while the faces are blurred', (tester) async {
      showing(
        DondeQuedaPhotoState(
          status: DondeQuedaPhotoStatus.blurring,
          game: game,
        ),
      );
      await pump(tester);

      expect(find.text('Borroneando las caras…'), findsOneWidget);
    });

    testWidgets('shows the blurred photo and the words, and goes on', (
      tester,
    ) async {
      showing(
        DondeQuedaPhotoState(
          status: DondeQuedaPhotoStatus.preview,
          game: game,
          photo: photo,
          line: const GameText.dirty(''),
          hint: GameText.dirty('x' * 81, optional: true),
          failure: DondeQuedaPhotoFailure.words,
        ),
      );
      await pump(tester);

      expect(
        find.text('Borroneamos una cara. Tocá una cara para borronearla.'),
        findsOneWidget,
      );
      expect(find.text('Contá qué es, en una línea.'), findsOneWidget);
      expect(find.text('Hasta 80 letras.'), findsOneWidget);
      expect(
        find.text(
          'Lo que escribiste no puede ir: sin direcciones con número ni '
          'nombres de personas.',
        ),
        findsOneWidget,
      );
      await tester.enterText(find.byType(TextFormField).first, 'el ceibo');
      await tester.enterText(find.byType(TextFormField).last, 'la plaza');
      await tester.tap(find.byType(TapToBlurPhoto));
      await tester.tap(find.text('Seguir'));
      await tester.tap(find.text('Sacar otra foto'));

      verify(() => cubit.lineChanged('el ceibo')).called(1);
      verify(() => cubit.hintChanged('la plaza')).called(1);
      verify(
        () => cubit.faceTapped(
          x: any(named: 'x'),
          y: any(named: 'y'),
        ),
      ).called(1);
      verify(cubit.wordsDone).called(1);
      verify(cubit.retakeRequested).called(1);
    });

    testWidgets('holds the buttons while a tapped face is blurred', (
      tester,
    ) async {
      showing(
        DondeQuedaPhotoState(
          status: DondeQuedaPhotoStatus.blurring,
          game: game,
          photo: photo,
        ),
      );
      await pump(tester);

      expect(find.text('Borroneando esa cara…'), findsOneWidget);
      await tester.tap(find.text('Seguir'));
      verifyNever(cubit.wordsDone);
    });

    testWidgets('drops the pin on the map and sends', (tester) async {
      showing(
        DondeQuedaPhotoState(
          status: DondeQuedaPhotoStatus.pinning,
          game: game,
          photo: photo,
          pin: DondeQuedaFixtures.pin,
          failure: DondeQuedaPhotoFailure.send,
        ),
      );
      await pump(tester);

      expect(find.text('Marcá dónde queda'), findsOneWidget);
      expect(find.text('© colaboradores de OpenStreetMap'), findsOneWidget);
      expect(
        find.text('No pudimos mandar la foto. Probá de nuevo en un rato.'),
        findsOneWidget,
      );
      await tester.tap(find.byType(InteractiveViewer));
      await tester.tap(find.text('Mandar la foto'));
      await tester.tap(find.text('Volver a la foto'));

      verify(() => cubit.pinDropped(any())).called(1);
      verify(cubit.sendTapped).called(1);
      verify(cubit.backToWords).called(1);
    });

    testWidgets('sends nothing before the pin', (tester) async {
      showing(
        DondeQuedaPhotoState(
          status: DondeQuedaPhotoStatus.pinning,
          game: game,
          photo: photo,
        ),
      );
      await pump(tester);
      await tester.tap(find.text('Mandar la foto'));
      verifyNever(cubit.sendTapped);
    });

    testWidgets('waits while the program checks the photo', (tester) async {
      showing(
        DondeQuedaPhotoState(status: DondeQuedaPhotoStatus.sending, game: game),
      );
      await pump(tester);

      expect(
        find.text('Revisando la foto. Tarda como medio minuto.'),
        findsOneWidget,
      );
    });

    for (final (status, message) in [
      (
        DondeQuedaPhotoStatus.done,
        'Listo, tu foto ya está. Los demás la ven en Mi ronda.',
      ),
      (
        DondeQuedaPhotoStatus.closed,
        'Esta semana ya no te toca: la foto la saca otra persona, o ya cerró.',
      ),
    ]) {
      testWidgets('ends with a way back: $status', (tester) async {
        showing(DondeQuedaPhotoState(status: status));
        final router = GoRouter(
          routes: [
            GoRoute(path: '/', builder: (_, _) => const Text('home')),
            GoRoute(path: '/ronda', builder: (_, _) => const Text('mi ronda')),
            GoRoute(
              path: '/foto',
              builder: (_, _) => BlocProvider.value(
                value: cubit,
                child: const DondeQuedaPhotoView(),
              ),
            ),
          ],
          initialLocation: '/foto',
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

        expect(find.text(message), findsOneWidget);
        await tester.tap(find.text('Volver a Mi ronda'));
        await tester.pumpAndSettle();

        expect(find.text('mi ronda'), findsOneWidget);
      });
    }

    testWidgets('a pushed screen goes back where it came from', (tester) async {
      showing(const DondeQuedaPhotoState(status: DondeQuedaPhotoStatus.done));
      final router = GoRouter(
        routes: [
          GoRoute(path: '/', builder: (_, _) => const Text('home')),
          GoRoute(
            path: '/foto',
            builder: (_, _) => BlocProvider.value(
              value: cubit,
              child: const DondeQuedaPhotoView(),
            ),
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
      unawaited(router.push('/foto'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Volver a Mi ronda'));
      await tester.pumpAndSettle();

      expect(find.text('home'), findsOneWidget);
    });
  });
}
