import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/welcome/welcome.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAppBloc extends MockBloc<AppEvent, AppState> implements AppBloc;

Finder _byId(String identifier) => find.bySemanticsIdentifier(identifier);

void main() {
  group(WelcomePage, () {
    late AppBloc appBloc;

    setUp(() {
      appBloc = _MockAppBloc();
      when(() => appBloc.state)
          .thenReturn(const AppState(status: AppStatus.unauthenticated));
    });

    Future<void> pumpSubject(
      WidgetTester tester, {
      bool showVoiceDoor = voiceDoorEnabled,
      Locale locale = rioplatense,
      Size size = phoneSize,
    }) => tester.pumpApp(
      BlocProvider.value(
        value: appBloc,
        child: WelcomePage(showVoiceDoor: showVoiceDoor),
      ),
      locale: locale,
      size: size,
    );

    test('ships with the voice door on', () {
      expect(voiceDoorEnabled, isTrue);
    });

    group('renders', () {
      // On a phone they wrap under the name when the words don't fit (the
      // test font is far wider than the app's); a wide window fits them.
      testWidgets("the language and the link on the name's line", (
        tester,
      ) async {
        await pumpSubject(tester, size: desktopSize);

        final name = tester.getCenter(find.text('Ronda')).dy;
        for (final identifier in [
          LanguageToggle.identifier,
          WelcomePage.howItWorksIdentifier,
        ]) {
          expect(
            tester.getCenter(find.bySemanticsIdentifier(identifier)).dy,
            closeTo(name, 4),
            reason: identifier,
          );
        }
      });

      testWidgets('the welcome copy, the buttons door and the terms note', (
        tester,
      ) async {
        await pumpSubject(tester);

        expect(
          find.text(
            'Los mismos vecinos, a pocas cuadras, el mismo día todas las '
            'semanas.',
          ),
          findsOneWidget,
        );
        expect(find.text('¿Cómo nos querés contar?'), findsOneWidget);
        expect(find.text('Tocando botones'), findsOneWidget);
        expect(find.text('Siete preguntas cortas.'), findsOneWidget);
        expect(find.text('Al seguir, aceptás las'), findsOneWidget);
        expect(find.text('condiciones de Ronda'), findsOneWidget);
      });

      testWidgets('no voice door while it is off', (tester) async {
        await pumpSubject(tester, showVoiceDoor: false);

        expect(find.text('Con un audio'), findsNothing);
        expect(_byId(WelcomePage.voiceDoorIdentifier), findsNothing);
      });

      testWidgets('the voice door when it is on', (tester) async {
        await pumpSubject(tester);

        expect(find.text('Con un audio'), findsOneWidget);
        expect(
          find.text('Hablás un minuto, como en WhatsApp.'),
          findsOneWidget,
        );
      });

      testWidgets('"¿Cómo funciona?" beside the name', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSubject(tester);

        expect(find.text('¿Cómo funciona?'), findsOneWidget);
        expect(_byId(WelcomePage.howItWorksIdentifier), findsOneWidget);
        handle.dispose();
      });

      testWidgets('doors Maestro finds by their identifiers', (tester) async {
        final handle = tester.ensureSemantics();
        await pumpSubject(tester);

        expect(
          tester.getSemantics(_byId(WelcomePage.buttonsDoorIdentifier)),
          isSemantics(
            label: 'Tocando botones\nSiete preguntas cortas.',
            isButton: true,
            hasTapAction: true,
          ),
        );
        expect(
          tester.getSemantics(_byId(WelcomePage.voiceDoorIdentifier)),
          isSemantics(isButton: true, hasTapAction: true),
        );
        expect(_byId(WelcomePage.termsLinkIdentifier), findsOneWidget);
        handle.dispose();
      });

      testWidgets('at 200% text without overflowing, scrolling to the doors', (
        tester,
      ) async {
        tester.platformDispatcher.textScaleFactorTestValue = 2;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        await pumpSubject(tester);
        await tester.scrollUntilVisible(find.text('condiciones de Ronda'), 200);

        expect(tester.takeException(), isNull);
        expect(find.text('condiciones de Ronda'), findsOneWidget);
      });

      testWidgets("a slim strip of the ronda's things beside the doors' "
          'heading', (tester) async {
        await pumpSubject(tester);

        final strip = find.byType(RondaSketch);
        expect(
          tester.widget<RondaSketch>(strip).scene,
          RondaScene.objectsOnALine,
        );
        expect(tester.getSize(strip).height, WelcomePage.sketchHeight);
        final heading = find.text('¿Cómo nos querés contar?');
        expect(
          tester.getCenter(strip).dy,
          closeTo(tester.getCenter(heading).dy, 1),
        );
        expect(
          tester.getTopLeft(strip).dx,
          greaterThan(tester.getTopLeft(heading).dx),
        );
      });

      testWidgets('in English', (tester) async {
        await pumpSubject(tester, locale: const Locale('en'));

        expect(
          find.text(
            'The same few neighbours, a few blocks away, the same day every '
            'week.',
          ),
          findsOneWidget,
        );
        expect(find.text('By tapping buttons'), findsOneWidget);
        expect(find.text("Ronda's terms"), findsOneWidget);
      });
    });

    group('the doors', () {
      double scaleOf(WidgetTester tester) => tester
          .widget<AnimatedScale>(
            find
                .ancestor(
                  of: find.byType(Card).first,
                  matching: find.byType(AnimatedScale),
                )
                .first,
          )
          .scale;

      testWidgets('press in on touch-down, before the tap', (tester) async {
        await pumpSubject(tester);

        final gesture = await tester.startGesture(
          tester.getCenter(find.text('Con un audio')),
        );
        await tester.pump();

        expect(scaleOf(tester), AppMotion.pressedScale);
        verifyNever(
          () => appBloc.add(const AppTermsAccepted(door: OnboardingDoor.voice)),
        );

        await gesture.up();
        await tester.pump();
        expect(scaleOf(tester), 1);
      });
    });

    group('accepts the terms', () {
      testWidgets('when the buttons door is tapped', (tester) async {
        await pumpSubject(tester);

        await tester.ensureVisible(_byId(WelcomePage.buttonsDoorIdentifier));
        await tester.tap(_byId(WelcomePage.buttonsDoorIdentifier));

        verify(() => appBloc.add(const AppTermsAccepted())).called(1);
      });

      testWidgets('when the voice door is tapped', (tester) async {
        await pumpSubject(tester);

        await tester.tap(_byId(WelcomePage.voiceDoorIdentifier));

        verify(
          () => appBloc.add(const AppTermsAccepted(door: OnboardingDoor.voice)),
        ).called(1);
      });

      testWidgets('when "Ya tengo cuenta" is tapped', (tester) async {
        await pumpSubject(tester);

        expect(find.text('Ya tengo cuenta'), findsOneWidget);
        await tester.ensureVisible(_byId(WelcomePage.accountIdentifier));
        await tester.tap(_byId(WelcomePage.accountIdentifier));

        verify(
          () =>
              appBloc.add(const AppTermsAccepted(door: OnboardingDoor.account)),
        ).called(1);
      });
    });

    group('lays out', () {
      Finder title() => find.text(
        'Los mismos vecinos, a pocas cuadras, el mismo día todas las semanas.',
      );
      Finder termsNote() => find.byType(TermsNote);

      testWidgets('the doors at the bottom of a phone', (tester) async {
        await pumpSubject(tester);

        expect(find.byType(RuledMargin), findsNothing);
        final safeBottom = tester
            .getBottomLeft(find.byType(SingleChildScrollView))
            .dy;
        // Only the scroll view's bottom padding under the terms note.
        expect(
          safeBottom - tester.getBottomLeft(termsNote()).dy,
          lessThanOrEqualTo(2 * AppSpacing.unit + 1),
        );
      });

      for (final size in [tabletSize, desktopSize]) {
        group('at ${size.width} px', () {
          testWidgets('in the readable column, centred on the paper', (
            tester,
          ) async {
            await pumpSubject(tester, size: size);

            final column = tester.getRect(find.byType(RuledMargin));
            expect(column.width, WindowSize.readableWidth);
            expect(column.center.dx, size.width / 2);
            expect(
              tester.getSize(title()).width,
              lessThanOrEqualTo(WindowSize.readableWidth),
            );
          });

          testWidgets('with the doors right under the copy, the two centred '
              'together', (tester) async {
            await pumpSubject(tester, size: size);

            final copyBottom = tester
                .getBottomLeft(find.textContaining('Contanos un poco de vos'))
                .dy;
            // The doors' heading shares its line with the strip of the
            // ronda's things, the taller of the two.
            expect(
              tester.getTopLeft(find.byType(RondaSketch)).dy - copyBottom,
              closeTo(2 * AppSpacing.unit, 1),
            );
            // The name's line, which the language and "¿Cómo funciona?"
            // share.
            final top = tester
                .getTopLeft(
                  find
                      .ancestor(
                        of: find.text('Ronda'),
                        matching: find.byType(Wrap),
                      )
                      .first,
                )
                .dy;
            final bottom = tester.getBottomLeft(termsNote()).dy;
            expect((top + bottom) / 2, closeTo(size.height / 2, 2));
          });
        });
      }
    });

    testWidgets(
      'tints a door under a mouse over ${AppMotion.hover.inMilliseconds} ms',
      (tester) async {
        await pumpSubject(tester);

        final ink = find.descendant(
          of: find.byType(WelcomeDoor).first,
          matching: find.byType(InkWell),
        );
        expect(
          tester.widget<InkWell>(ink.first).hoverDuration,
          AppMotion.hover,
        );
        expect(
          tester.getSemantics(_byId(WelcomePage.buttonsDoorIdentifier)),
          isSemantics(isButton: true, hasTapAction: true),
        );
      },
    );
  });
}
