import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda/app/bloc/app_bloc.dart';
import 'package:ronda/app/view/app_shell.dart';
import 'package:ronda/cerca/cerca.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda/mate_flyer/mate_flyer.dart';
import 'package:ronda/my_ronda/my_ronda.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda/welcome/welcome.dart';

/// The welcome screen's query parameter that says where sign-in started,
/// so the router returns there once it is done. Only [AdminPage.path] is
/// honoured.
const returnToParameter = 'from';

/// Builds the app's router: the welcome screen with sign-in and the terms
/// under it, onboarding, and one shell with a branch per tab.
///
/// Where people may be follows [appBloc]'s state, and [refreshListenable]
/// fires when it changes, so the redirect runs again on every change:
/// - signed out: the welcome screen and the terms; sign-in only after a
///   welcome door accepted the terms;
/// - signed in, profile not read yet: wherever they are;
/// - signed in without a profile: onboarding;
/// - signed in with a profile: the tabs, never welcome or onboarding;
/// - the admin screen: anyone signed in, with or without a profile (the
///   owner need not onboard); the server decides who sees a proposal.
///   Signed-out people sent from it to the welcome screen carry
///   `?from=/admin`, and sign-in returns them there instead of
///   to Mi ronda or onboarding.
/// - a ronda's flyer (`/volante/{rondaId}`): like the tabs; the server
///   decides who may make it.
///
/// `/` and any unknown location land on Mi ronda, which the rules above
/// then redirect as needed.
GoRouter createAppRouter({
  required AppBloc appBloc,
  required Listenable refreshListenable,
}) {
  return GoRouter(
    initialLocation: MyRondaPage.path,
    refreshListenable: refreshListenable,
    redirect: (_, state) {
      final location = state.matchedLocation;
      final onWelcome =
          location == WelcomePage.path ||
          location.startsWith('${WelcomePage.path}/');
      final onOnboarding = location == OnboardingPage.path;
      final onAdmin = location == AdminPage.path;
      final returnTo =
          onWelcome &&
              state.uri.queryParameters[returnToParameter] == AdminPage.path
          ? AdminPage.path
          : null;
      final welcome = onAdmin || returnTo != null
          ? '${WelcomePage.path}?$returnToParameter=${AdminPage.path}'
          : WelcomePage.path;
      final app = appBloc.state;
      return switch (app.status) {
        AppStatus.unauthenticated when !onWelcome => welcome,
        AppStatus.unauthenticated
            when location == LoginPage.path && app.pendingTerms == null =>
          welcome,
        AppStatus.unauthenticated || AppStatus.loadingProfile => null,
        AppStatus.onboarding =>
          onOnboarding || onAdmin ? null : returnTo ?? OnboardingPage.path,
        AppStatus.authenticated =>
          onWelcome || onOnboarding ? returnTo ?? MyRondaPage.path : null,
      };
    },
    onException: (_, _, router) => router.go(MyRondaPage.path),
    routes: [
      GoRoute(path: '/', redirect: (_, _) => MyRondaPage.path),
      GoRoute(
        path: WelcomePage.path,
        builder: (_, _) => const WelcomePage(),
        routes: [
          GoRoute(
            path: LoginPage.segment,
            builder: (_, _) => const LoginPage(),
          ),
          GoRoute(
            path: TermsPage.segment,
            builder: (_, _) => const TermsPage(),
          ),
        ],
      ),
      GoRoute(
        path: OnboardingPage.path,
        builder: (_, _) => const OnboardingPage(),
      ),
      GoRoute(path: AdminPage.path, builder: (_, _) => const AdminPage()),
      GoRoute(
        path: MateFlyerPage.path,
        builder: (_, state) =>
            MateFlyerPage(rondaId: state.pathParameters['rondaId']!),
      ),
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
