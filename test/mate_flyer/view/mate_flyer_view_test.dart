import 'dart:typed_data';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flyer_repository/flyer_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/mate_flyer/mate_flyer.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockFlyerRepository extends Mock implements FlyerRepository;

class _MockMateFlyerCubit extends MockCubit<MateFlyerState>
    implements MateFlyerCubit;

void main() {
  final photo = BlurredPhoto.test(width: 400, height: 300, blurredFaces: 2);
  final flyer = MateFlyer(
    id: 'flyer-1',
    image: Uint8List.fromList([1, 2]),
    landingUrl: 'https://ronda-uy.firebaseapp.com/f/flyer-1',
  );

  group(MateFlyerPage, () {
    late AppBloc appBloc;
    late FlyerRepository repository;

    setUp(() {
      appBloc = _MockAppBloc();
      repository = _MockFlyerRepository();
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.authenticated,
          user: User(id: 'demo-uid'),
        ),
      );
      when(() => repository.canBlurFaces).thenReturn(true);
      when(repository.retrieveLostPhoto).thenAnswer((_) async => null);
    });

    testWidgets('provides a $MateFlyerCubit for its ronda and looks for a '
        'lost photo', (tester) async {
      await tester.pumpApp(
        RepositoryProvider<FlyerRepository>.value(
          value: repository,
          child: BlocProvider.value(
            value: appBloc,
            child: const MateFlyerPage(rondaId: 'ronda-1'),
          ),
        ),
      );
      await tester.pump();

      expect(
        tester.element(find.byType(MateFlyerView)).read<MateFlyerCubit>().state,
        equals(const MateFlyerState()),
      );
      verify(repository.retrieveLostPhoto).called(1);
    });

    test('puts the ronda in its location', () {
      expect(MateFlyerPage.location('ronda 1'), equals('/volante/ronda%201'));
    });
  });

  group(MateFlyerView, () {
    late MateFlyerCubit cubit;

    setUp(() {
      cubit = _MockMateFlyerCubit();
      when(() => cubit.photoRequested(any())).thenAnswer((_) async {});
      when(
        () => cubit.faceTapped(
          x: any(named: 'x'),
          y: any(named: 'y'),
        ),
      ).thenAnswer((_) async {});
      when(() => cubit.flyerRequested()).thenAnswer((_) async {});
      when(() => cubit.shareRequested(title: any(named: 'title')))
          .thenAnswer((_) async {});
    });

    setUpAll(() => registerFallbackValue(PhotoSource.camera));

    Future<void> pump(
      WidgetTester tester,
      MateFlyerState state, {
      Locale locale = rioplatense,
    }) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(value: cubit, child: const MateFlyerView()),
        locale: locale,
      );
    }

    testWidgets('on web, sends the host to the phone app', (tester) async {
      await pump(
        tester,
        const MateFlyerState(status: MateFlyerStatus.unsupported),
      );

      expect(find.text('Hacelo desde la app del teléfono'), findsOneWidget);
      expect(find.text('Sacar una foto'), findsNothing);
    });

    testWidgets('in English too', (tester) async {
      await pump(
        tester,
        const MateFlyerState(status: MateFlyerStatus.unsupported),
        locale: const Locale('en'),
      );

      expect(find.text('Do it from the phone app'), findsOneWidget);
      expect(find.text('A spare mate'), findsOneWidget);
    });

    group('waiting for a photo', () {
      testWidgets('asks for the group things and opens the camera', (
        tester,
      ) async {
        await pump(tester, const MateFlyerState());

        expect(
          find.text(
            'Sacale una foto a las cosas del grupo. Mejor sin gente: si sale '
            'alguien, lo borroneamos antes de subir.',
          ),
          findsOneWidget,
        );
        await tester.tap(find.text('Sacar una foto'));
        verify(() => cubit.photoRequested(PhotoSource.camera)).called(1);
      });

      testWidgets('opens the gallery', (tester) async {
        await pump(tester, const MateFlyerState());

        await tester.tap(find.text('Elegir una de la galería'));

        verify(() => cubit.photoRequested(PhotoSource.gallery)).called(1);
      });

      for (final (failure, message) in [
        (MateFlyerFailure.photo, 'No pudimos abrir la foto. Probá de nuevo.'),
        (
          MateFlyerFailure.nothingToCutOut,
          'No encontramos el termo, el mazo ni los mates. Probá con otra '
              'foto, más de cerca.',
        ),
      ]) {
        testWidgets('says ${failure.name} went wrong', (tester) async {
          await pump(tester, MateFlyerState(failure: failure));

          expect(find.text(message), findsOneWidget);
        });
      }
    });

    testWidgets('says faces are being blurred', (tester) async {
      await pump(
        tester,
        const MateFlyerState(status: MateFlyerStatus.blurring),
      );

      expect(find.text('Borroneando las caras…'), findsOneWidget);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    group('the blurred photo', () {
      testWidgets('says how many faces it blurred and how to blur '
          'more', (tester) async {
        await pump(
          tester,
          MateFlyerState(status: MateFlyerStatus.preview, photo: photo),
        );

        expect(find.text('Mirá que esté bien'), findsOneWidget);
        expect(
          find.text('Borroneamos 2 caras. Tocá una cara para borronearla.'),
          findsOneWidget,
        );
      });

      testWidgets('blurs where it is tapped, as a share of the '
          'photo', (tester) async {
        await pump(
          tester,
          MateFlyerState(status: MateFlyerStatus.preview, photo: photo),
        );

        final box = tester.getRect(find.byType(AspectRatio));
        await tester.tapAt(box.topLeft + Offset(box.width / 4, box.height / 2));

        final captured = verify(
          () => cubit.faceTapped(
            x: captureAny(named: 'x'),
            y: captureAny(named: 'y'),
          ),
        ).captured;
        expect(captured[0] as double, closeTo(0.25, 0.01));
        expect(captured[1] as double, closeTo(0.5, 0.01));
      });

      testWidgets('makes the flyer and offers another photo', (tester) async {
        await pump(
          tester,
          MateFlyerState(status: MateFlyerStatus.preview, photo: photo),
        );

        await tester.tap(find.text('Hacer el volante'));
        await tester.ensureVisible(find.text('Sacar otra foto'));
        await tester.tap(find.text('Sacar otra foto'));

        verify(() => cubit.flyerRequested()).called(1);
        verify(() => cubit.retakeRequested()).called(1);
      });

      testWidgets('takes no taps while a tapped face is blurring', (
        tester,
      ) async {
        await pump(
          tester,
          MateFlyerState(status: MateFlyerStatus.blurring, photo: photo),
        );

        await tester.tap(find.byType(AspectRatio));
        await tester.tap(find.text('Hacer el volante'));

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        verifyNever(
          () => cubit.faceTapped(
            x: any(named: 'x'),
            y: any(named: 'y'),
          ),
        );
        verifyNever(() => cubit.flyerRequested());
      });

      testWidgets('says the host should make it', (tester) async {
        await pump(
          tester,
          MateFlyerState(
            status: MateFlyerStatus.preview,
            photo: photo,
            failure: MateFlyerFailure.notHost,
          ),
        );

        expect(
          find.text('El volante lo hacen quienes abren la ronda.'),
          findsOneWidget,
        );
      });

      testWidgets('says the flyer failed', (tester) async {
        await pump(
          tester,
          MateFlyerState(
            status: MateFlyerStatus.preview,
            photo: photo,
            failure: MateFlyerFailure.flyer,
          ),
        );

        expect(
          find.text('No pudimos hacer el volante. Probá de nuevo en un rato.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('says the flyer is on its way', (tester) async {
      await pump(
        tester,
        MateFlyerState(status: MateFlyerStatus.making, photo: photo),
      );

      expect(
        find.text('Estamos haciendo tu volante. Tarda como medio minuto.'),
        findsOneWidget,
      );
    });

    group('the flyer', () {
      testWidgets('shows it, what the photo is for, and shares it', (
        tester,
      ) async {
        await pump(
          tester,
          MateFlyerState(status: MateFlyerStatus.ready, flyer: flyer),
        );

        expect(find.text('Así queda tu volante'), findsOneWidget);
        expect(
          find.text('La foto la usamos solo para el volante.'),
          findsOneWidget,
        );
        await tester.ensureVisible(find.text('Imprimir o compartir'));
        await tester.tap(find.text('Imprimir o compartir'));
        await tester.ensureVisible(find.text('Sacar otra foto'));
        await tester.tap(find.text('Sacar otra foto'));

        verify(() => cubit.shareRequested(title: 'Un mate de más')).called(1);
        verify(() => cubit.retakeRequested()).called(1);
      });

      testWidgets('says the share sheet failed', (tester) async {
        await pump(
          tester,
          MateFlyerState(
            status: MateFlyerStatus.ready,
            flyer: flyer,
            failure: MateFlyerFailure.share,
          ),
        );

        expect(
          find.text('No pudimos abrir las opciones para compartirlo.'),
          findsOneWidget,
        );
      });
    });

    testWidgets('falls back to the photo step for a state with nothing to '
        'show', (tester) async {
      await pump(tester, const MateFlyerState(status: MateFlyerStatus.ready));

      expect(find.text('Sacar una foto'), findsOneWidget);
    });
  });
}
