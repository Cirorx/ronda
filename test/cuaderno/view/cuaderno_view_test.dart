import 'dart:typed_data';

import 'package:bloc_test/bloc_test.dart';
import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/cuaderno/cuaderno.dart';
import 'package:ronda/onboarding/widgets/live_words.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockCuadernoCubit extends MockCubit<CuadernoState>
    implements CuadernoCubit;

class _MockLineVoiceCubit extends MockCubit<LineVoiceState>
    implements LineVoiceCubit;

class _MockErrorReporter extends Mock implements ErrorReporter;

CuadernoEntry _line(int day, String text) =>
    CuadernoEntry(day: DateTime(2026, 10, day), text: text);

/// A valid 1 × 1 PNG, so `Image.memory` decodes.
final _png = Uint8List.fromList(const [
  0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D, //
  0x49, 0x48, 0x44, 0x52, 0x00, 0x00, 0x00, 0x01, 0x00, 0x00, 0x00, 0x01,
  0x08, 0x06, 0x00, 0x00, 0x00, 0x1F, 0x15, 0xC4, 0x89, 0x00, 0x00, 0x00,
  0x0D, 0x49, 0x44, 0x41, 0x54, 0x78, 0x9C, 0x63, 0xF8, 0xFF, 0xFF, 0x3F,
  0x00, 0x05, 0xFE, 0x02, 0xFE, 0xA7, 0x35, 0x81, 0x84, 0x00, 0x00, 0x00,
  0x00, 0x49, 0x45, 0x4E, 0x44, 0xAE, 0x42, 0x60, 0x82,
]);

