import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/app/view/app_shell.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

void main() {
  group(AppShell, () {
    late GoRouter router;

    Widget page(String name) => Scaffold(
      body: Column(
        children: [
          Text(name),
          TextButton(onPressed: () {}, child: Text('$name botón')),
          TextButton(
            onPressed: () => router.go('/$name/mas'),
            child: Text('$name más'),
          ),
        ],
      ),
    );

    Future<void> pumpShell(
      WidgetTester tester, {
      Size size = phoneSize,
      double textScale = 1,
    }) {
      router = GoRouter(
        initialLocation: '/ronda',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => AppShell(navigationShell: shell),
            branches: [
              for (final name in ['ronda', 'cerca', 'ajustes'])
                StatefulShellBranch(
                  routes: [
                    GoRoute(
                      path: '/$name',
                      builder: (_, _) => page(name),
                      routes: [
                        GoRoute(
                          path: 'mas',
                          builder: (_, _) => Text('$name, más adentro'),
                        ),
                      ],
                    ),
                  ],
                ),
            ],
          ),
        ],
      );
      addTearDown(router.dispose);
      tester.view
        ..physicalSize = size
        ..devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp.router(
          theme: AppTheme.light,
          locale: rioplatense,
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      );
    }

    for (final size in [phoneSize, tabletSize]) {
      testWidgets('keeps the tabs in the bottom bar at ${size.width} px', (
        tester,
      ) async {
        await pumpShell(tester, size: size);
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationRail), findsNothing);
        expect(find.byType(PressScale), findsNWidgets(3));

        await tester.tap(find.text('Cerca'));
        await tester.pumpAndSettle();
        expect(find.text('cerca'), findsOneWidget);
      });
    }

    group('at ${desktopSize.width} px', () {
      testWidgets('stands the same three tabs in a rail', (tester) async {
        await pumpShell(tester, size: desktopSize);
        await tester.pumpAndSettle();

        expect(find.byType(NavigationBar), findsNothing);
        expect(find.byType(NavigationRail), findsOneWidget);
        for (final label in ['Mi ronda', 'Cerca', 'Ajustes']) {
          expect(
            find.descendant(
              of: find.byType(NavigationRail),
              matching: find.text(label),
            ),
            findsOneWidget,
          );
        }
        // The rail is at the start, the content beside it.
        expect(
          tester.getRect(find.byType(NavigationRail)).right,
          lessThanOrEqualTo(tester.getRect(find.text('ronda')).left),
        );
      });

      testWidgets('switches tabs from the rail', (tester) async {
        await pumpShell(tester, size: desktopSize);
        await tester.pumpAndSettle();

        await tester.tap(find.text('Ajustes'));
        await tester.pumpAndSettle();

        expect(find.text('ajustes'), findsOneWidget);
        expect(
          tester
              .widget<NavigationRail>(find.byType(NavigationRail))
              .selectedIndex,
          2,
        );
      });

      testWidgets('returns the open tab to its first screen', (tester) async {
        await pumpShell(tester, size: desktopSize);
        await tester.pumpAndSettle();
        await tester.tap(find.text('ronda más'));
        await tester.pumpAndSettle();
        expect(find.text('ronda, más adentro'), findsOneWidget);

        await tester.tap(find.text('Mi ronda'));
        await tester.pumpAndSettle();

        expect(find.text('ronda botón'), findsOneWidget);
      });

      testWidgets('presses a tab in from touch-down', (tester) async {
        await pumpShell(tester, size: desktopSize);
        await tester.pumpAndSettle();

        final gesture = await tester.startGesture(
          tester.getCenter(find.byIcon(Icons.near_me_outlined)),
        );
        await tester.pump(AppMotion.press);

        final scale = tester.widget<AnimatedScale>(
          find
              .ancestor(
                of: find.byIcon(Icons.near_me_outlined),
                matching: find.byType(AnimatedScale),
              )
              .first,
        );
        expect(scale.scale, AppMotion.pressedScale);
        await gesture.up();
        await tester.pumpAndSettle();
      });

      testWidgets('takes focus through the rail before the content', (
        tester,
      ) async {
        await pumpShell(tester, size: desktopSize);
        await tester.pumpAndSettle();

        final railBox = tester.getRect(find.byType(NavigationRail));
        // From the top of the page, as a browser starts.
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        final reached = <bool>[];
        for (var i = 0; i < 4; i++) {
          await tester.sendKeyEvent(LogicalKeyboardKey.tab);
          await tester.pump();
          final focused = FocusManager.instance.primaryFocus!.context!;
          final box = focused.findRenderObject()! as RenderBox;
          reached.add(
            railBox.contains(box.localToGlobal(box.size.center(Offset.zero))),
          );
        }
        expect(reached, [true, true, true, false]);
      });

      testWidgets('holds at 200% text', (tester) async {
        await pumpShell(tester, size: desktopSize, textScale: 2);
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
        expect(find.byType(NavigationRail), findsOneWidget);
      });
    });
  });
}
