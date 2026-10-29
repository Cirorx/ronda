import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/onboarding/view/steps/steps.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockOnboardingCubit extends MockCubit<OnboardingState>
    implements OnboardingCubit;

class _MockVoiceNoteCubit extends MockCubit<VoiceNoteState>
    implements VoiceNoteCubit;

class _MockOnboardingRepository extends Mock implements OnboardingRepository;

const _signup = VoiceSignup(firstName: 'Graciela', pretexts: ['mate']);

Finder _byId(String identifier) => find.bySemanticsIdentifier(identifier);

void main() {
  late OnboardingCubit onboarding;

  setUpAll(() => registerFallbackValue(const VoiceSignup()));

  setUp(() {
    onboarding = _MockOnboardingCubit();
    when(() => onboarding.state)
        .thenReturn(const OnboardingState(recording: true));
  });

  group(VoiceNoteStep, () {
    testWidgets('provides a $VoiceNoteCubit that starts recording', (
      tester,
    ) async {
      final appBloc = _MockAppBloc();
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.onboarding,
          user: User(id: 'demo-uid'),
        ),
      );
      final repository = _MockOnboardingRepository();
      when(repository.startVoiceNote).thenAnswer((_) async {});
      when(repository.discardVoiceNote).thenAnswer((_) async {});

      await tester.pumpApp(
        RepositoryProvider<OnboardingRepository>.value(
          value: repository,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<AppBloc>.value(value: appBloc),
              BlocProvider<OnboardingCubit>.value(value: onboarding),
            ],
            child: const VoiceNoteStep(),
          ),
        ),
      );
      await tester.pump();

      expect(find.byType(VoiceNoteView), findsOneWidget);
      verify(repository.startVoiceNote).called(1);
      await tester.pumpWidget(const SizedBox());
      verify(repository.discardVoiceNote).called(1);
    });
  });

  group(VoiceNoteView, () {
    late VoiceNoteCubit cubit;

    setUp(() {
      cubit = _MockVoiceNoteCubit();
      when(() => cubit.start()).thenAnswer((_) async {});
      when(() => cubit.finish()).thenAnswer((_) async {});
      when(() => cubit.restart()).thenAnswer((_) async {});
    });

    Future<void> pumpSubject(
      WidgetTester tester,
      VoiceNoteState state, {
      Stream<VoiceNoteState>? states,
      Locale locale = rioplatense,
    }) {
      if (states != null) {
        whenListen(cubit, states, initialState: state);
      } else {
        when(() => cubit.state).thenReturn(state);
      }
      return tester.pumpApp(
        MultiBlocProvider(
          providers: [
            BlocProvider<OnboardingCubit>.value(value: onboarding),
            BlocProvider<VoiceNoteCubit>.value(value: cubit),
          ],
          child: const VoiceNoteView(),
        ),
        locale: locale,
      );
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      await tester.pump();
    }

    group('while recording', () {
      const recording = VoiceNoteState(
        status: VoiceNoteStatus.recording,
        elapsed: Duration(seconds: 23),
      );

      testWidgets('shows the timer, the ideas and the deletion note', (
        tester,
      ) async {
        await pumpSubject(tester, recording);

        expect(find.text('Te escuchamos'), findsOneWidget);
        expect(find.text('0:23 de 1:00'), findsOneWidget);
        expect(find.text('Ideas de qué contar'), findsOneWidget);
        expect(
          find.text('Cómo te llamás y en qué barrio estás'),
          findsOneWidget,
        );
        expect(find.text('Qué podés llevar o enseñar'), findsOneWidget);
        expect(
          find.text('El audio se borra apenas lo leemos.'),
          findsOneWidget,
        );
        expect(find.text('Cancelar'), findsOneWidget);
      });

      testWidgets('finishes with "Terminé"', (tester) async {
        await pumpSubject(tester, recording);

        await tapVisible(tester, _byId(VoiceNoteView.doneIdentifier));

        verify(() => cubit.finish()).called(1);
      });

      testWidgets('starts over with "Borrar y empezar de nuevo"', (
        tester,
      ) async {
        await pumpSubject(tester, recording);

        await tapVisible(tester, _byId(VoiceNoteView.restartIdentifier));

        verify(() => cubit.restart()).called(1);
      });

      testWidgets('leaves for the buttons with "Cancelar"', (tester) async {
        await pumpSubject(tester, recording);

        await tester.tap(find.text('Cancelar'));

        verify(() => onboarding.voiceCancelled()).called(1);
      });

      testWidgets('disables "Terminé" until the recorder runs', (tester) async {
        await pumpSubject(tester, const VoiceNoteState());

        await tapVisible(tester, _byId(VoiceNoteView.doneIdentifier));
        await tapVisible(tester, _byId(VoiceNoteView.restartIdentifier));

        verifyNever(() => cubit.finish());
        verifyNever(() => cubit.restart());
      });

      testWidgets('holds 200% text', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await pumpSubject(tester, recording);

        expect(tester.takeException(), isNull);
      });

      testWidgets('in English', (tester) async {
        await pumpSubject(tester, recording, locale: const Locale('en'));

        expect(find.text("We're listening"), findsOneWidget);
        expect(find.text('0:23 of 1:00'), findsOneWidget);
      });
    });

    testWidgets('says the note is being read', (tester) async {
      await pumpSubject(
        tester,
        const VoiceNoteState(status: VoiceNoteStatus.reading),
      );

      expect(find.text('Estamos leyendo tu audio'), findsOneWidget);
      expect(find.text('· Borramos el audio'), findsOneWidget);
    });

    testWidgets('hands what was understood to the read-back', (tester) async {
      await pumpSubject(
        tester,
        const VoiceNoteState(status: VoiceNoteStatus.reading),
        states: Stream.value(
          const VoiceNoteState(status: VoiceNoteStatus.read, signup: _signup),
        ),
      );
      await tester.pump();

      verify(() => onboarding.voiceRead(_signup)).called(1);
    });

    for (final (status, title, retry) in [
      (
        VoiceNoteStatus.notUnderstood,
        'No te entendimos bien',
        'Grabar de nuevo',
      ),
      (VoiceNoteStatus.failure, 'No pudimos leer el audio', 'Grabar de nuevo'),
      (
        VoiceNoteStatus.microphoneDenied,
        'No podemos usar el micrófono',
        'Ya le di permiso',
      ),
    ]) {
      group('when ${status.name}', () {
        testWidgets('says so and offers "$retry"', (tester) async {
          await pumpSubject(tester, VoiceNoteState(status: status));

          expect(find.text(title), findsOneWidget);
          await tapVisible(tester, find.text(retry));

          verify(() => cubit.start()).called(1);
        });

        testWidgets('offers the buttons instead', (tester) async {
          await pumpSubject(tester, VoiceNoteState(status: status));

          await tapVisible(tester, _byId(VoiceNoteView.buttonsIdentifier));

          verify(() => onboarding.voiceCancelled()).called(1);
        });
      });
    }

    testWidgets('lists the three steps to allow the microphone', (
      tester,
    ) async {
      await pumpSubject(
        tester,
        const VoiceNoteState(status: VoiceNoteStatus.microphoneDenied),
      );

      expect(find.text('1. Abrí los ajustes del teléfono.'), findsOneWidget);
      expect(find.text('3. Volvé a Ronda y grabá.'), findsOneWidget);
    });

    testWidgets('gives tips when nothing was understood', (tester) async {
      await pumpSubject(
        tester,
        const VoiceNoteState(status: VoiceNoteStatus.notUnderstood),
      );

      expect(find.text('Para la próxima'), findsOneWidget);
      expect(find.text('· Tomate al menos 20 segundos.'), findsOneWidget);
    });
  });
}