void main() {
  group(CuadernoView, () {
    late CuadernoCubit cubit;
    late LineVoiceCubit voice;
    late ErrorReporter reporter;

    final entries = [_line(29, 'El jacarandá floreció.'), _line(27, 'Llovió.')];
    final today = DateTime(2026, 10, 30);
    final saturday = DateTime(2026, 10, 31);
    final ready = CuadernoState(
      status: CuadernoStatus.ready,
      cuaderno: Cuaderno(entries: entries),
      today: today,
    );

    setUpAll(() => registerFallbackValue(_line(1, 'x')));

    setUp(() {
      cubit = _MockCuadernoCubit();
      voice = _MockLineVoiceCubit();
      reporter = _MockErrorReporter();
      when(() => cubit.state).thenReturn(ready);
      when(() => voice.state).thenReturn(const LineVoiceState());
      when(() => cubit.writeToday(any())).thenAnswer((_) async {});
      when(() => cubit.retry()).thenAnswer((_) async {});
      when(() => cubit.deleteEntry(any())).thenAnswer((_) async {});
      when(() => cubit.restoreEntry(any())).thenAnswer((_) async {});
      when(() => cubit.bringToggled(any(), bring: any(named: 'bring')))
          .thenAnswer((_) async {});
      when(() => cubit.postcardRequested()).thenAnswer((_) async {});
      when(() => cubit.shareRequested(title: any(named: 'title')))
          .thenAnswer((_) async {});
      when(() => voice.start()).thenAnswer((_) async {});
      when(() => voice.finish()).thenAnswer((_) async {});
      when(() => voice.cancel()).thenAnswer((_) async {});
      when(() => voice.textTaken()).thenReturn(null);
      when(
        () => reporter.reportFailure(
          screen: any(named: 'screen'),
          step: any(named: 'step'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async {});
    });

    Future<void> pump(
      WidgetTester tester, {
      PermissionPlace place = PermissionPlace.app,
      Locale locale = rioplatense,
      Size size = const Size(360, 1600),
    }) async {
      await tester.pumpApp(
        RepositoryProvider<ErrorReporter>.value(
          value: reporter,
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: voice),
            ],
            child: CuadernoView(place: place),
          ),
        ),
        locale: locale,
        size: size,
      );
      await tester.pump();
    }

    group('while it reads', () {
      testWidgets('says so', (tester) async {
        when(() => cubit.state).thenReturn(const CuadernoState());

        await pump(tester);

        expect(find.text('Abriendo tu cuaderno…'), findsOneWidget);
      });

      testWidgets('says when it could not, and tries again', (tester) async {
        when(() => cubit.state)
            .thenReturn(const CuadernoState(status: CuadernoStatus.failure));
        await pump(tester);

        expect(find.text('No pudimos abrir tu cuaderno.'), findsOneWidget);
        await tester.tap(find.text('Probar de nuevo'));

        verify(() => cubit.retry()).called(1);
      });
    });

    group("today's line", () {
      testWidgets('asks "¿Qué viste hoy?" under the title', (tester) async {
        await pump(tester);

        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text('El cuaderno del barrio'),
          ),
          findsOneWidget,
        );
        expect(find.text('¿Qué viste hoy?'), findsOneWidget);
        expect(find.text('Anotar'), findsOneWidget);
      });

      testWidgets('keeps "Anotar" off until something is written', (
        tester,
      ) async {
        await pump(tester);

        final button = tester.widget<FilledButton>(
          find.widgetWithText(FilledButton, 'Anotar'),
        );
        expect(button.onPressed, isNull);

        await tester.enterText(find.byType(TextField), 'El río estaba claro');
        await tester.pump();

        await tester.tap(find.widgetWithText(FilledButton, 'Anotar'));
        verify(() => cubit.writeToday('El río estaba claro')).called(1);
      });

      testWidgets("writes from the keyboard's done", (tester) async {
        await pump(tester);

        await tester.enterText(find.byType(TextField), 'Una línea');
        await tester.testTextInput.receiveAction(TextInputAction.done);

        verify(() => cubit.writeToday('Una línea')).called(1);
      });

      testWidgets('never takes a line break', (tester) async {
        await pump(tester);

        await tester.enterText(find.byType(TextField), 'uno\ndos');

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          equals('unodos'),
        );
      });

      testWidgets('shows no counter', (tester) async {
        await pump(tester);

        expect(find.text('0/280'), findsNothing);
      });

      testWidgets('shows what was written today, to change', (tester) async {
        when(() => cubit.state).thenReturn(
          CuadernoState(
            status: CuadernoStatus.ready,
            cuaderno: Cuaderno(entries: [_line(30, 'Hoy salió el sol.')]),
            today: today,
          ),
        );

        await pump(tester);

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          equals('Hoy salió el sol.'),
        );
        expect(find.text('Cambiar lo de hoy'), findsOneWidget);
      });

      testWidgets('says "Anotado." once written, and not while saving', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(ready.copyWith(wrote: true));
        await pump(tester);
        expect(find.text('Anotado.'), findsOneWidget);

        when(() => cubit.state)
            .thenReturn(ready.copyWith(wrote: true, writing: true));
        await tester.pumpWidget(const SizedBox());
        await pump(tester);
        expect(find.text('Anotado.'), findsNothing);
      });
    });

    group('by voice', () {
      testWidgets('waits for the tap', (tester) async {
        await pump(tester);

        await tester.tap(find.text('Decilo con la voz'));

        verify(() => voice.start()).called(1);
      });

      testWidgets('does not start twice while starting', (tester) async {
        when(() => voice.state)
            .thenReturn(const LineVoiceState(status: LineVoiceStatus.starting));
        await pump(tester);

        final button = tester.widget<OutlinedButton>(
          find.ancestor(
            of: find.text('Decilo con la voz'),
            matching: find.byType(OutlinedButton),
          ),
        );
        expect(button.onPressed, isNull);
      });

      testWidgets('shows the recorder, then "Terminé" reads it', (
        tester,
      ) async {
        when(() => voice.state).thenReturn(
          const LineVoiceState(
            status: LineVoiceStatus.recording,
            elapsed: Duration(seconds: 7),
            levels: [0.2, 0.5],
            heard: 2,
          ),
        );
        await pump(tester);

        expect(find.text('Grabando'), findsOneWidget);
        expect(find.text('0:07 de 0:30'), findsOneWidget);
        expect(
          find.text('El audio se borra apenas lo leemos.'),
          findsOneWidget,
        );
        expect(find.byType(TextField), findsNothing);

        await tester.tap(find.text('Terminé'));
        verify(() => voice.finish()).called(1);
      });

      testWidgets('shows the words heard so far, with their caption', (
        tester,
      ) async {
        when(() => voice.state).thenReturn(
          const LineVoiceState(
            status: LineVoiceStatus.recording,
            words: 'El jacarandá',
          ),
        );
        await pump(tester);

        expect(find.byType(LiveWords), findsOneWidget);
        expect(find.text('Lo que vamos escuchando'), findsOneWidget);
        expect(find.text('El jacarandá'), findsOneWidget);
      });

      testWidgets('shows no words before any is heard', (tester) async {
        when(
          () => voice.state,
        ).thenReturn(const LineVoiceState(status: LineVoiceStatus.recording));
        await pump(tester);

        expect(find.byType(LiveWords), findsNothing);
      });

      testWidgets('"Cancelar" throws the recording away', (tester) async {
        when(
          () => voice.state,
        ).thenReturn(const LineVoiceState(status: LineVoiceStatus.recording));
        await pump(tester);

        await tester.tap(find.text('Cancelar'));

        verify(() => voice.cancel()).called(1);
      });

      testWidgets('says it is reading', (tester) async {
        when(() => voice.state)
            .thenReturn(const LineVoiceState(status: LineVoiceStatus.reading));
        await pump(tester);

        expect(find.text('Pasando tu audio a texto…'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsOneWidget);
      });

      testWidgets('puts the words in the field to change', (tester) async {
        whenListen(
          voice,
          Stream.value(
            const LineVoiceState(
              status: LineVoiceStatus.read,
              text: 'El jacarandá floreció.',
            ),
          ),
          initialState: const LineVoiceState(),
        );
        await pump(tester);
        await tester.pump();

        expect(
          tester.widget<TextField>(find.byType(TextField)).controller!.text,
          equals('El jacarandá floreció.'),
        );
        verify(() => voice.textTaken()).called(1);
      });

      for (final (problem, text) in [
        (
          VoiceLineProblem.noMicrophone,
          'No encontramos un micrófono. Podés escribir la línea.',
        ),
        (
          VoiceLineProblem.microphoneDenied,
          'El teléfono no nos dejó usar el micrófono. Podés darle permiso en '
              'los ajustes, o escribir la línea.',
        ),
        (
          VoiceLineProblem.notUnderstood,
          'No pudimos entender el audio. Probá de nuevo más cerca del '
              'teléfono, o escribí la línea. El audio ya se borró.',
        ),
        (
          VoiceLineProblem.termsMissing,
          'Para usar la voz hay que aceptar las condiciones. Podés escribir '
              'la línea.',
        ),
        (
          VoiceLineProblem.readFailed,
          'No pudimos pasar el audio a texto. Probá de nuevo en un rato, o '
              'escribí la línea.',
        ),
      ]) {
        testWidgets('says $problem and leaves the field to type in', (
          tester,
        ) async {
          when(() => voice.state).thenReturn(
            LineVoiceState(status: LineVoiceStatus.failed, problem: problem),
          );
          await pump(tester);

          expect(find.text(text), findsOneWidget);
          expect(find.byType(TextField), findsOneWidget);
        });
      }

      testWidgets('sends the browser to its address bar', (tester) async {
        when(() => voice.state).thenReturn(
          const LineVoiceState(
            status: LineVoiceStatus.failed,
            problem: VoiceLineProblem.microphoneDenied,
          ),
        );
        await pump(tester, place: PermissionPlace.browser);

        expect(find.textContaining('candado'), findsOneWidget);
      });

      testWidgets("sends an iPhone's browser to Ajustes, or to typing", (
        tester,
      ) async {
        when(() => voice.state).thenReturn(
          const LineVoiceState(
            status: LineVoiceStatus.failed,
            problem: VoiceLineProblem.microphoneDenied,
          ),
        );
        await pump(tester, place: PermissionPlace.iPhoneBrowser);

        expect(
          find.text(
            'El iPhone no nos dejó usar el micrófono. Prendelo en Ajustes → '
            'Chrome (o Safari) → Micrófono, o escribí la línea.',
          ),
          findsOneWidget,
        );
      });

      testWidgets("reports a failure that is Ronda's, once, with the code", (
        tester,
      ) async {
        whenListen(
          voice,
          Stream.value(
            const LineVoiceState(
              status: LineVoiceStatus.failed,
              problem: VoiceLineProblem.uploadFailed,
              problemCode: 'retry-limit-exceeded',
            ),
          ),
          initialState: const LineVoiceState(),
        );

        await pump(tester);
        await tester.pump();

        verify(
          () => reporter.reportFailure(
            screen: CuadernoPage.path,
            step: CuadernoView.reportStep,
            code: 'voice/uploadFailed/retry-limit-exceeded',
          ),
        ).called(1);
      });

      for (final problem in [
        VoiceLineProblem.noMicrophone,
        VoiceLineProblem.microphoneDenied,
      ]) {
        testWidgets('does not report $problem: it is the person setup', (
          tester,
        ) async {
          whenListen(
            voice,
            Stream.value(
              LineVoiceState(status: LineVoiceStatus.failed, problem: problem),
            ),
            initialState: const LineVoiceState(),
          );

          await pump(tester);
          await tester.pump();

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

    group('failures', () {
      for (final (failure, text) in [
        (
          CuadernoFailure.write,
          'No pudimos guardarlo en este teléfono. Probá de nuevo.',
        ),
        (
          CuadernoFailure.postcard,
          'No pudimos dibujarla. Probá de nuevo en un rato.',
        ),
        (
          CuadernoFailure.nothingToDraw,
          'No encontramos nada para dibujar en las líneas de esta semana. '
              'Probá con cosas y lugares que viste.',
        ),
        (CuadernoFailure.share, 'No pudimos abrir el menú de compartir.'),
      ]) {
        testWidgets('says $failure', (tester) async {
          when(() => cubit.state)
              .thenReturn(ready.copyWith(failure: () => failure));

          await pump(tester);

          expect(find.text(text), findsOneWidget);
        });
      }
    });

    group('the lines', () {
      testWidgets('lists them newest first, with no count', (tester) async {
        await pump(tester);

        expect(find.text('Tus líneas'), findsOneWidget);
        expect(find.text('El jacarandá floreció.'), findsOneWidget);
        expect(find.text('Llovió.'), findsOneWidget);
        expect(find.textContaining('jueves 29/10'), findsOneWidget);
        expect(find.textContaining(RegExp(r'\d+ líneas?')), findsNothing);
        expect(
          find.text('Tu cuaderno queda en este teléfono. No lo lee nadie más.'),
          findsOneWidget,
        );
      });

      testWidgets('says what an empty cuaderno needs, and no more', (
        tester,
      ) async {
        when(
          () => cubit.state,
        ).thenReturn(CuadernoState(status: CuadernoStatus.ready, today: today));

        await pump(tester);

        expect(
          find.text('Todavía no anotaste nada. Alcanza con lo que veas hoy.'),
          findsOneWidget,
        );
      });

      Future<void> openMenu(WidgetTester tester, String day) async {
        await tester.tap(find.byTooltip('Opciones de la línea del $day'));
        await tester.pumpAndSettle();
      }

      testWidgets('brings one to the meeting', (tester) async {
        await pump(tester);

        await openMenu(tester, 'jueves 29/10');
        await tester.tap(find.text('Llevar esta línea'));

        verify(() => cubit.bringToggled(entries.first, bring: true)).called(1);
      });

      testWidgets('marks the one brought, and stops bringing it', (
        tester,
      ) async {
        when(() => cubit.state).thenReturn(
          CuadernoState(
            status: CuadernoStatus.ready,
            cuaderno: Cuaderno(entries: entries, bringDay: entries.first.day),
            today: today,
          ),
        );
        await pump(tester);
        expect(find.text('Llevás esta.'), findsOneWidget);

        await openMenu(tester, 'jueves 29/10');
        await tester.tap(find.text('Ya no la llevo'));

        verify(() => cubit.bringToggled(entries.first, bring: false)).called(1);
      });

      testWidgets('deletes one, and can undo', (tester) async {
        await pump(tester);

        await openMenu(tester, 'jueves 29/10');
        await tester.tap(find.text('Borrar esta línea'));
        await tester.pumpAndSettle();
        verify(() => cubit.deleteEntry(entries.first)).called(1);
        expect(find.text('Línea borrada.'), findsOneWidget);

        await tester.tap(find.text('Deshacer'));
        verify(() => cubit.restoreEntry(entries.first)).called(1);
      });
    });

    group('the postcard', () {
      final offered = ready.copyWith(meetingDate: () => saturday);

      testWidgets('is not mentioned until it is time', (tester) async {
        await pump(tester);

        expect(find.text('Tu postal de la semana'), findsNothing);
      });

      testWidgets('is offered, with what it sends and keeps', (tester) async {
        when(() => cubit.state).thenReturn(offered);
        await pump(tester);

        expect(find.text('Tu postal de la semana'), findsOneWidget);
        expect(
          find.textContaining('Mandamos las líneas, sin nombres'),
          findsOneWidget,
        );

        await tester.tap(find.text('Dibujar la postal'));
        verify(() => cubit.postcardRequested()).called(1);
      });

      testWidgets('says while it is drawn', (tester) async {
        when(() => cubit.state)
            .thenReturn(offered.copyWith(makingPostcard: true));
        await pump(tester);

        expect(
          find.text('Dibujando tu postal. Tarda unos segundos.'),
          findsOneWidget,
        );
        expect(find.text('Dibujar la postal'), findsNothing);
      });

      testWidgets('shows the picture, saves it, and draws another', (
        tester,
      ) async {
        when(() => cubit.state)
            .thenReturn(offered.copyWith(postcard: () => Postcard(_png)));
        await pump(tester);

        // Read the label off the widget: the semantics tree depends on what
        // earlier tests in the same isolate left on, so it flips with order.
        expect(
          tester.widget<Image>(find.byType(Image)).semanticLabel,
          'Postal de tu semana, dibujada con tus líneas',
        );

        await tester.tap(find.text('Guardar en el teléfono'));
        verify(() => cubit.shareRequested(title: 'Postal del barrio'))
            .called(1);
        await tester.tap(find.text('Dibujar otra'));
        verify(() => cubit.postcardRequested()).called(1);
      });

      testWidgets('stays on screen after the offer ends, with no new draw', (
        tester,
      ) async {
        when(() => cubit.state)
            .thenReturn(ready.copyWith(postcard: () => Postcard(_png)));
        await pump(tester);

        expect(find.byType(Image), findsOneWidget);
        expect(find.text('Dibujar otra'), findsNothing);
      });
    });

    testWidgets('in English', (tester) async {
      await pump(tester, locale: const Locale('en'));

      expect(find.text('What did you see today?'), findsOneWidget);
    });

    testWidgets('keeps to a readable column on a desktop window', (
      tester,
    ) async {
      await pump(tester, size: desktopSize);

      expect(find.byType(ReadableColumn), findsOneWidget);
    });

    testWidgets('has no overflow at large text', (tester) async {
      await tester.pumpApp(
        RepositoryProvider<ErrorReporter>.value(
          value: reporter,
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: cubit),
              BlocProvider.value(value: voice),
            ],
            child: const CuadernoView(),
          ),
        ),
        textScale: 2,
      );
      await tester.pump();

      expect(tester.takeException(), isNull);
    });
  });
}
