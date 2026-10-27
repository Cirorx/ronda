import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/app/bloc/app_bloc.dart';
import 'package:ronda/app/view/app_shell.dart';
import 'package:ronda/cerca/cerca.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda/my_ronda/my_ronda.dart';
import 'package:ronda/settings/settings.dart';

/// Builds the app's router: the login screen, and one shell with a branch
/// per tab.
///
/// Signed-out people land on [LoginPage] wherever they were going; signed-in
/// people never see it. [refreshListenable] fires when [appBloc]'s state
/// changes, so the redirect runs again on sign-in and sign-out. `/` and any
/// unknown location land on Mi ronda.
GoRouter createAppRouter({
  required AppBloc appBloc,
  required Listenable refreshListenable,
}) {
  return GoRouter(
    initialLocation: MyRondaPage.path,
    refreshListenable: refreshListenable,
    redirect: (_, state) {
      final signedIn = appBloc.state.status == AppStatus.authenticated;
      final onLogin = state.matchedLocation == LoginPage.path;
      if (!signedIn) return onLogin ? null : LoginPage.path;
      return onLogin ? MyRondaPage.path : null;
    },
    onException: (_, _, router) => router.go(MyRondaPage.path),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => MyRondaPage.path),
      GoRoute(path: LoginPage.path, builder: (_, _) => const LoginPage()),
      StatefulShellRoute.indexedStack(
        builder: (_, _, navigationShell) =>
            AppShell(navigationShell: navigationShell),
        branches: [
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: MyRondaPage.path,
                builder: (_, _) => const MyRondaPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: CercaPage.path,
                builder: (_, _) => const CercaPage(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: SettingsPage.path,
                builder: (_, _) => const SettingsPage(),
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
