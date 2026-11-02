import 'dart:async';

import 'package:error_reporter/error_reporter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/onboarding/widgets/live_words.dart';
import 'package:ronda/small_plan/small_plan.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

import '../../helpers/helpers.dart';

class _MockSmallPlanRepository extends Mock implements SmallPlanRepository;

class _MockErrorReporter extends Mock implements ErrorReporter;

void main() {
  group(SmallPlanSheet, () {
    late SmallPlanRepository repository;
    late ErrorReporter reporter;
    late StreamController<double> levels;
    late StreamController<String> words;
    SmallPlan? chosen;
    var closedWithoutPlan = false;

    final call = SmallPlanSuggestion(
      id: 'call-1',
      kind: SmallPlanKind.call,
      at: DateTime(2026, 11, 3, 18),
      outdoor: false,
    );
    final walk = SmallPlanSuggestion(
      id: 'walk-1',
      kind: SmallPlanKind.walk,
      at: DateTime(2026, 11, 4, 18),
      outdoor: true,
      place: 'la Plaza de los Aromos',
      dry: true,
    );
    final said = SmallPlanRead(
      plan: SmallPlan(
        kind: SmallPlanKind.walk,
        at: DateTime(2026, 11, 3, 19),
        activity: 'Caminar 30 minutos por la rambla',
        place: 'desde la parada 23',
      ),
      moved: true,
      dry: true,
    );

    setUp(() {
      chosen = null;
      closedWithoutPlan = false;
      repository = _MockSmallPlanRepository();
      reporter = _MockErrorReporter();
      levels = StreamController<double>.broadcast();
      words = StreamController<String>.broadcast();
      addTearDown(() => unawaited(levels.close()));
      addTearDown(() => unawaited(words.close()));
      when(() => repository.suggestions())
          .thenAnswer((_) async => [walk, call]);
      when(() => repository.startVoiceNote('uid')).thenAnswer((_) async {});
      when(() => repository.voiceLevels()).thenAnswer((_) => levels.stream);
      when(() => repository.liveWords()).thenAnswer((_) => words.stream);
      when(() => repository.discardVoiceNote()).thenAnswer((_) async {});
      when(() => repository.shapeVoiceNote('uid'))
          .thenAnswer((_) async => said);
      when(() => repository.shapeText('uid', any()))
          .thenAnswer((_) async => said);
      when(
        () => reporter.reportFailure(
          screen: any(named: 'screen'),
          step: any(named: 'step'),
          code: any(named: 'code'),
        ),
      ).thenAnswer((_) async {});
    });

    /// Pumps a button that opens the sheet, and opens it.
    Future<void> open(WidgetTester tester, {Locale? locale}) async {
      await tester.pumpApp(
        MultiRepositoryProvider(
          providers: [
            RepositoryProvider.value(value: repository),
            RepositoryProvider<ErrorReporter>.value(value: reporter),
          ],
          child: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  chosen = await SmallPlanSheet.show(context, uid: 'uid');
                  closedWithoutPlan = chosen == null;
                },
                child: const Text('abrir'),
              ),
            ),
          ),
        ),
        locale: locale ?? rioplatense,
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    Future<void> sayIt(WidgetTester tester) async {
      await tester.tap(find.text('Decilo vos'));
      await tester.pumpAndSettle();
    }

    /// Starts recording and waits out the sheet's swap. Not `pumpAndSettle`:
    /// a recording ticks every second for as long as it runs.
    Future<void> startRecording(WidgetTester tester) async {
      await tester.tap(find.text('Grabar'));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 200));
      }
    }

    /// Lets the real event loop turn once. Stopping a recording awaits the
    /// periodic timer's cancel, which completes in the root zone, out of
    /// reach of the test's fake clock.
    Future<void> letRecorderStop(WidgetTester tester) => tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );

    /// Taps the button with [label], scrolling the sheet to it first.
    Future<void> press(WidgetTester tester, String label) async {
      await tester.ensureVisible(find.text(label));
      await tester.tap(find.text(label));
    }

    group('the ideas', () {
      testWidgets('shows the three of them, each with its day and the '
          'forecast', (tester) async {
        await open(tester);

        expect(find.text('Elegí algo chico'), findsOneWidget);
        expect(
          find.text('Caminar 30 minutos por la Plaza de los Aromos'),
          findsOneWidget,
        );
        expect(find.textContaining('el miércoles a las 18:00'), findsOneWidget);
        expect(find.textContaining('No se espera lluvia'), findsOneWidget);
        expect(
          find.text('Llamar a alguien con quien hace tiempo no hablás'),
          findsOneWidget,
        );
        expect(find.text('Decilo vos'), findsOneWidget);
      });

      testWidgets('closes with the plan of the one that was tapped', (
        tester,
      ) async {
        await open(tester);

        await tester.tap(
          find.text('Llamar a alguien con quien hace tiempo no hablás'),
        );
        await tester.pumpAndSettle();

        expect(chosen, equals(call.plan));
        expect(find.text('Elegí algo chico'), findsNothing);
      });

      testWidgets('says while the ideas load', (tester) async {
        final ideas = Completer<List<SmallPlanSuggestion>>();
        when(() => repository.suggestions()).thenAnswer((_) => ideas.future);
        await tester.pumpApp(
          RepositoryProvider.value(
            value: repository,
            child: Builder(
              builder: (context) => TextButton(
                onPressed: () =>
                    unawaited(SmallPlanSheet.show(context, uid: 'uid')),
                child: const Text('abrir'),
              ),
            ),
          ),
        );

        await tester.tap(find.text('abrir'));
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Buscando ideas cerca tuyo…'), findsOneWidget);
        ideas.complete([call]);
        await tester.pumpAndSettle();
      });

      testWidgets('offers to try again when they could not be had, and '
          'still lets the member say theirs', (tester) async {
        when(
          () => repository.suggestions(),
        ).thenThrow(const SmallPlanFailure(SmallPlanFailureKind.suggestFailed));
        await open(tester);

        expect(
          find.text('No pudimos traer ideas ahora. Podés contarnos la tuya.'),
          findsOneWidget,
        );
        expect(find.text('Decilo vos'), findsOneWidget);

        when(() => repository.suggestions()).thenAnswer((_) async => [call]);
        await press(tester, 'Probar de nuevo');
        await tester.pumpAndSettle();

        expect(
          find.text('Llamar a alguien con quien hace tiempo no hablás'),
          findsOneWidget,
        );
      });

      testWidgets('closes with no plan when it is thrown down', (tester) async {
        await open(tester);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(closedWithoutPlan, isTrue);
      });

      testWidgets('is in English on an English phone', (tester) async {
        await open(tester, locale: const Locale('en'));

        expect(find.text('Pick something small'), findsOneWidget);
        expect(
          find.text("Call someone you haven't talked to in a while"),
          findsOneWidget,
        );
        expect(find.text('Say yours'), findsOneWidget);
      });
    });

    group('typing it', () {
      testWidgets('shapes what was typed and closes once it is '
          'confirmed', (tester) async {
        await open(tester);
        await sayIt(tester);

        expect(find.text('Contanos qué te gustaría hacer'), findsOneWidget);
        await tester.enterText(
          find.byType(TextFormField),
          'caminar por la rambla el martes',
        );
        await press(tester, 'Listo');
        await tester.pumpAndSettle();

        expect(find.text('¿Es esto?'), findsOneWidget);
        expect(
          find.text(
            'Caminar 30 minutos por la rambla, el martes a las 19:00, '
            'desde la parada 23.',
          ),
          findsOneWidget,
        );
        expect(
          find.text('El día que dijiste se espera lluvia, así que lo pasamos.'),
          findsOneWidget,
        );
        expect(find.text('No se espera lluvia ese día.'), findsOneWidget);
        verify(
          () => repository.shapeText('uid', 'caminar por la rambla el martes'),
        ).called(1);

        await press(tester, 'Sí, es esto');
        await tester.pumpAndSettle();

        expect(chosen, equals(said.plan));
      });

      testWidgets('asks for words before sending an empty field', (
        tester,
      ) async {
        await open(tester);
        await sayIt(tester);

        await press(tester, 'Listo');
        await tester.pumpAndSettle();

        expect(find.text('Escribí algo primero.'), findsOneWidget);
        verifyNever(() => repository.shapeText(any(), any()));
      });

      testWidgets('says when what was typed is too long', (tester) async {
        await open(tester);
        await sayIt(tester);

        await tester.enterText(find.byType(TextFormField), 'a' * 301);
        await tester.pumpAndSettle();

        expect(find.text('Es muy largo. Que sea corto.'), findsOneWidget);
      });

      testWidgets('goes back to the ideas', (tester) async {
        await open(tester);
        await sayIt(tester);

        await press(tester, 'Volver a las ideas');
        await tester.pumpAndSettle();

        expect(find.text('Elegí algo chico'), findsOneWidget);
      });

      testWidgets('lets the member try again from the plan we made', (
        tester,
      ) async {
        await open(tester);
        await sayIt(tester);
        await tester.enterText(find.byType(TextFormField), 'caminar');
        await press(tester, 'Listo');
        await tester.pumpAndSettle();

        await press(tester, 'Probar de nuevo');
        await tester.pumpAndSettle();

        expect(find.text('Contanos qué te gustaría hacer'), findsOneWidget);
      });

      testWidgets('says plainly when a plan was left out, whatever the '
          'reason', (tester) async {
        when(() => repository.shapeText('uid', any())).thenAnswer(
          (_) async => const SmallPlanDropped(PlanDropReason.health),
        );
        await open(tester);
        await sayIt(tester);

        await tester.enterText(find.byType(TextFormField), 'algo');
        await press(tester, 'Listo');
        await tester.pumpAndSettle();

        expect(
          find.textContaining('No pudimos armar un plan con eso.'),
          findsOneWidget,
        );
        expect(find.textContaining('salud'), findsNothing);
        expect(find.textContaining('health'), findsNothing);
      });

      testWidgets('says what failed, and tells the error log', (tester) async {
        when(() => repository.shapeText('uid', any())).thenThrow(
          const SmallPlanFailure(SmallPlanFailureKind.readFailed, code: 'x'),
        );
        await open(tester);
        await sayIt(tester);

        await tester.enterText(find.byType(TextFormField), 'algo');
        await press(tester, 'Listo');
        await tester.pumpAndSettle();

        expect(find.textContaining('No pudimos leerlo.'), findsOneWidget);
        verify(
          () => reporter.reportFailure(
            screen: '/ronda',
            step: 'smallPlan',
            code: 'smallPlan/readFailed/x',
          ),
        ).called(1);
      });

      testWidgets('does not tell the error log about a note nobody could '
          'read', (tester) async {
        when(
          () => repository.shapeText('uid', any()),
        ).thenThrow(const SmallPlanFailure(SmallPlanFailureKind.notUnderstood));
        await open(tester);
        await sayIt(tester);

        await tester.enterText(find.byType(TextFormField), 'algo');
        await press(tester, 'Listo');
        await tester.pumpAndSettle();

        expect(find.textContaining('No te entendimos bien.'), findsOneWidget);
        verifyNever(
          () => reporter.reportFailure(
            screen: any(named: 'screen'),
            step: any(named: 'step'),
            code: any(named: 'code'),
          ),
        );
      });
    });

    group('by voice', () {
      testWidgets('records while the waveform follows the voice, then '
          'shapes the note', (tester) async {
        await open(tester);
        await sayIt(tester);

        await startRecording(tester);
        levels.add(0.7);
        await tester.pump(const Duration(seconds: 1));

        expect(find.text('Grabando'), findsOneWidget);
        expect(find.textContaining('de 1:00'), findsOneWidget);

        await press(tester, 'Terminé');
        await letRecorderStop(tester);
        await tester.pumpAndSettle();

        expect(find.text('¿Es esto?'), findsOneWidget);
        verify(() => repository.shapeVoiceNote('uid')).called(1);
      });

      testWidgets('warns when nothing is heard', (tester) async {
        await open(tester);
        await sayIt(tester);
        await startRecording(tester);

        await tester.pump(const Duration(seconds: 3));
        await tester.pump();

        expect(
          find.text('No te escuchamos. Revisá el micrófono.'),
          findsOneWidget,
        );
        await press(tester, 'Cancelar');
        await letRecorderStop(tester);
        await tester.pumpAndSettle();
      });

      testWidgets('shows the words heard so far once there are some', (
        tester,
      ) async {
        await open(tester);
        await sayIt(tester);
        await startRecording(tester);
        expect(find.byType(LiveWords), findsNothing);

        words.add('mate en la rambla');
        await tester.pump();

        expect(find.text('Lo que vamos escuchando'), findsOneWidget);
        expect(find.text('mate en la rambla'), findsOneWidget);
        await press(tester, 'Cancelar');
        await letRecorderStop(tester);
        await tester.pumpAndSettle();
      });

      testWidgets('throws the note away on cancel', (tester) async {
        await open(tester);
        await sayIt(tester);
        await startRecording(tester);

        await press(tester, 'Cancelar');
        await letRecorderStop(tester);
        await tester.pumpAndSettle();

        expect(find.text('Contanos qué te gustaría hacer'), findsOneWidget);
        verify(() => repository.discardVoiceNote()).called(greaterThan(0));
      });

      testWidgets('says the microphone is not available, without telling '
          'the error log', (tester) async {
        when(() => repository.startVoiceNote('uid')).thenThrow(
          const SmallPlanFailure(SmallPlanFailureKind.microphoneDenied),
        );
        await open(tester);
        await sayIt(tester);

        await press(tester, 'Grabar');
        await tester.pumpAndSettle();

        expect(
          find.textContaining('Ronda no puede usar el micrófono.'),
          findsOneWidget,
        );
        verifyNever(
          () => reporter.reportFailure(
            screen: any(named: 'screen'),
            step: any(named: 'step'),
            code: any(named: 'code'),
          ),
        );
      });

      testWidgets('says while the note is read', (tester) async {
        final reading = Completer<SmallPlanReading>();
        when(() => repository.shapeVoiceNote('uid'))
            .thenAnswer((_) => reading.future);
        await open(tester);
        await sayIt(tester);
        await startRecording(tester);

        await press(tester, 'Terminé');
        await letRecorderStop(tester);
        await tester.pump(const Duration(milliseconds: 600));

        expect(find.text('Armando tu plan…'), findsOneWidget);
        reading.complete(said);
        await tester.pumpAndSettle();
      });
    });
  });
}
