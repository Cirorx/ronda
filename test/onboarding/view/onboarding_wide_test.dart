import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/onboarding/view/steps/steps.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockOnboardingCubit extends MockCubit<OnboardingState>
    implements OnboardingCubit;

Finder _byId(String identifier) => find.bySemanticsIdentifier(identifier);

final _answered = OnboardingState(
  step: OnboardingStep.review,
  pretexts: const {Pretext.mate, Pretext.caminata},
  brings: const {Bring.termo, Bring.tengoGanas},
  slots: {const Slot(SlotDay.thursday, SlotBand.afternoon)},
  barrio: Barrio.solymarNorte,
  ageBand: AgeBand.sixties,
  firstName: const FirstName.dirty('Marta'),
);

void main() {
  group('$OnboardingView on wide windows', () {
    late OnboardingCubit cubit;

    setUpAll(() => registerFallbackValue(OnboardingStep.pretexts));

    setUp(() => cubit = _MockOnboardingCubit());

    Future<void> pumpSubject(
      WidgetTester tester,
      OnboardingState state, {
      Size size = desktopSize,
      double textScale = 1,
    }) async {
      when(() => cubit.state).thenReturn(state);
      await tester.pumpApp(
        BlocProvider.value(value: cubit, child: const OnboardingView()),
        size: size,
        textScale: textScale,
      );
      await tester.pumpAndSettle();
    }

    group('at ${phoneSize.width} px', () {
      testWidgets('keeps one question a page, edge to edge', (tester) async {
        await pumpSubject(tester, const OnboardingState(), size: phoneSize);

        expect(find.byType(PretextsStep), findsOneWidget);
        expect(find.byType(BringsStep), findsNothing);
        expect(find.text('1 de 7'), findsOneWidget);
        expect(find.byType(ReadableColumn), findsNothing);
        expect(find.byType(OnboardingObjects), findsNothing);
      });
    });

    group('at ${tabletSize.width} px', () {
      testWidgets('keeps one question a page in a readable column', (
        tester,
      ) async {
        await pumpSubject(tester, const OnboardingState(), size: tabletSize);

        expect(find.byType(BringsStep), findsNothing);
        expect(find.text('1 de 7'), findsOneWidget);
        expect(
          tester.getSize(find.byType(RuledMargin)).width,
          WindowSize.readableWidth,
        );
        expect(
          tester.getCenter(find.byType(RuledMargin)).dx,
          tabletSize.width / 2,
        );
        expect(find.byType(OnboardingObjects), findsNothing);
        expect(
          tester.getSize(find.byType(LinearProgressIndicator)).width,
          lessThan(WindowSize.readableWidth),
        );
      });
    });

    group('at ${desktopSize.width} px', () {
      testWidgets('puts what you would do and what you bring on one page', (
        tester,
      ) async {
        await pumpSubject(tester, const OnboardingState());

        expect(find.byType(PretextsStep), findsOneWidget);
        expect(find.byType(BringsStep), findsOneWidget);
        expect(find.text('¿Qué te gustaría hacer?'), findsOneWidget);
        expect(find.text('¿Qué podés llevar o enseñar?'), findsOneWidget);
        expect(find.text('1 de 4'), findsOneWidget);
        expect(find.bySemanticsLabel('Paso 1 de 4'), findsOneWidget);
        // Each question is still a heading of its own.
        expect(
          tester.getSemantics(find.text('¿Qué podés llevar o enseñar?')),
          isSemantics(label: '¿Qué podés llevar o enseñar?', isHeader: true),
        );
      });

      for (final (step, other, number) in [
        (OnboardingStep.brings, PretextsStep, 1),
        (OnboardingStep.slots, BarrioStep, 2),
        (OnboardingStep.barrio, SlotsStep, 2),
        (OnboardingStep.needs, AgeBandStep, 3),
      ]) {
        testWidgets('shows ${step.name} with the rest of page $number', (
          tester,
        ) async {
          await pumpSubject(tester, OnboardingState(step: step));

          expect(find.byType(other), findsOneWidget);
          expect(find.text('$number de 4'), findsOneWidget);
        });
      }

      testWidgets('leaves the name on a page of its own', (tester) async {
        await pumpSubject(
          tester,
          const OnboardingState(step: OnboardingStep.firstName),
        );

        expect(find.byType(FirstNameStep), findsOneWidget);
        expect(find.byType(NeedsStep), findsNothing);
        expect(find.text('4 de 4'), findsOneWidget);
      });

      testWidgets('drops "Saltear" where the needs share a page', (
        tester,
      ) async {
        await pumpSubject(
          tester,
          const OnboardingState(step: OnboardingStep.ageBand),
        );

        expect(find.byType(NeedsStep), findsOneWidget);
        expect(_byId(NeedsStep.skipIdentifier), findsNothing);
      });

      group('"Seguir"', () {
        testWidgets('waits until every question on the page is answered', (
          tester,
        ) async {
          await pumpSubject(
            tester,
            const OnboardingState(pretexts: {Pretext.mate}),
          );

          expect(
            tester
                .widget<FilledButton>(
                  find.descendant(
                    of: _byId(OnboardingNextButton.identifier),
                    matching: find.byType(FilledButton),
                  ),
                )
                .onPressed,
            isNull,
          );
        });

        testWidgets('moves past the whole page', (tester) async {
          await pumpSubject(
            tester,
            const OnboardingState(
              pretexts: {Pretext.mate},
              brings: {Bring.termo},
            ),
          );

          await tester.tap(_byId(OnboardingNextButton.identifier));

          verify(
            () => cubit.nextAfter(const [
              OnboardingStep.pretexts,
              OnboardingStep.brings,
            ]),
          ).called(1);
        });
      });

      group('back', () {
        testWidgets('goes to the first question of the page before', (
          tester,
        ) async {
          await pumpSubject(
            tester,
            const OnboardingState(step: OnboardingStep.barrio),
          );

          await tester.tap(_byId(OnboardingStepLayout.backIdentifier));

          verify(() => cubit.backTo(OnboardingStep.pretexts)).called(1);
        });

        testWidgets('from the system goes to the page before', (tester) async {
          await pumpSubject(
            tester,
            const OnboardingState(step: OnboardingStep.ageBand),
          );

          await tester.binding.handlePopRoute();
          await tester.pump();

          verify(() => cubit.backTo(OnboardingStep.slots)).called(1);
        });

        testWidgets('from the name steps back one question', (tester) async {
          await pumpSubject(
            tester,
            const OnboardingState(step: OnboardingStep.firstName),
          );

          await tester.tap(_byId(OnboardingStepLayout.backIdentifier));

          verify(() => cubit.back()).called(1);
        });
      });

      group('side panel', () {
        testWidgets('says what will show up before anything is chosen', (
          tester,
        ) async {
          await pumpSubject(tester, const OnboardingState());

          expect(find.byType(OnboardingObjects), findsOneWidget);
          expect(find.text('Tu ronda'), findsOneWidget);
          expect(
            find.text('Lo que elijas para hacer y para llevar aparece acá.'),
            findsOneWidget,
          );
          expect(
            find.byType(RondaObjectIcon),
            findsNWidgets(RondaObject.values.length),
          );
        });

        testWidgets('draws what was chosen, beside the questions', (
          tester,
        ) async {
          await pumpSubject(tester, _answered);

          final panel = find.byType(OnboardingObjects);
          Finder inPanel(Finder finder) =>
              find.descendant(of: panel, matching: finder);
          expect(inPanel(find.text('Para hacer')), findsOneWidget);
          expect(inPanel(find.text('Para llevar')), findsOneWidget);
          expect(inPanel(find.text('Mate en la rambla')), findsOneWidget);
          expect(inPanel(find.text('Caminata')), findsOneWidget);
          expect(inPanel(find.text('Termo')), findsOneWidget);
          expect(inPanel(find.text('Tengo ganas')), findsOneWidget);
          // A walk and "Tengo ganas" are not things to draw.
          expect(inPanel(find.byType(RondaObjectIcon)), findsNWidgets(2));
          expect(
            tester.getRect(panel).left,
            greaterThan(tester.getRect(find.byType(ReviewStep)).left),
          );
        });

        testWidgets('only draws what the brings say', (tester) async {
          await pumpSubject(
            tester,
            const OnboardingState(
              step: OnboardingStep.brings,
              brings: {Bring.pan},
            ),
          );

          final panel = find.byType(OnboardingObjects);
          expect(
            find.descendant(of: panel, matching: find.text('Para hacer')),
            findsNothing,
          );
          expect(
            find.descendant(of: panel, matching: find.text('Para llevar')),
            findsOneWidget,
          );
        });

        testWidgets('is not read twice by screen readers', (tester) async {
          await pumpSubject(tester, _answered);

          expect(find.bySemanticsLabel('Tu ronda'), findsNothing);
        });
      });

      testWidgets('takes focus through the questions before "Seguir"', (
        tester,
      ) async {
        await pumpSubject(
          tester,
          const OnboardingState(
            pretexts: {Pretext.mate},
            brings: {Bring.termo},
          ),
        );
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();

        final next = tester.getRect(_byId(OnboardingNextButton.identifier));
        final brings = tester.getRect(find.byType(BringsStep));
        final ys = <double>[];
        for (var i = 0; i < 30; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final box =
              FocusManager.instance.primaryFocus!.context!.findRenderObject()!
                  as RenderBox;
          final center = box.localToGlobal(box.size.center(Offset.zero));
          if (next.contains(center)) break;
          ys.add(center.dy);
        }
        // The pretexts' chips, then the brings', then "Seguir".
        expect(ys, isNotEmpty);
        expect(ys.first, lessThan(brings.top));
        expect(ys.last, greaterThan(brings.top));
      });

      testWidgets('goes back to one question a page at 200% text', (
        tester,
      ) async {
        await pumpSubject(tester, const OnboardingState(), textScale: 2);

        expect(tester.takeException(), isNull);
        expect(find.byType(BringsStep), findsNothing);
        expect(find.text('1 de 7'), findsOneWidget);
        expect(find.byType(OnboardingObjects), findsOneWidget);
      });
    });
  });
}
