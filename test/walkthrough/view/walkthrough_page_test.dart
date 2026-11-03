import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/walkthrough/walkthrough.dart';
import 'package:ronda/welcome/welcome.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

class _MockLanguageCubit extends MockCubit<LanguageState>
    implements LanguageCubit;

class _MockGoRouter extends Mock implements GoRouter;

Finder _byId(String identifier) => find.bySemanticsIdentifier(identifier);

const _firstTitle = 'Los mismos 5 o 6, cada semana';
const _secondTitle = 'Un aviso por semana, nada más';
const _thirdTitle = 'Un programa se encarga del resto';

void main() {
  group(WalkthroughPage, () {
    late AppBloc appBloc;
    late GoRouter router;
    late LanguageCubit languageCubit;
    late StreamController<LanguageState> languages;

    setUpAll(() => registerFallbackValue(AppLanguage.spanish));

    setUp(() {
      languages = StreamController<LanguageState>();
      addTearDown(languages.close);
      languageCubit = _MockLanguageCubit();
      // A pick shows at once, as the real cubit's does.
      whenListen(
        languageCubit,
        languages.stream,
        initialState: const LanguageState(),
      );
      when(() => languageCubit.languagePicked(any())).thenAnswer(
        (invocation) async => languages.add(
          LanguageState(
            language: invocation.positionalArguments.first as AppLanguage?,
          ),
        ),
      );
      appBloc = _MockAppBloc();
      when(() => appBloc.state)
          .thenReturn(const AppState(status: AppStatus.unauthenticated));
      router = _MockGoRouter();
      when(() => router.canPop()).thenReturn(false);
    });

    Future<void> pumpSubject(
      WidgetTester tester, {
      Locale locale = rioplatense,
      Size size = phoneSize,
      double textScale = 1,
      bool reduced = false,
      TextDirection? direction,
    }) {
      Widget page = const WalkthroughPage();
      if (direction != null) {
        page = Directionality(textDirection: direction, child: page);
      }
      return tester.pumpApp(
        InheritedGoRouter(
          goRouter: router,
          child: MultiBlocProvider(
            providers: [
              BlocProvider.value(value: appBloc),
              BlocProvider.value(value: languageCubit),
            ],
            // The picked language, over the one pumped, as the app does:
            // the same tree either way, so only the locale changes.
            child: BlocBuilder<LanguageCubit, LanguageState>(
              builder: (context, state) => Localizations.override(
                context: context,
                locale: state.language.locale ?? locale,
                child: reducedMotion(reduced: reduced, child: page),
              ),
            ),
          ),
        ),
        locale: locale,
        size: size,
        textScale: textScale,
      );
    }

    Future<void> tapNext(WidgetTester tester) async {
      await tester.tap(_byId(WalkthroughPage.nextIdentifier));
      await tester.pumpAndSettle();
    }

    group('on open', () {
      testWidgets('does not mark it seen yet', (tester) async {
        await pumpSubject(tester);

        verifyNever(() => appBloc.add(const AppWalkthroughSeen()));
      });

      testWidgets('shows the first card, "Saltear" and "Seguir"', (
        tester,
      ) async {
        await pumpSubject(tester);

        expect(find.text(_firstTitle), findsOneWidget);
        expect(
          find.text(
            'A pocas cuadras, con una excusa: mate en la rambla, truco, '
            'fútbol 5.',
          ),
          findsOneWidget,
        );
        expect(find.byType(WalkthroughArt), findsOneWidget);
        expect(find.text('Saltear'), findsOneWidget);
        expect(find.text('Seguir'), findsOneWidget);
        expect(find.bySemanticsLabel('Tarjeta 1 de 3'), findsOneWidget);
      });

      testWidgets('in English', (tester) async {
        await pumpSubject(tester, locale: const Locale('en'));

        expect(find.text('The same 5 or 6, every week'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.text('Continue'), findsOneWidget);
      });
    });

    group('"Seguir"', () {
      testWidgets('moves through the cards, then reads "Empezar"', (
        tester,
      ) async {
        await pumpSubject(tester);

        await tapNext(tester);
        expect(find.text(_secondTitle), findsOneWidget);
        expect(find.bySemanticsLabel('Tarjeta 2 de 3'), findsOneWidget);

        await tapNext(tester);
        expect(find.text(_thirdTitle), findsOneWidget);
        expect(find.text('Empezar'), findsOneWidget);
        expect(find.text('Seguir'), findsNothing);
      });

      testWidgets('changes card at once with reduced motion', (tester) async {
        await pumpSubject(tester, reduced: true);

        await tester.tap(_byId(WalkthroughPage.nextIdentifier));
        await tester.pump();

        expect(find.text(_secondTitle), findsOneWidget);
        expect(find.text(_firstTitle), findsNothing);
      });
    });

    group('the language toggle', () {
      testWidgets('sits in the header on every card', (tester) async {
        await pumpSubject(tester);

        for (var card = 0; card < WalkthroughPage.cardCount; card++) {
          expect(_byId(LanguageToggle.identifier), findsOneWidget);
          expect(find.text('English'), findsOneWidget);
          final toggle = tester.getCenter(_byId(LanguageToggle.identifier));
          final skip = tester.getCenter(_byId(WalkthroughPage.skipIdentifier));
          expect(toggle.dx, lessThan(skip.dx));
          if (card < WalkthroughPage.cardCount - 1) await tapNext(tester);
        }
      });

      testWidgets('switches the cards in place, on the same card', (
        tester,
      ) async {
        await pumpSubject(tester);
        await tapNext(tester);

        await tester.tap(_byId(LanguageToggle.identifier));
        await tester.pumpAndSettle();

        verify(() => languageCubit.languagePicked(AppLanguage.english))
            .called(1);
        expect(find.text("One message a week, that's it"), findsOneWidget);
        expect(find.text(_secondTitle), findsNothing);
        expect(find.text('Español'), findsOneWidget);
        expect(find.text('Skip'), findsOneWidget);
        expect(find.bySemanticsLabel('Card 2 of 3'), findsOneWidget);

        await tapNext(tester);
        expect(find.text('A program takes care of the rest'), findsOneWidget);
      });

      testWidgets('back to Spanish, still on the same card', (tester) async {
        await pumpSubject(tester, locale: const Locale('en'));
        await tapNext(tester);
        await tapNext(tester);

        await tester.tap(find.text('Español'));
        await tester.pumpAndSettle();

        verify(() => languageCubit.languagePicked(AppLanguage.spanish))
            .called(1);
        expect(find.text(_thirdTitle), findsOneWidget);
        expect(find.text('Empezar'), findsOneWidget);
      });

      for (final (label, size, textScale) in [
        ('at 200% text', phoneSize, 2.0),
        ('on a 320 dp phone', const Size(320, 640), 1.0),
        ('on a 320 dp phone at 200% text', const Size(320, 640), 2.0),
      ]) {
        testWidgets('keeps both within reach $label', (tester) async {
          await pumpSubject(tester, size: size, textScale: textScale);

          expect(tester.takeException(), isNull);
          for (final id in [
            LanguageToggle.identifier,
            WalkthroughPage.skipIdentifier,
          ]) {
            final rect = tester.getRect(_byId(id));
            expect(rect.left, greaterThanOrEqualTo(0));
            expect(rect.right, lessThanOrEqualTo(size.width));
          }
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));

          await tester.tap(_byId(WalkthroughPage.skipIdentifier));
          verify(() => appBloc.add(const AppWalkthroughSeen())).called(1);
        });
      }
    });

    group('the sample weekly card', () {
      testWidgets('shows the real answers as a picture, read as one line', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        await pumpSubject(tester);
        await tapNext(tester);

        expect(find.text('Jueves 16:00 · Rambla y Gestido'), findsOneWidget);
        expect(find.byType(RsvpBar), findsOneWidget);
        expect(
          find.text(
            'No hay nada que revisar todos los días. Si no podés, tocás '
            '«Esta no» y nadie pregunta por qué.',
          ),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(
            'Así llega el aviso: jueves 16:00, Rambla y Gestido. ¿Venís? '
            'Voy o Esta no.',
          ),
          findsOneWidget,
        );
        expect(_byId('walkthrough.preview.yes'), findsNothing);
        expect(_byId('walkthrough.preview.no'), findsNothing);
        handle.dispose();
      });

      testWidgets('takes no taps', (tester) async {
        await pumpSubject(tester);
        await tapNext(tester);

        await tester.tap(find.text('Voy'), warnIfMissed: false);
        await tester.pumpAndSettle();

        expect(find.text(_secondTitle), findsOneWidget);
      });
    });

    group('leads to the welcome doors', () {
      testWidgets('with "Saltear"', (tester) async {
        await pumpSubject(tester);

        await tester.tap(_byId(WalkthroughPage.skipIdentifier));

        verify(() => appBloc.add(const AppWalkthroughSeen())).called(1);
        verify(() => router.go(WelcomePage.path)).called(1);
      });

      testWidgets('with "Empezar" on the last card', (tester) async {
        await pumpSubject(tester);
        await tapNext(tester);
        await tapNext(tester);

        await tapNext(tester);

        verify(() => appBloc.add(const AppWalkthroughSeen())).called(1);
        verify(() => router.go(WelcomePage.path)).called(1);
      });

      testWidgets('back under it, when opened from the welcome screen', (
        tester,
      ) async {
        when(() => router.canPop()).thenReturn(true);
        await pumpSubject(tester);

        await tester.tap(_byId(WalkthroughPage.skipIdentifier));

        verify(() => router.pop<Object?>()).called(1);
        verifyNever(() => router.go(any()));
      });
    });

    group('swipes', () {
      testWidgets('to the next card and back', (tester) async {
        await pumpSubject(tester);

        await tester.fling(find.byType(PageView), const Offset(-300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text(_secondTitle), findsOneWidget);
        expect(find.bySemanticsLabel('Tarjeta 2 de 3'), findsOneWidget);

        await tester.fling(find.byType(PageView), const Offset(300, 0), 1000);
        await tester.pumpAndSettle();
        expect(find.text(_firstTitle), findsOneWidget);
      });

      testWidgets('on the app spring, or a quicker one with reduced motion', (
        tester,
      ) async {
        await pumpSubject(tester);
        var physics =
            tester.widget<PageView>(find.byType(PageView)).physics!
                as WalkthroughPhysics;
        expect(physics.reduced, isFalse);

        await pumpSubject(tester, reduced: true);
        physics =
            tester.widget<PageView>(find.byType(PageView)).physics!
                as WalkthroughPhysics;
        expect(physics.reduced, isTrue);
      });
    });

    group('arrow keys', () {
      testWidgets('move forward and back, and stop at the ends', (
        tester,
      ) async {
        await pumpSubject(tester);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(find.text(_firstTitle), findsOneWidget);

        for (var i = 0; i < 3; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
          await tester.pump();
        }
        await tester.pumpAndSettle();
        expect(find.text(_thirdTitle), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(find.text(_secondTitle), findsOneWidget);
      });

      testWidgets('follow the reading direction', (tester) async {
        await pumpSubject(tester, direction: TextDirection.rtl);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowLeft);
        await tester.pumpAndSettle();
        expect(find.text(_secondTitle), findsOneWidget);

        await tester.sendKeyEvent(LogicalKeyboardKey.arrowRight);
        await tester.pumpAndSettle();
        expect(find.text(_firstTitle), findsOneWidget);
      });
    });

    group('lays out', () {
      for (final size in windowSizes) {
        testWidgets('every card at ${size.width.toInt()} wide', (tester) async {
          await pumpSubject(tester, size: size);
          await tapNext(tester);
          await tapNext(tester);

          expect(tester.takeException(), isNull);
          expect(find.text(_thirdTitle), findsOneWidget);
          final column = tester.getSize(find.byType(PageView));
          expect(column.width, lessThanOrEqualTo(WindowSize.readableWidth));
        });
      }

      testWidgets('at 200% text without the pictures, keeping the sample', (
        tester,
      ) async {
        await pumpSubject(tester, textScale: 2);

        expect(tester.takeException(), isNull);
        expect(find.byType(WalkthroughArt), findsNothing);

        await tapNext(tester);
        expect(tester.takeException(), isNull);
        expect(find.byType(WeekCardPreview), findsOneWidget);
      });
    });
  });
}
