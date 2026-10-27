import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/onboarding/view/steps/steps.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockOnboardingCubit extends MockCubit<OnboardingState>
    implements OnboardingCubit;

const _thursday = Slot(SlotDay.thursday, SlotBand.afternoon);

final _answered = OnboardingState(
  step: OnboardingStep.review,
  pretexts: const {Pretext.mate, Pretext.truco},
  brings: const {Bring.termo},
  slots: {_thursday, const Slot(SlotDay.saturday, SlotBand.morning)},
  barrio: Barrio.solymarNorte,
  ageBand: AgeBand.sixties,
  needs: const {Need.noCar, Need.walkALot},
  firstName: const FirstName.dirty('Marta'),
);

Finder _byId(String identifier) => find.bySemanticsIdentifier(identifier);

void main() {
  group(OnboardingView, () {
    late OnboardingCubit cubit;

    setUpAll(() {
      registerFallbackValue(OnboardingStep.pretexts);
      registerFallbackValue(Barrio.shangrila);
      registerFallbackValue(AgeBand.sixties);
      registerFallbackValue(Need.noCar);
    });

    setUp(() {
      cubit = _MockOnboardingCubit();
      when(() => cubit.save()).thenAnswer((_) async {});
    });

    Future<void> pumpSubject(WidgetTester tester, OnboardingState state) {
      when(() => cubit.state).thenReturn(state);
      return tester.pumpApp(
        BlocProvider.value(value: cubit, child: const OnboardingView()),
      );
    }

    Future<void> tapVisible(WidgetTester tester, Finder finder) async {
      await tester.ensureVisible(finder);
      await tester.pump();
      await tester.tap(finder);
      await tester.pump();
    }

    group('renders', () {
      for (final (step, type, title) in [
        (OnboardingStep.pretexts, PretextsStep, '¿Qué te gustaría hacer?'),
        (OnboardingStep.brings, BringsStep, '¿Qué podés llevar o enseñar?'),
        (OnboardingStep.slots, SlotsStep, '¿Cuándo podés?'),
        (OnboardingStep.barrio, BarrioStep, '¿En qué barrio estás?'),
        (OnboardingStep.ageBand, AgeBandStep, '¿Qué edad tenés, más o menos?'),
        (OnboardingStep.needs, NeedsStep, '¿Hay algo que te complique ir?'),
        (OnboardingStep.firstName, FirstNameStep, '¿Cómo te llamás?'),
      ]) {
        testWidgets('$type for ${step.name}, numbered among the questions', (
          tester,
        ) async {
          await pumpSubject(tester, OnboardingState(step: step));

          expect(find.byType(type), findsOneWidget);
          expect(find.text(title), findsOneWidget);
          final number = OnboardingStep.questions.indexOf(step) + 1;
          expect(find.text('$number de 7'), findsOneWidget);
          expect(find.bySemanticsLabel('Paso $number de 7'), findsOneWidget);
        });
      }

      testWidgets('$ReviewStep for the read-back, without a number', (
        tester,
      ) async {
        await pumpSubject(tester, _answered);

        expect(find.byType(ReviewStep), findsOneWidget);
        expect(find.text('¿Está todo bien?'), findsOneWidget);
        expect(find.byType(LinearProgressIndicator), findsNothing);
      });
    });

    group('back', () {
      testWidgets('is hidden on the first question', (tester) async {
        await pumpSubject(tester, const OnboardingState());

        expect(_byId(OnboardingStepLayout.backIdentifier), findsNothing);
      });

      testWidgets('shows on the first question opened from the read-back', (
        tester,
      ) async {
        await pumpSubject(
          tester,
          _answered.copyWith(
            step: OnboardingStep.pretexts,
            editingFromReview: true,
          ),
        );

        expect(_byId(OnboardingStepLayout.backIdentifier), findsOneWidget);
      });

      testWidgets('calls back when tapped', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(step: OnboardingStep.brings),
        );

        await tester.tap(_byId(OnboardingStepLayout.backIdentifier));

        verify(() => cubit.back()).called(1);
      });

      testWidgets('calls back on the system back button past the first '
          'question', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(step: OnboardingStep.brings),
        );

        await tester.binding.handlePopRoute();
        await tester.pump();

        verify(() => cubit.back()).called(1);
      });

      testWidgets('calls back on the read-back', (tester) async {
        await pumpSubject(tester, _answered);

        await tester.tap(_byId(OnboardingStepLayout.backIdentifier));

        verify(() => cubit.back()).called(1);
      });
    });

    group('next', () {
      testWidgets('is disabled while the question is unanswered', (
        tester,
      ) async {
        await pumpSubject(tester, const OnboardingState());

        await tester.tap(_byId(OnboardingNextButton.identifier));

        verifyNever(() => cubit.next());
        expect(
          tester.getSemantics(_byId(OnboardingNextButton.identifier)),
          isSemantics(label: 'Seguir', isButton: true, isEnabled: false),
        );
      });

      testWidgets('calls next once answered', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(pretexts: {Pretext.mate}),
        );

        await tester.tap(_byId(OnboardingNextButton.identifier));

        verify(() => cubit.next()).called(1);
        expect(
          tester.getSemantics(_byId(OnboardingNextButton.identifier)),
          isSemantics(label: 'Seguir', isButton: true, hasTapAction: true),
        );
      });
    });

    group('answers', () {
      testWidgets('the pretexts with chips', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(pretexts: {Pretext.truco}),
        );

        await tester.tap(find.text('Mate en la rambla'));

        verify(() => cubit.pretextsChanged({Pretext.truco, Pretext.mate}))
            .called(1);
      });

      testWidgets('what they bring with chips', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(step: OnboardingStep.brings),
        );

        await tester.tap(_byId('${BringsStep.identifier}.tengoGanas'));

        verify(() => cubit.bringsChanged({Bring.tengoGanas})).called(1);
        expect(find.text('Tengo ganas'), findsOneWidget);
      });

      testWidgets('the slots on the grid', (tester) async {
        await pumpSubject(
          tester,
          OnboardingState(
            step: OnboardingStep.slots,
            slots: {const Slot(SlotDay.monday, SlotBand.morning)},
          ),
        );

        await tester.tap(_byId('${SlotsStep.identifier}.3.1'));

        verify(
          () => cubit.slotsChanged({
            const Slot(SlotDay.monday, SlotBand.morning),
            _thursday,
          }),
        ).called(1);
        expect(find.bySemanticsLabel('Jueves a la tarde'), findsOneWidget);
        expect(find.bySemanticsLabel('Lunes a la mañana'), findsOneWidget);
        expect(find.bySemanticsLabel('Domingo a la noche'), findsOneWidget);
      });

      testWidgets('the barrio with one chip', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(
            step: OnboardingStep.barrio,
            barrio: Barrio.shangrila,
          ),
        );

        await tapVisible(tester, find.text('Solymar Norte'));

        verify(() => cubit.barrioChanged(Barrio.solymarNorte)).called(1);
      });

      testWidgets('the age band with one chip', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(
            step: OnboardingStep.ageBand,
            ageBand: AgeBand.thirties,
          ),
        );

        await tapVisible(tester, find.text('Sesenta y pico'));

        verify(() => cubit.ageBandChanged(AgeBand.sixties)).called(1);
      });

      testWidgets('the needs with switches, kept on the phone', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(
            step: OnboardingStep.needs,
            needs: {Need.walkALot},
          ),
        );

        expect(
          find.text('Queda guardado solo en este teléfono'),
          findsOneWidget,
        );
        await tapVisible(tester, _byId('${NeedsStep.identifier}.noCar'));
        await tapVisible(tester, _byId('${NeedsStep.identifier}.walkALot'));

        verify(() => cubit.needToggled(Need.noCar, marked: true)).called(1);
        verify(() => cubit.needToggled(Need.walkALot, marked: false)).called(1);
      });

      testWidgets('nothing for the needs with "Saltear"', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(step: OnboardingStep.needs),
        );

        await tester.tap(_byId(NeedsStep.skipIdentifier));

        verify(() => cubit.needsSkipped()).called(1);
      });

      testWidgets('the first name in a field', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(step: OnboardingStep.firstName),
        );

        await tester.enterText(find.byType(TextField), 'Marta');
        await tester.testTextInput.receiveAction(TextInputAction.done);

        verify(() => cubit.firstNameChanged('Marta')).called(1);
        verify(() => cubit.next()).called(1);
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.autofillHints, contains(AutofillHints.givenName));
      });
    });

    group('first name errors', () {
      for (final (value, message) in [
        ('', 'Escribí tu nombre de pila.'),
        ('a' * 31, 'Usá hasta 30 letras.'),
        ('Marta2', 'Usá solo letras.'),
      ]) {
        testWidgets('say "$message"', (tester) async {
          await pumpSubject(
            tester,
            OnboardingState(
              step: OnboardingStep.firstName,
              firstName: FirstName.dirty(value),
            ),
          );

          expect(find.text(message), findsOneWidget);
        });
      }

      testWidgets('stay hidden before typing', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(step: OnboardingStep.firstName),
        );

        expect(find.text('Escribí tu nombre de pila.'), findsNothing);
      });
    });

    group('read-back', () {
      testWidgets('shows every answer in order', (tester) async {
        await pumpSubject(tester, _answered);

        for (final text in [
          'Marta',
          'Sesenta y pico',
          'Solymar Norte',
          'Mate en la rambla, Truco',
          'Jueves a la tarde, Sábado a la mañana',
          'Termo',
          'Caminar mucho, No tengo auto',
        ]) {
          expect(find.text(text), findsOneWidget, reason: text);
        }
      });

      testWidgets('says "Nada" when no need is marked', (tester) async {
        await pumpSubject(tester, _answered.copyWith(needs: const {}));

        await tester.ensureVisible(find.text('Nada'));
        expect(find.text('Nada'), findsOneWidget);
      });

      testWidgets('shows empty values for unanswered single choices', (
        tester,
      ) async {
        await pumpSubject(
          tester,
          const OnboardingState(step: OnboardingStep.review),
        );

        expect(find.byType(ReadBackCard), findsOneWidget);
      });

      for (final step in OnboardingStep.questions) {
        testWidgets('opens ${step.name} with its "Cambiar"', (tester) async {
          await pumpSubject(tester, _answered);

          await tapVisible(
            tester,
            _byId('${ReviewStep.identifier}.${step.name}'),
          );

          verify(() => cubit.edit(step)).called(1);
        });
      }

      testWidgets('saves with "Está bien, guardalo"', (tester) async {
        await pumpSubject(tester, _answered);

        await tester.tap(_byId(ReviewStep.saveIdentifier));

        verify(() => cubit.save()).called(1);
      });

      for (final status in [OnboardingStatus.saving, OnboardingStatus.saved]) {
        testWidgets('disables saving while ${status.name}', (tester) async {
          await pumpSubject(tester, _answered.copyWith(status: status));

          await tester.tap(_byId(ReviewStep.saveIdentifier));

          verifyNever(() => cubit.save());
        });
      }

      testWidgets('says so when saving failed', (tester) async {
        await pumpSubject(
          tester,
          _answered.copyWith(status: OnboardingStatus.failure),
        );

        await tester.ensureVisible(
          find.text('No pudimos guardar. Probá de nuevo.'),
        );
        expect(
          find.text('No pudimos guardar. Probá de nuevo.'),
          findsOneWidget,
        );
      });
    });

    group('holds 200% text', () {
      for (final state in [
        const OnboardingState(step: OnboardingStep.slots),
        const OnboardingState(step: OnboardingStep.needs),
        _answered,
      ]) {
        testWidgets('on ${state.step.name}', (tester) async {
          tester.platformDispatcher.textScaleFactorTestValue = 2;
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

          await pumpSubject(tester, state);

          expect(tester.takeException(), isNull);
        });
      }
    });

    group('localizes', () {
      testWidgets('the questions in English', (tester) async {
        when(() => cubit.state).thenReturn(const OnboardingState());
        await tester.pumpApp(
          BlocProvider.value(value: cubit, child: const OnboardingView()),
          locale: const Locale('en'),
        );

        expect(find.text('What would you like to do?'), findsOneWidget);
        expect(find.text('1 of 7'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
      });
    });
  });
}
