import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(RondaSheetRoute, () {
    const contentKey = Key('content');
    const contentHeight = 300.0;
    const handleHeight = AppTheme.minTarget;
    const sheetHeight = contentHeight + handleHeight;

    late NavigatorState navigator;
    late Future<String?> result;

    Widget content() => Container(
      key: contentKey,
      height: contentHeight,
      color: Colors.transparent,
      child: Builder(
        builder: (context) => Center(
          child: TextButton(
            onPressed: () => Navigator.of(context).pop('listo'),
            child: const Text('Listo'),
          ),
        ),
      ),
    );

    Future<void> open(
      WidgetTester tester, {
      WidgetBuilder? builder,
      bool reduced = false,
      bool isDismissible = true,
      bool enableDrag = true,
      bool settle = true,
    }) async {
      await tester.pumpApp(
        MediaQuery(
          data: MediaQueryData(size: phoneSize, disableAnimations: reduced),
          child: Builder(
            builder: (context) {
              navigator = Navigator.of(context);
              return Center(
                child: TextButton(
                  onPressed: () => result = showRondaSheet<String>(
                    context: context,
                    builder: builder ?? (_) => content(),
                    isDismissible: isDismissible,
                    enableDrag: enableDrag,
                  ),
                  child: const Text('Abrir'),
                ),
              );
            },
          ),
        ),
      );
      await tester.tap(find.text('Abrir'));
      await tester.pump();
      if (settle) await tester.pumpAndSettle();
    }

    double top(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(contentKey)).dy;

    /// Where the content's top rests once the sheet is open.
    double restTop(WidgetTester tester) =>
        tester.view.physicalSize.height / tester.view.devicePixelRatio -
        contentHeight;

    Color scrim(WidgetTester tester) =>
        tester.widget<ModalBarrier>(find.byType(ModalBarrier).last).color!;

    Offset grabPoint(WidgetTester tester) =>
        tester.getTopLeft(find.byKey(contentKey)) + const Offset(20, 20);

    /// Drags by [dy] in [steps] moves [stepTime] apart, then lets go.
    Future<void> drag(
      WidgetTester tester,
      double dy, {
      int steps = 10,
      Duration stepTime = const Duration(milliseconds: 100),
      Offset? from,
    }) async {
      final gesture = await tester.startGesture(from ?? grabPoint(tester));
      var time = Duration.zero;
      for (var step = 0; step < steps; step++) {
        time += stepTime;
        await gesture.moveBy(Offset(0, dy / steps), timeStamp: time);
      }
      await gesture.up(timeStamp: time + stepTime);
    }

    group('opens', () {
      testWidgets('over a scrim, resting on the bottom edge', (tester) async {
        await open(tester);

        expect(top(tester), closeTo(restTop(tester), 0.5));
        expect(
          scrim(tester),
          AppTheme.light.bottomSheetTheme.modalBarrierColor,
        );
        expect(
          ModalRoute.of(tester.element(find.byKey(contentKey))),
          isA<RondaSheetRoute<String>>(),
        );
      });

      testWidgets('rising from below on a spring', (tester) async {
        await open(tester, settle: false);
        await tester.pump(const Duration(milliseconds: 60));
        final early = top(tester);
        await tester.pump(const Duration(milliseconds: 60));

        expect(early, greaterThan(top(tester)));
        expect(top(tester), greaterThan(restTop(tester)));
        await tester.pumpAndSettle();
        expect(top(tester), closeTo(restTop(tester), 0.5));
      });

      testWidgets('as a named route with a close button read out once', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        await open(tester);
        final localizations = MaterialLocalizations.of(
          tester.element(find.byKey(contentKey)),
        );

        expect(
          find.bySemanticsLabel(localizations.bottomSheetLabel),
          findsOneWidget,
        );
        final close = find.semantics.byPredicate(
          (node) => node.tooltip == localizations.closeButtonTooltip,
        );
        expect(close, findsOne);
        expect(
          find.semantics.byPredicate(
            (node) =>
                node.label == localizations.modalBarrierDismissLabel ||
                node.label == localizations.closeButtonTooltip,
          ),
          findsNothing,
        );
        tester.semantics.tap(close);
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
        expect(await result, isNull);
        semantics.dispose();
      });
    });

    group('drags', () {
      testWidgets('1:1 from where it was grabbed', (tester) async {
        await open(tester);
        final rest = top(tester);

        final gesture = await tester.startGesture(grabPoint(tester));
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();
        expect(top(tester), closeTo(rest + 40, 0.5));
        await gesture.moveBy(const Offset(0, 60));
        await tester.pump();
        expect(top(tester), closeTo(rest + 100, 0.5));
        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('lightening the scrim as it goes down', (tester) async {
        await open(tester);
        final full = scrim(tester).a;

        final gesture = await tester.startGesture(grabPoint(tester));
        await gesture.moveBy(const Offset(0, sheetHeight / 2));
        await tester.pump();

        expect(scrim(tester).a, closeTo(full / 2, 0.02));
        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('rubber-banding past the top, then back', (tester) async {
        await open(tester);
        final rest = top(tester);

        final gesture = await tester.startGesture(grabPoint(tester));
        await gesture.moveBy(const Offset(0, -200));
        await tester.pump();

        final lifted = rest - top(tester);
        expect(lifted, greaterThan(0));
        expect(lifted, lessThan(200));
        expect(lifted, closeTo(-AppMotion.rubberBand(-200, sheetHeight), 0.5));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(top(tester), closeTo(rest, 0.5));
      });
    });

    group('on release', () {
      testWidgets('closes when thrown down', (tester) async {
        await open(tester);

        await tester.fling(find.byKey(contentKey), const Offset(0, 60), 1500);
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
        expect(await result, isNull);
      });

      testWidgets('closes when let go slowly past half its height', (
        tester,
      ) async {
        await open(tester);

        await drag(tester, sheetHeight * 0.7);
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
      });

      testWidgets('springs back when let go slowly near the top', (
        tester,
      ) async {
        await open(tester);
        final rest = top(tester);

        await drag(tester, 80);
        await tester.pumpAndSettle();

        expect(top(tester), closeTo(rest, 0.5));
      });

      testWidgets('springs back when pushed up, however far down', (
        tester,
      ) async {
        await open(tester);
        final rest = top(tester);

        final gesture = await tester.startGesture(grabPoint(tester));
        await gesture.moveBy(
          const Offset(0, sheetHeight * 0.8),
          timeStamp: const Duration(milliseconds: 500),
        );
        for (var step = 1; step <= 4; step++) {
          await gesture.moveBy(
            const Offset(0, -10),
            timeStamp: Duration(milliseconds: 500 + step * 10),
          );
        }
        await gesture.up(timeStamp: const Duration(milliseconds: 550));
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsOneWidget);
        expect(top(tester), closeTo(rest, 0.5));
      });

      testWidgets('bounces a little after a flick back up', (tester) async {
        await open(tester);
        final rest = top(tester);

        final gesture = await tester.startGesture(grabPoint(tester));
        await gesture.moveBy(
          const Offset(0, 100),
          timeStamp: const Duration(milliseconds: 500),
        );
        for (var step = 1; step <= 4; step++) {
          await gesture.moveBy(
            const Offset(0, -20),
            timeStamp: Duration(milliseconds: 500 + step * 10),
          );
        }
        await gesture.up(timeStamp: const Duration(milliseconds: 550));

        var highest = top(tester);
        for (var frame = 0; frame < 30; frame++) {
          await tester.pump(const Duration(milliseconds: 16));
          if (top(tester) < highest) highest = top(tester);
        }
        expect(highest, lessThan(rest));
        await tester.pumpAndSettle();
        expect(top(tester), closeTo(rest, 0.5));
      });
    });

    group('can be grabbed mid-flight', () {
      testWidgets('while rising, with no jump', (tester) async {
        await open(tester, settle: false);
        await tester.pump(const Duration(milliseconds: 150));
        final before = top(tester);
        expect(before, greaterThan(restTop(tester)));

        final gesture = await tester.startGesture(
          tester.getTopLeft(find.byKey(contentKey)) + const Offset(20, 5),
        );
        await gesture.moveBy(const Offset(0, 30));
        await tester.pump();

        expect(top(tester), closeTo(before + 30, 0.5));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(top(tester), closeTo(restTop(tester), 0.5));
      });

      testWidgets('while springing back, with no jump', (tester) async {
        await open(tester);
        await drag(tester, 120);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));
        final before = top(tester);
        expect(before, greaterThan(restTop(tester)));

        final gesture = await tester.startGesture(grabPoint(tester));
        await gesture.moveBy(const Offset(0, 20));
        await tester.pump();

        expect(top(tester), closeTo(before + 20, 0.5));
        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('while rubber-banding back, with no jump', (tester) async {
        await open(tester);
        final gesture = await tester.startGesture(grabPoint(tester));
        await gesture.moveBy(const Offset(0, -200));
        await gesture.up();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 30));
        final before = top(tester);
        expect(before, lessThan(restTop(tester)));

        final again = await tester.startGesture(grabPoint(tester));
        await again.moveBy(const Offset(0, -20));
        await tester.pump();

        expect(top(tester), lessThan(before));
        await again.up();
        await tester.pumpAndSettle();
        expect(top(tester), closeTo(restTop(tester), 0.5));
      });

      testWidgets('while closing after a scrim tap', (tester) async {
        await open(tester);

        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        final before = top(tester);
        expect(before, greaterThan(restTop(tester)));

        final gesture = await tester.startGesture(grabPoint(tester));
        await gesture.moveBy(const Offset(0, -20));
        await tester.pump();
        expect(top(tester), closeTo(before - 20, 0.5));
        await gesture.up();
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsOneWidget);
      });
    });

    group('closes', () {
      /// The middle of the handle's row, above the content.
      Offset handle(WidgetTester tester) => Offset(
        tester.getCenter(find.byKey(contentKey)).dx,
        top(tester) - handleHeight / 2,
      );

      testWidgets('on a tap on its handle, as a mouse would', (tester) async {
        await open(tester);

        final mouse = await tester.createGesture(kind: PointerDeviceKind.mouse);
        addTearDown(mouse.removePointer);
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is MouseRegion &&
                widget.cursor == SystemMouseCursors.click,
          ),
          findsOneWidget,
        );
        await mouse.down(handle(tester));
        await mouse.up();
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
        expect(await result, isNull);
      });

      testWidgets('on a tap anywhere across the handle row', (tester) async {
        await open(tester);

        await tester.tapAt(Offset(24, top(tester) - handleHeight / 2));
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
      });

      testWidgets('with the close button at the end of the handle row', (
        tester,
      ) async {
        await open(tester);
        final button = find.byType(IconButton);

        expect(tester.getCenter(button).dy, closeTo(handle(tester).dy, 0.5));
        expect(tester.getCenter(button).dx, greaterThan(handle(tester).dx));
        await tester.tap(button);
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
      });

      testWidgets('on a scrim tap, down the way it came', (tester) async {
        await open(tester);

        await tester.tapAt(const Offset(10, 10));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(top(tester), greaterThan(restTop(tester)));
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
        expect(await result, isNull);
      });

      testWidgets('with a result when its content pops', (tester) async {
        await open(tester);

        await tester.tap(find.text('Listo'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 60));
        expect(top(tester), greaterThan(restTop(tester)));
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
        expect(await result, 'listo');
      });

      testWidgets('even when a screen was pushed over it meanwhile', (
        tester,
      ) async {
        await open(tester);

        await tester.tapAt(const Offset(10, 10));
        await tester.pump(const Duration(milliseconds: 16));
        navigator.push(
          PageRouteBuilder<void>(
            opaque: false,
            pageBuilder: (_, _, _) => const SizedBox.shrink(),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
        expect(await result, isNull);
      });
    });

    group('holds', () {
      testWidgets('on a scrim tap when not dismissible', (tester) async {
        await open(tester, isDismissible: false);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsOneWidget);
      });

      testWidgets('on a handle tap, with no close button, when not '
          'dismissible', (tester) async {
        await open(tester, isDismissible: false);

        expect(find.byType(IconButton), findsNothing);
        await tester.tapAt(
          Offset(
            tester.getCenter(find.byKey(contentKey)).dx,
            top(tester) - handleHeight / 2,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsOneWidget);
      });

      testWidgets('on its close button when its content may not pop', (
        tester,
      ) async {
        var refused = 0;
        await open(
          tester,
          builder: (_) => PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) => refused += didPop ? 0 : 1,
            child: content(),
          ),
        );

        await tester.tap(find.byType(IconButton));
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsOneWidget);
        expect(refused, 1);
      });

      testWidgets('still when dragging is off', (tester) async {
        await open(tester, enableDrag: false);
        final rest = top(tester);

        await tester.fling(find.byKey(contentKey), const Offset(0, 60), 1500);
        await tester.pumpAndSettle();

        expect(top(tester), closeTo(rest, 0.5));
      });

      testWidgets('on a scrim tap when its content may not pop', (
        tester,
      ) async {
        var refused = 0;
        await open(
          tester,
          builder: (_) => PopScope(
            canPop: false,
            onPopInvokedWithResult: (didPop, _) => refused += didPop ? 0 : 1,
            child: content(),
          ),
        );

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsOneWidget);
        expect(refused, 1);
      });

      testWidgets('when its content may not pop', (tester) async {
        await open(
          tester,
          builder: (_) => PopScope(canPop: false, child: content()),
        );

        await tester.fling(find.byKey(contentKey), const Offset(0, 60), 1500);
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsOneWidget);
      });
    });

    group('with scrolling content', () {
      Widget scrolling(BuildContext context) => SingleChildScrollView(
        child: Column(
          children: [
            SingleChildScrollView(
              key: const Key('sideways'),
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (var i = 0; i < 20; i++)
                    SizedBox(width: 80, height: 40, child: Text('$i')),
                ],
              ),
            ),
            Container(key: contentKey, height: 2000),
          ],
        ),
      );

      testWidgets('is pulled down from the top of its content', (tester) async {
        await open(tester, builder: scrolling);
        final rest = top(tester);

        final gesture = await tester.startGesture(grabPoint(tester));
        await gesture.moveBy(const Offset(0, 40));
        await gesture.moveBy(const Offset(0, 40));
        await tester.pump();

        expect(top(tester), greaterThan(rest));
        await gesture.up();
        await tester.pumpAndSettle();
        expect(top(tester), closeTo(rest, 0.5));
      });

      testWidgets('is thrown down from the top of its content', (tester) async {
        await open(tester, builder: scrolling);

        await tester.flingFrom(grabPoint(tester), const Offset(0, 200), 2000);
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
      });

      testWidgets('stays put while its content scrolls', (tester) async {
        await open(tester, builder: scrolling);
        final rest = top(tester);

        await tester.drag(
          find.byKey(const Key('sideways')),
          const Offset(-200, 0),
        );
        await tester.dragFrom(grabPoint(tester), const Offset(0, -300));
        await tester.pumpAndSettle();

        expect(top(tester), lessThan(rest));
        expect(find.byKey(contentKey), findsOneWidget);
      });
    });

    group('with reduced motion', () {
      testWidgets('cross-fades in, without rising', (tester) async {
        await open(tester, reduced: true, settle: false);
        await tester.pump(const Duration(milliseconds: 50));

        expect(top(tester), closeTo(restTop(tester), 0.5));
        final fade = tester.widget<FadeTransition>(
          find
              .ancestor(
                of: find.byKey(contentKey),
                matching: find.byType(FadeTransition),
              )
              .first,
        );
        expect(fade.opacity.value, inExclusiveRange(0, 1));
        await tester.pumpAndSettle();
      });

      testWidgets(
        'cross-fades in over the full ${AppMotion.crossFade} when the phone '
        'removes animations',
        (tester) async {
          removeAnimations(tester);
          await open(tester, reduced: true, settle: false);
          await tester.pump(AppMotion.crossFade ~/ 2);

          final fade = tester.widget<FadeTransition>(
            find
                .ancestor(
                  of: find.byKey(contentKey),
                  matching: find.byType(FadeTransition),
                )
                .first,
          );
          expect(fade.opacity.value, inExclusiveRange(0, 1));
          await tester.pump(AppMotion.crossFade ~/ 2);
          expect(fade.opacity.value, 1);
        },
      );

      testWidgets('closes at once on a tap on its handle', (tester) async {
        await open(tester, reduced: true);

        await tester.tapAt(
          Offset(
            tester.getCenter(find.byKey(contentKey)).dx,
            top(tester) - handleHeight / 2,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
      });

      testWidgets('jumps back when let go near the top', (tester) async {
        await open(tester, reduced: true);
        final rest = top(tester);

        await drag(tester, 80);
        await tester.pump();

        expect(top(tester), closeTo(rest, 0.5));
      });

      testWidgets('fades out when let go past half its height', (tester) async {
        await open(tester, reduced: true);

        await drag(tester, sheetHeight * 0.7);
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
      });

      testWidgets('fades out on a scrim tap', (tester) async {
        await open(tester, reduced: true);

        await tester.tapAt(const Offset(10, 10));
        await tester.pumpAndSettle();

        expect(find.byKey(contentKey), findsNothing);
      });
    });
  });
}
