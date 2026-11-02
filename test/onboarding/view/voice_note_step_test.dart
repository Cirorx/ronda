import 'package:auth_repository/auth_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:error_reporter/error_reporter.dart';
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

class _MockErrorReporter extends Mock implements ErrorReporter;

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
    testWidgets('provides a $VoiceNoteCubit that records only on "Grabar"', (
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
      when(() => repository.startVoiceNote('demo-uid'))
          .thenAnswer((_) async {});
      when(repository.discardVoiceNote).thenAnswer((_) async {});
      when(repository.voiceLevels).thenAnswer((_) => const Stream.empty());
      when(repository.liveWords).thenAnswer((_) => const Stream.empty());

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
      verifyNever(() => repository.startVoiceNote(any()));

      await tester.tap(find.text('Grabar'));
      await tester.pump();
      verify(() => repository.startVoiceNote('demo-uid')).called(1);
      await tester.pumpWidget(const SizedBox());
      verify(repository.discardVoiceNote).called(1);
    });
  });

  group('$VoiceNoteStep error log', () {
    late OnboardingRepository repository;
    late ErrorReporter reporter;

    setUp(() {
      repository = _MockOnboardingRepository();
      reporter = _MockErrorReporter();
      when(repository.discardVoiceNote).thenAnswer((_) async {});
      when(repository.voiceLevels).thenAnswer((_) => const Stream.empty());
      when(repository.liveWords).thenAnswer((_) => const Stream.empty());
      when(
        () => reporter.reportFailure(
          screen: any(named: 'screen'),
          step: any(named: 'step'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async {});
    });

    Future<void> pumpStep(WidgetTester tester) async {
      final appBloc = _MockAppBloc();
      when(() => appBloc.state).thenReturn(
        const AppState(
          status: AppStatus.onboarding,
          user: User(id: 'demo-uid'),
        ),
      );
      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider<OnboardingRepository>.value(value: repository),
            RepositoryProvider<ErrorReporter>.value(value: reporter),
          ],
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
    }

    testWidgets('reports a recorder that fails, once', (tester) async {
      when(() => repository.startVoiceNote(any()))
          .thenThrow(Exception('no recorder'));
      await pumpStep(tester);

      await tester.tap(find.text('Grabar'));
      await tester.pump();

      verify(
        () => reporter.reportFailure(
          screen: OnboardingPage.path,
          step: VoiceNoteStep.reportStep,
          code: 'voice/recorderFailed',
        ),
      ).called(1);
    });

    test("codes a failure with the server's answer when there is one", () {
      expect(
        VoiceNoteStep.reportCode(VoiceNoteFailure.uploadFailed, 'unauthorized'),
        equals('voice/uploadFailed/unauthorized'),
      );
      expect(
        VoiceNoteStep.reportCode(VoiceNoteFailure.readFailed, null),
        equals('voice/readFailed'),
      );
    });

    for (final (thrown, name) in [
      (const MicrophoneDeniedFailure(), 'a refused microphone'),
      (const NoMicrophoneFailure(), 'a missing microphone'),
    ]) {
      testWidgets('does not report $name', (tester) async {
        when(() => repository.startVoiceNote(any())).thenThrow(thrown);
        await pumpStep(tester);

        await tester.tap(find.text('Grabar'));
        await tester.pump();

        expect(find.byType(VoiceNoteView), findsOneWidget);
        verifyNever(
          () => reporter.reportFailure(
            screen: any(named: 'screen'),
            step: any(named: 'step'),
            code: any(named: 'code'),
          ),
        );
      });
    }
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
      bool reduced = false,
      PermissionPlace place = PermissionPlace.app,
    }) {
      if (states != null) {
        whenListen(cubit, states, initialState: state);
      } else {
        when(() => cubit.state).thenReturn(state);
      }
      return tester.pumpApp(
        reducedMotion(
          reduced: reduced,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<OnboardingCubit>.value(value: onboarding),
              BlocProvider<VoiceNoteCubit>.value(value: cubit),
            ],
            child: VoiceNoteView(place: place),
          ),
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
        expect(find.text('Qué contar'), findsOneWidget);
        expect(find.textContaining('«Soy Ana, tengo 34'), findsOneWidget);
        const pretexts =
            'Qué te gustaría hacer: mate en la rambla, truco, fútbol 5, '
            'caminata, conga, un café o merienda, mirar pájaros';
        const brings =
            'Qué podés llevar o enseñar: pan, yerba, mate y termo, sillas, '
            'enseño truco, tortas fritas si llueve';
        for (final idea in [
          'Tu nombre',
          'Tu edad, más o menos',
          'Tu barrio',
          pretexts,
          'Qué días, y si de mañana, tarde o noche',
          brings,
        ]) {
          expect(find.text(idea), findsOneWidget);
        }
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

      testWidgets('shows the voice as a waveform', (tester) async {
        await pumpSubject(
          tester,
          const VoiceNoteState(
            status: VoiceNoteStatus.recording,
            levels: [0, 0.4, 0.9],
            heard: 3,
          ),
        );

        final waveform = tester.widget<VoiceWaveform>(
          find.byType(VoiceWaveform),
        );
        expect(waveform.levels, equals([0, 0.4, 0.9]));
        expect(waveform.heard, equals(3));
        expect(waveform.length, equals(VoiceNoteCubit.waveformLength));
        expect(
          find.text('No te escuchamos. Revisá el micrófono.'),
          findsNothing,
        );
      });

      testWidgets('shows the words heard so far, with their caption', (
        tester,
      ) async {
        await pumpSubject(
          tester,
          const VoiceNoteState(
            status: VoiceNoteStatus.recording,
            words: 'Hola, soy Marta',
          ),
        );

        expect(find.byType(LiveWords), findsOneWidget);
        expect(find.text('Lo que vamos escuchando'), findsOneWidget);
        expect(find.text('Hola, soy Marta'), findsOneWidget);
      });

      testWidgets('shows no words before any is heard', (tester) async {
        await pumpSubject(tester, recording);

        expect(find.byType(LiveWords), findsNothing);
        expect(find.text('Lo que vamos escuchando'), findsNothing);
      });

      testWidgets('says when it hears nothing', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSubject(
          tester,
          const VoiceNoteState(status: VoiceNoteStatus.recording, silent: true),
        );

        final warning = find.text('No te escuchamos. Revisá el micrófono.');
        expect(warning, findsOneWidget);
        expect(tester.getSemantics(warning), isSemantics(isLiveRegion: true));
        semantics.dispose();
      });

      testWidgets('reads out "Grabando" once, and the time, never the bars', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await pumpSubject(tester, recording);

        expect(
          tester.getSemantics(find.text('Grabando')),
          isSemantics(label: 'Grabando', isLiveRegion: true),
        );
        expect(
          tester.getSemantics(find.text('0:23 de 1:00')),
          isSemantics(label: '0:23 de 1:00', isLiveRegion: false),
        );
        expect(
          find.descendant(
            of: find.byType(VoiceWaveform),
            matching: find.byType(ExcludeSemantics),
          ),
          findsOneWidget,
        );
        semantics.dispose();
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
        expect(find.text('Recording'), findsOneWidget);
      });
    });

    group('before recording', () {
      testWidgets('waits for "Grabar" with the ideas', (tester) async {
        await pumpSubject(tester, const VoiceNoteState());

        expect(find.text('Te escuchamos'), findsOneWidget);
        expect(
          find.text(
            'Tocá «Grabar» cuando quieras y hablá tranquilo, como en un '
            'audio a un amigo.',
          ),
          findsOneWidget,
        );
        expect(find.text('Qué contar'), findsOneWidget);
        expect(find.text('Que no falte'), findsOneWidget);
        expect(find.byType(VoiceWaveform), findsNothing);
        expect(_byId(VoiceNoteView.doneIdentifier), findsNothing);
        verifyNever(() => cubit.start());
      });

      testWidgets('records on "Grabar"', (tester) async {
        await pumpSubject(tester, const VoiceNoteState());

        await tapVisible(tester, _byId(VoiceNoteView.recordIdentifier));

        verify(() => cubit.start()).called(1);
      });

      testWidgets('disables "Grabar" while the microphone starts', (
        tester,
      ) async {
        await pumpSubject(
          tester,
          const VoiceNoteState(status: VoiceNoteStatus.starting),
        );

        await tapVisible(tester, _byId(VoiceNoteView.recordIdentifier));

        verifyNever(() => cubit.start());
      });

      testWidgets('in English', (tester) async {
        await pumpSubject(
          tester,
          const VoiceNoteState(),
          locale: const Locale('en'),
        );

        expect(find.text('Record'), findsOneWidget);
      });
    });

    group('while reading', () {
      const uploading = VoiceNoteState(status: VoiceNoteStatus.reading);
      const heard = VoiceNoteState(
        status: VoiceNoteStatus.reading,
        stage: VoiceNoteStage.understanding,
        transcript: 'Soy Ana, tengo 34, vivo en Barrio Sur',
      );

      String? valueOf(WidgetTester tester, String label) =>
          tester.getSemantics(find.text(label)).getSemanticsData().value;

      testWidgets('says the note is being read, step by step', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSubject(tester, uploading);

        expect(find.text('Estamos leyendo tu audio'), findsOneWidget);
        expect(valueOf(tester, 'Mandando tu audio'), equals('Ahora'));
        expect(valueOf(tester, 'Escuchándolo'), equals('Falta'));
        expect(valueOf(tester, 'Entendiendo lo que contaste'), equals('Falta'));
        expect(
          tester.getSemantics(find.text('Mandando tu audio')),
          isSemantics(isLiveRegion: true),
        );
        expect(find.text('Esto escuchamos'), findsNothing);
        semantics.dispose();
      });

      testWidgets('ticks the steps done', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSubject(
          tester,
          const VoiceNoteState(
            status: VoiceNoteStatus.reading,
            stage: VoiceNoteStage.listening,
          ),
        );

        expect(valueOf(tester, 'Mandando tu audio'), equals('Listo'));
        expect(valueOf(tester, 'Escuchándolo'), equals('Ahora'));
        expect(find.byIcon(Icons.check_circle), findsOneWidget);
        semantics.dispose();
      });

      testWidgets('shows the words as soon as they are back', (tester) async {
        await pumpSubject(tester, heard);
        await tester.pump(AppMotion.standardDuration);

        expect(find.text('Esto escuchamos'), findsOneWidget);
        expect(
          find.text('«Soy Ana, tengo 34, vivo en Barrio Sur»'),
          findsOneWidget,
        );
        expect(find.text('Tu audio ya se borró.'), findsOneWidget);
        expect(find.byIcon(Icons.check_circle), findsNWidgets(2));
      });

      testWidgets('ticks every step once read', (tester) async {
        await pumpSubject(
          tester,
          const VoiceNoteState(
            status: VoiceNoteStatus.read,
            signup: _signup,
            stage: VoiceNoteStage.understanding,
            transcript: 'Soy Ana',
          ),
        );

        expect(find.byIcon(Icons.check_circle), findsNWidgets(3));
        expect(find.text('Estamos leyendo tu audio'), findsOneWidget);
      });

      testWidgets('changes the barrio line every few seconds', (tester) async {
        await pumpSubject(
          tester,
          uploading,
          states: Stream.value(
            uploading.copyWith(waited: const Duration(seconds: 3)),
          ),
        );
        expect(find.text('Cebando el mate…'), findsOneWidget);

        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Cebando el mate…'), findsNothing);
        expect(find.text('Buscando quién trae los bizcochos…'), findsOneWidget);
      });

      testWidgets('comes round to the first line again', (tester) async {
        await pumpSubject(
          tester,
          uploading.copyWith(
            waited: const Duration(seconds: VoiceReading.lineSeconds * 8),
          ),
        );

        expect(find.text('Cebando el mate…'), findsOneWidget);
      });

      testWidgets('breathes the step under way', (tester) async {
        await pumpSubject(tester, uploading);
        double scale() => tester
            .widget<ScaleTransition>(
              find
                  .ancestor(
                    of: find.byIcon(Icons.radio_button_checked),
                    matching: find.byType(ScaleTransition),
                  )
                  .first,
            )
            .scale
            .value;

        await tester.pump(const Duration(milliseconds: 500));

        expect(scale(), lessThan(1));
      });

      testWidgets('holds still with reduced motion', (tester) async {
        await pumpSubject(tester, uploading, reduced: true);
        double scale() => tester
            .widget<ScaleTransition>(
              find
                  .ancestor(
                    of: find.byIcon(Icons.radio_button_checked),
                    matching: find.byType(ScaleTransition),
                  )
                  .first,
            )
            .scale
            .value;

        await tester.pump(const Duration(milliseconds: 500));

        expect(scale(), equals(1));
      });

      testWidgets('holds 200% text', (tester) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
        await pumpSubject(tester, heard);
        await tester.pump(AppMotion.standardDuration);

        expect(tester.takeException(), isNull);
      });

      testWidgets('in English', (tester) async {
        await pumpSubject(tester, heard, locale: const Locale('en'));
        await tester.pump(AppMotion.standardDuration);

        expect(find.text('Working out your answers'), findsOneWidget);
        expect(find.text("Here's what we heard"), findsOneWidget);
        expect(find.text('Brewing the mate…'), findsOneWidget);
      });
    });

    testWidgets('reads out that the note is being read', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSubject(
        tester,
        const VoiceNoteState(status: VoiceNoteStatus.reading),
      );

      expect(
        tester.getSemantics(find.text('Estamos leyendo tu audio')),
        isSemantics(isHeader: true, isLiveRegion: true),
      );
      semantics.dispose();
    });

    testWidgets('does not read out the recorder as it opens', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSubject(
        tester,
        const VoiceNoteState(status: VoiceNoteStatus.recording),
      );

      expect(
        tester.getSemantics(find.text('Te escuchamos')),
        isSemantics(isHeader: true, isLiveRegion: false),
      );
      semantics.dispose();
    });

    testWidgets('leaves for the buttons with "Cancelar" while reading', (
      tester,
    ) async {
      await pumpSubject(
        tester,
        const VoiceNoteState(status: VoiceNoteStatus.reading),
      );

      await tester.tap(find.text('Cancelar'));

      verify(() => onboarding.voiceCancelled()).called(1);
    });

    for (final state in [
      for (final status in VoiceNoteStatus.values)
        VoiceNoteState(status: status),
      for (final failure in VoiceNoteFailure.values)
        VoiceNoteState(status: VoiceNoteStatus.failed, failure: failure),
    ]) {
      testWidgets('is "Tu audio" in the top bar, with "Cancelar", when '
          '${state.status.name} ${state.failure?.name ?? ''}', (tester) async {
        await pumpSubject(tester, state);

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('Tu audio'),
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsIdentifier(OnboardingStepLayout.backIdentifier),
          findsOneWidget,
        );
      });
    }

    group('moving on', () {
      const recording = VoiceNoteState(status: VoiceNoteStatus.recording);
      const reading = VoiceNoteState(status: VoiceNoteStatus.reading);

      testWidgets('swaps the recorder for the reading screen in place', (
        tester,
      ) async {
        await pumpSubject(tester, recording, states: Stream.value(reading));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('Te escuchamos'), findsOneWidget);
        expect(
          find.ancestor(
            of: find.text('Estamos leyendo tu audio'),
            matching: find.byType(ScaleTransition),
          ),
          findsWidgets,
        );
        expect(find.text('Tu audio'), findsOneWidget);

        await tester.pump(AppMotion.standardDuration);
        expect(find.text('Te escuchamos'), findsNothing);
        expect(find.text('Estamos leyendo tu audio'), findsOneWidget);
      });

      testWidgets('only cross-fades with reduced motion', (tester) async {
        await pumpSubject(
          tester,
          recording,
          states: Stream.value(reading),
          reduced: true,
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          find.ancestor(
            of: find.text('Estamos leyendo tu audio'),
            matching: find.byType(ScaleTransition),
          ),
          findsNothing,
        );
        await tester.pump(AppMotion.crossFade);
        expect(find.text('Te escuchamos'), findsNothing);
      });

      testWidgets('fills the timer bar on from the last second', (
        tester,
      ) async {
        double bar() => tester
            .widget<LinearProgressIndicator>(
              find.byType(LinearProgressIndicator),
            )
            .value!;
        await pumpSubject(
          tester,
          const VoiceNoteState(
            status: VoiceNoteStatus.recording,
            elapsed: Duration(seconds: 30),
          ),
          states: Stream.value(
            const VoiceNoteState(
              status: VoiceNoteStatus.recording,
              elapsed: Duration(seconds: 36),
            ),
          ),
        );
        expect(bar(), closeTo(0.5, 1e-9));

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        expect(bar(), greaterThan(0.5));
        expect(bar(), lessThan(0.6));

        await tester.pumpAndSettle();
        expect(bar(), closeTo(0.6, 1e-9));
      });

      testWidgets('keeps a note read after "Cancelar" from the read-back', (
        tester,
      ) async {
        when(() => onboarding.state).thenReturn(const OnboardingState());
        await pumpSubject(
          tester,
          reading,
          states: Stream.value(
            const VoiceNoteState(status: VoiceNoteStatus.read, signup: _signup),
          ),
        );
        await tester.pump();

        verifyNever(() => onboarding.voiceRead(any()));
      });
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

    VoiceNoteState failed(VoiceNoteFailure failure) =>
        VoiceNoteState(status: VoiceNoteStatus.failed, failure: failure);

    for (final (state, title, body, retry) in [
      (
        const VoiceNoteState(status: VoiceNoteStatus.notUnderstood),
        'No te entendimos bien',
        'Puede ser el ruido, o que fue muy corto. El audio ya se borró y no '
            'guardamos nada.',
        'Grabar de nuevo',
      ),
      (
        failed(VoiceNoteFailure.noMicrophone),
        'No encontramos un micrófono',
        'Conectá uno y probá de nuevo, o seguí tocando botones. No guardamos '
            'nada.',
        'Grabar de nuevo',
      ),
      (
        failed(VoiceNoteFailure.microphoneDenied),
        'No podemos usar el micrófono',
        'El teléfono no nos dejó. No pasa nada: podés darle permiso, o seguir '
            'tocando botones.',
        'Ya le di permiso',
      ),
      (
        failed(VoiceNoteFailure.recorderFailed),
        'No pudimos grabar',
        'El micrófono se cortó o no nos llegó sonido. Probá de nuevo. No '
            'guardamos nada.',
        'Grabar de nuevo',
      ),
      (
        failed(VoiceNoteFailure.uploadFailed),
        'No pudimos mandar el audio',
        'Revisá la conexión a internet y probá de nuevo. No guardamos nada.',
        'Grabar de nuevo',
      ),
      (
        failed(VoiceNoteFailure.readFailed),
        'No pudimos leer el audio',
        'Probá de nuevo en un rato. No guardamos nada.',
        'Grabar de nuevo',
      ),
      (
        const VoiceNoteState(status: VoiceNoteStatus.failed),
        'No pudimos leer el audio',
        'Probá de nuevo en un rato. No guardamos nada.',
        'Grabar de nuevo',
      ),
    ]) {
      group('when ${state.failure?.name ?? state.status.name}', () {
        testWidgets('says what failed and offers "$retry"', (tester) async {
          final semantics = tester.ensureSemantics();
          await pumpSubject(tester, state);

          expect(find.text(title), findsOneWidget);
          expect(find.text(body), findsOneWidget);
          expect(
            tester.getSemantics(find.text(title)),
            isSemantics(isHeader: true, isLiveRegion: true),
          );
          await tapVisible(tester, find.text(retry));

          verify(() => cubit.start()).called(1);
          semantics.dispose();
        });

        testWidgets('offers the buttons instead', (tester) async {
          await pumpSubject(tester, state);

          await tapVisible(tester, _byId(VoiceNoteView.buttonsIdentifier));

          verify(() => onboarding.voiceCancelled()).called(1);
        });
      });
    }

    for (final (failure, title, body) in [
      (
        VoiceNoteFailure.uploadRefused,
        'No pudimos mandar el audio',
        'Es un problema nuestro, no tuyo. Mientras lo arreglamos, seguí '
            'tocando botones: es igual de rápido. No guardamos nada.',
      ),
      (
        VoiceNoteFailure.termsMissing,
        'Falta aceptar las condiciones',
        'Sin eso no mandamos el audio. Seguí tocando botones: las aceptás al '
            'guardar. No guardamos nada.',
      ),
    ]) {
      testWidgets('when ${failure.name}, offers only the buttons', (
        tester,
      ) async {
        await pumpSubject(tester, failed(failure));

        expect(find.text(title), findsOneWidget);
        expect(find.text(body), findsOneWidget);
        expect(_byId(VoiceNoteView.retryIdentifier), findsNothing);
        await tapVisible(tester, _byId(VoiceNoteView.buttonsIdentifier));

        verify(() => onboarding.voiceCancelled()).called(1);
      });
    }

    testWidgets('says the failure in English', (tester) async {
      await pumpSubject(
        tester,
        failed(VoiceNoteFailure.uploadRefused),
        locale: const Locale('en'),
      );

      expect(find.text("We couldn't send your recording"), findsOneWidget);
    });

    testWidgets('tells a browser how to allow the microphone', (tester) async {
      await pumpSubject(
        tester,
        failed(VoiceNoteFailure.microphoneDenied),
        place: PermissionPlace.browser,
      );

      expect(
        find.text(
          'El navegador no nos dejó usar el micrófono. No pasa nada: podés '
          'darle permiso, o seguir tocando botones.',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '1. Tocá el candado al lado de la dirección, arriba de todo.',
        ),
        findsOneWidget,
      );
      expect(
        find.text('3. Volvé acá y tocá «Ya le di permiso».'),
        findsOneWidget,
      );
    });

    testWidgets("tells an iPhone's browser to allow it in Ajustes", (
      tester,
    ) async {
      await pumpSubject(
        tester,
        failed(VoiceNoteFailure.microphoneDenied),
        place: PermissionPlace.iPhoneBrowser,
      );

      expect(
        find.text(
          '1. Abrí Ajustes del iPhone, entrá en Chrome (o en Safari) y prendé '
          '«Micrófono».',
        ),
        findsOneWidget,
      );
      expect(
        find.text(
          '3. Si no te vuelve a preguntar, recargá esta página y tocá '
          '«Permitir».',
        ),
        findsOneWidget,
      );
      expect(find.text('Prefiero tocar botones'), findsOneWidget);
    });

    testWidgets('lists the three steps to allow the microphone', (
      tester,
    ) async {
      await pumpSubject(tester, failed(VoiceNoteFailure.microphoneDenied));

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
