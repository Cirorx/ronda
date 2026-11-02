import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:ronda/app/cubit/admin_access_cubit.dart';
import 'package:ronda/app/view/app_shell.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

import '../../helpers/helpers.dart';

class _MockAdminAccessCubit extends MockCubit<AdminAccess>
    implements AdminAccessCubit;

void main() {
  group(AppShell, () {
    late GoRouter router;
    late AdminAccessCubit adminAccess;

    setUp(() {
      adminAccess = _MockAdminAccessCubit();
      when(() => adminAccess.state).thenReturn(AdminAccess.member);
    });

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
      Locale locale = rioplatense,
      String initialLocation = '/ronda',
      int unread = 0,
    }) {
      router = GoRouter(
        initialLocation: initialLocation,
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => AppShell(navigationShell: shell),
            branches: [
              for (final name in ['ronda', 'cerca', 'ajustes', 'admin'])
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
        MultiBlocProvider(
          providers: [
            BlocProvider.value(value: adminAccess),
            BlocProvider.value(value: unreadReports(unread)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light,
            locale: locale,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            routerConfig: router,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context)
                  .copyWith(textScaler: TextScaler.linear(textScale)),
              child: child!,
            ),
          ),
        ),
      );
    }

    Finder barTab(String label) => find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(label),
    );

    group('the Admin tab', () {
      for (final (locale, labels) in [
        (rioplatense, ['Mi ronda', 'Cerca', 'Ajustes']),
        (const Locale('en'), ['My ronda', 'Nearby', 'Settings']),
      ]) {
        testWidgets('shows after the others for the admin in $locale', (
          tester,
        ) async {
          when(() => adminAccess.state).thenReturn(AdminAccess.admin);

          await pumpShell(tester, locale: locale);
          await tester.pumpAndSettle();

          final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
          expect(bar.destinations, hasLength(4));
          for (final label in [...labels, 'Admin']) {
            expect(barTab(label), findsOneWidget, reason: label);
          }

          await tester.tap(barTab('Admin'));
          await tester.pumpAndSettle();
          expect(find.text('admin'), findsOneWidget);
          expect(
            tester
                .widget<NavigationBar>(find.byType(NavigationBar))
                .selectedIndex,
            AppShell.adminBranch,
          );
        });

        for (final access in [
          AdminAccess.member,
          AdminAccess.checking,
          AdminAccess.signedOut,
        ]) {
          testWidgets('stays hidden while $access in $locale', (tester) async {
            when(() => adminAccess.state).thenReturn(access);

            await pumpShell(tester, locale: locale);
            await tester.pumpAndSettle();

            final bar = tester.widget<NavigationBar>(
              find.byType(NavigationBar),
            );
            expect(bar.destinations, hasLength(3));
            for (final label in labels) {
              expect(barTab(label), findsOneWidget, reason: label);
            }
            expect(barTab('Admin'), findsNothing);
          });
        }
      }

      testWidgets('goes when a renewed token loses the claim', (tester) async {
        whenListen(
          adminAccess,
          Stream.value(AdminAccess.member),
          initialState: AdminAccess.admin,
        );

        await pumpShell(tester);
        expect(barTab('Admin'), findsOneWidget);
        await tester.pumpAndSettle();

        expect(barTab('Admin'), findsNothing);
      });

      testWidgets('stays while it is the open tab, until the router moves '
          'away', (tester) async {
        await pumpShell(tester, initialLocation: '/admin');
        await tester.pumpAndSettle();

        expect(barTab('Admin'), findsOneWidget);
        expect(
          tester
              .widget<NavigationBar>(find.byType(NavigationBar))
              .selectedIndex,
          AppShell.adminBranch,
        );
      });

      testWidgets('carries the unread reports, said in words', (tester) async {
        when(() => adminAccess.state).thenReturn(AdminAccess.admin);

        await pumpShell(tester, unread: 2);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text('2'),
          ),
          findsOneWidget,
        );
        final admin = tester.widget<NavigationDestination>(
          find.widgetWithText(NavigationDestination, 'Admin'),
        );
        expect(admin.tooltip, equals('Admin, 2 reportes sin leer'));
      });

      testWidgets('says the unread reports in the rail too', (tester) async {
        final semantics = tester.ensureSemantics();
        when(() => adminAccess.state).thenReturn(AdminAccess.admin);

        await pumpShell(tester, size: desktopSize, unread: 1);
        await tester.pumpAndSettle();

        expect(
          find.bySemanticsLabel(RegExp('Admin, 1 reporte sin leer')),
          findsOneWidget,
        );
        semantics.dispose();
      });

      testWidgets('stands in the rail for the admin on a desktop', (
        tester,
      ) async {
        when(() => adminAccess.state).thenReturn(AdminAccess.admin);

        await pumpShell(tester, size: desktopSize);
        await tester.pumpAndSettle();

        expect(
          find.descendant(
            of: find.byType(NavigationRail),
            matching: find.text('Admin'),
          ),
          findsOneWidget,
        );
      });
    });

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
