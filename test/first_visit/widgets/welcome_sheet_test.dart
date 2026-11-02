import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/first_visit/first_visit.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';
import '../fixtures.dart';

class _MockFirstVisitCubit extends MockCubit<FirstVisitState>
    implements FirstVisitCubit;

class _MockRondaRepository extends Mock implements RondaRepository;

void main() {
  group(WelcomeSheet, () {
    late FirstVisitCubit cubit;

    setUpAll(() => registerFallbackValue(FirstVisitFixtures.open));

    setUp(() {
      cubit = _MockFirstVisitCubit();
      when(cubit.sheetOpened).thenReturn(null);
      when(
        () => cubit.picked(
          any(),
          waiterUid: any(named: 'waiterUid'),
          sign: any(named: 'sign'),
        ),
      ).thenAnswer((_) async {});
    });

    /// Opens the sheet over a button for [welcome], as [uid].
    Future<void> open(
      WidgetTester tester, {
      Welcome? welcome,
      String uid = 'demo-101',
      FirstVisitState state = const FirstVisitState(),
    }) async {
      tester.view
        ..physicalSize = const Size(360, 1600)
        ..devicePixelRatio = 1;
      if (cubit is _MockFirstVisitCubit) {
        when(() => cubit.state).thenReturn(state);
      }
      await tester.pumpApp(
        size: tester.view.physicalSize,
        BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () => WelcomeSheet.show(
                  context,
                  uid: uid,
                  welcome: welcome ?? FirstVisitFixtures.open,
                ),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      // A ring may spin on «Guardar»: settle by time, not by frames.
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
    }

    testWidgets('offers [Espero yo] and the other members, and the preview', (
      tester,
    ) async {
      await open(tester);

      expect(find.text('¿Quién espera a Nico?'), findsOneWidget);
      expect(find.text('Espero yo'), findsOneWidget);
      expect(find.text('Ana'), findsOneWidget);
      expect(find.text('Jorge'), findsOneWidget);
      expect(find.text('Mirta'), findsNothing);
      expect(find.text('Esto es lo que ve Nico:'), findsOneWidget);
      expect(find.text('Te espera Mirta.'), findsOneWidget);
      verify(cubit.sheetOpened).called(1);
    });

    testWidgets('the preview follows the choice and the line as typed', (
      tester,
    ) async {
      await open(tester);

      await tester.tap(find.text('Jorge'));
      await tester.enterText(find.byType(TextField), 'tiene el termo verde');
      await tester.pump();

      expect(
        find.text('Te espera Jorge — tiene el termo verde.'),
        findsOneWidget,
      );
    });

    testWidgets('«Guardar» saves the choice and the line, felt as a commit', (
      tester,
    ) async {
      final haptics = recordHaptics(tester);
      await open(tester);

      await tester.tap(find.text('Ana'));
      await tester.enterText(find.byType(TextField), 'con gorra roja');
      await tester.tap(find.text('Guardar'));
      await tester.pump();

      verify(
        () => cubit.picked(
          FirstVisitFixtures.open,
          waiterUid: 'demo-103',
          sign: 'con gorra roja',
        ),
      ).called(1);
      expect(haptics, [commitHaptic]);
    });

    testWidgets('starts from the last pick and its line', (tester) async {
      await open(tester, welcome: FirstVisitFixtures.picked);

      await tester.tap(find.text('Guardar'));
      await tester.pump();

      verify(
        () => cubit.picked(
          FirstVisitFixtures.picked,
          waiterUid: 'demo-102',
          sign: 'tiene el termo verde',
        ),
      ).called(1);
    });

    testWidgets('a host who is not coming cannot wait, and starts on the '
        'first member', (tester) async {
      await open(tester, uid: 'demo-104');

      expect(find.text('Espero yo'), findsNothing);
      expect(find.text('Te espera Ana.'), findsOneWidget);
    });

    testWidgets('closes once saved', (tester) async {
      final repository = _MockRondaRepository();
      final saved = Completer<void>();
      when(
        () => repository.setWelcome(
          rondaId: any(named: 'rondaId'),
          newcomerUid: any(named: 'newcomerUid'),
          waiterUid: any(named: 'waiterUid'),
          sign: any(named: 'sign'),
        ),
      ).thenAnswer((_) => saved.future);
      cubit = FirstVisitCubit(uid: 'demo-101', rondaRepository: repository);
      addTearDown(cubit.close);
      await open(tester);

      await tester.tap(find.text('Guardar'));
      await tester.pump();
      saved.complete();
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));

      expect(find.byType(WelcomeSheet), findsNothing);
    });

    testWidgets('while saving, «Guardar» says so and sends nothing more', (
      tester,
    ) async {
      await open(
        tester,
        state: const FirstVisitState(save: WelcomeSaveStatus.saving),
      );

      expect(find.text('Guardando…'), findsOneWidget);
      await tester.tap(find.text('Guardando…'), warnIfMissed: false);
      verifyNever(
        () => cubit.picked(
          any(),
          waiterUid: any(named: 'waiterUid'),
          sign: any(named: 'sign'),
        ),
      );
    });

    for (final (reason, words) in [
      (
        WelcomeFailureReason.emoji,
        'No se guardó: tiene un emoji. Escribilo sin emojis.',
      ),
      (
        WelcomeFailureReason.voseo,
        'No se guardó: Ronda escribe con vos («tenés», no «tienes»).',
      ),
      (WelcomeFailureReason.money, 'No se guardó: dejá la plata afuera.'),
      (
        WelcomeFailureReason.notPublic,
        'No se guardó: parece una dirección o una casa. Decí cómo reconocer '
            'a quien espera, no dónde vive.',
      ),
      (WelcomeFailureReason.other, 'No se guardó. Probá de nuevo.'),
    ]) {
      testWidgets('says why when $reason held it', (tester) async {
        await open(
          tester,
          state: FirstVisitState(
            save: WelcomeSaveStatus.failed,
            failure: reason,
          ),
        );

        expect(find.text(words), findsOneWidget);
        expect(find.byType(NoteBanner), findsOneWidget);
      });
    }

    testWidgets('reads in English too', (tester) async {
      when(() => cubit.state).thenReturn(const FirstVisitState());
      await tester.pumpApp(
        BlocProvider.value(
          value: cubit,
          child: Scaffold(
            body: WelcomeSheet(
              uid: 'demo-101',
              welcome: FirstVisitFixtures.picked,
            ),
          ),
        ),
        locale: const Locale('en'),
      );

      expect(find.text('Who waits for Nico?'), findsOneWidget);
      expect(
        find.text(
          'Nico is coming for the first time on Thursday. Who will wait for '
          'Nico at frente al quiosco at 15:50?',
        ),
        findsOneWidget,
      );
      expect(
        find.text('Jorge will be waiting for you — tiene el termo verde.'),
        findsOneWidget,
      );
    });
  });
}
