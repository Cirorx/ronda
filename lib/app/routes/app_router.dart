import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/acta/acta.dart';
import 'package:ronda/admin/admin.dart';
import 'package:ronda/agent_trace/agent_trace.dart';
import 'package:ronda/app/bloc/app_bloc.dart';
import 'package:ronda/app/view/app_shell.dart';
import 'package:ronda/attendance/attendance.dart';
import 'package:ronda/cerca/cerca.dart';
import 'package:ronda/error_log/error_log.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda/mate_flyer/mate_flyer.dart';
import 'package:ronda/my_ronda/my_ronda.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/payoff/payoff.dart';
import 'package:ronda/rain_move/rain_move.dart';
import 'package:ronda/ronda_setup/ronda_setup.dart';
import 'package:ronda/settings/settings.dart';
import 'package:ronda/welcome/welcome.dart';

/// The welcome screen's query parameter that says where sign-in started,
/// so the router returns there once it is done. Only [AdminPage.path] is
/// honoured.
const returnToParameter = 'from';

/// Builds the app's router: the welcome screen with sign-in and the terms
/// under it, onboarding, the payoff with its sign-in under it, and one shell
/// with a branch per tab.
///
/// Where people may be follows [appBloc]'s state, and [refreshListenable]
/// fires when it changes, so the redirect runs again on every change:
/// - signed out: the welcome screen and the terms; once a welcome door
///   accepted the terms, also the questions, the payoff and either sign-in
///   (the answers stay on the phone until then);
/// - signed in, profile not read yet: wherever they are;
/// - signed in without a profile: onboarding, which saves the answers held
///   on the phone straight away when there are some;
/// - signed in with a profile: the tabs, never welcome, onboarding or the
///   payoff;
/// - the admin screen, its trace (`/admin/programa`) and the app's errors
///   (`/admin/errores`): anyone signed in, with or without a profile (the
///   owner need not onboard); the server decides who sees a proposal.
///   Signed-out people sent from it to the welcome screen carry
///   `?from=/admin`, and sign-in returns them there instead of
///   to Mi ronda or onboarding.
/// - a ronda's flyer (`/volante/{rondaId}`): like the tabs; the server
///   decides who may make it.
/// - Ajustes' screens (`/ajustes/avisos`, `/ajustes/contar`,
///   `/ajustes/datos`): like the tabs, inside the Ajustes tab.
/// - a ronda's acta (`/acta/{rondaId}`), the host's rain proposal
///   (`/lluvia/{rondaId}/{week}`, opened from the push) and the host's
///   "¿Quién vino hoy?" (`/asistencia/{rondaId}/{week}`): like the tabs;
///   the rules decide who reads them. The admin's own copies of the last
///   one and "Lugar, hora y anfitriones" sit under `/admin`.
///
/// `/` and any unknown location land on Mi ronda, which the rules above
/// then redirect as needed.
///
/// Every route is a plain [GoRoute], so its page is a [MaterialPage] and
/// the theme's `RondaPageTransitionsBuilder` moves between screens: a push
/// comes in from the right and goes back out to the right, with the edge
/// swipe back, or cross-fades with reduced motion. The tabs are an indexed
/// stack, so switching tabs doesn't slide.
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
      final onPayoff =
          location == PayoffPage.path ||
          location.startsWith('${PayoffPage.path}/');
      final onAdmin =
          location == AdminPage.path ||
          location.startsWith('${AdminPage.path}/');
      final returnTo =
          onWelcome &&
              state.uri.queryParameters[returnToParameter] == AdminPage.path
          ? AdminPage.path
          : null;
      final welcome = onAdmin || returnTo != null
          ? '${WelcomePage.path}?$returnToParameter=${AdminPage.path}'
          : WelcomePage.path;
      final app = appBloc.state;
      // Past a welcome door: the terms are accepted, on this phone.
      final pastDoor = location == LoginPage.path || onOnboarding || onPayoff;
      return switch (app.status) {
        AppStatus.unauthenticated when !onWelcome && !pastDoor => welcome,
        AppStatus.unauthenticated when pastDoor && app.pendingTerms == null =>
          welcome,
        AppStatus.unauthenticated || AppStatus.loadingProfile => null,
        AppStatus.onboarding =>
          onOnboarding || onAdmin ? null : returnTo ?? OnboardingPage.path,
        AppStatus.authenticated =>
          onWelcome || onOnboarding || onPayoff
              ? returnTo ?? MyRondaPage.path
              : null,
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
            builder: (context, _) => LoginPage(
              reason: context.read<AppBloc>().state.door == OnboardingDoor.voice
                  ? LoginReason.voice
                  : LoginReason.signIn,
            ),
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
      GoRoute(
        path: PayoffPage.path,
        builder: (_, _) => const PayoffPage(),
        routes: [
          GoRoute(
            path: LoginPage.segment,
            builder: (_, _) => const LoginPage(reason: LoginReason.keepSeat),
          ),
        ],
      ),
      GoRoute(
        path: AdminPage.path,
        builder: (_, _) => const AdminPage(),
        routes: [
          GoRoute(
            path: AgentTracePage.segment,
            builder: (_, _) => const AgentTracePage(),
          ),
          GoRoute(
            path: RondaSetupPage.segment,
            builder: (_, _) => const RondaSetupPage(),
          ),
          GoRoute(
            path: ErrorLogPage.segment,
            builder: (_, _) => const ErrorLogPage(),
          ),
          GoRoute(
            path: AttendancePage.adminSegment,
            builder: (_, state) => AttendancePage(
              rondaId: state.pathParameters['rondaId']!,
              week: state.pathParameters['week']!,
            ),
          ),
        ],
      ),
      GoRoute(
        path: ActaPage.path,
        builder: (_, state) =>
            ActaPage(rondaId: state.pathParameters['rondaId']!),
      ),
      GoRoute(
        path: RainMovePage.path,
        builder: (_, state) => RainMovePage(
          rondaId: state.pathParameters['rondaId']!,
          week: state.pathParameters['week']!,
        ),
      ),
      GoRoute(
        path: AttendancePage.path,
        builder: (_, state) => AttendancePage(
          rondaId: state.pathParameters['rondaId']!,
          week: state.pathParameters['week']!,
        ),
      ),
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
                routes: [
                  GoRoute(
                    path: NotificationsPage.segment,
                    builder: (_, _) => const NotificationsPage(),
                  ),
                  GoRoute(
                    path: ReportPage.segment,
                    builder: (_, _) => const ReportPage(),
                  ),
                  GoRoute(
                    path: YourDataPage.segment,
                    builder: (_, _) => const YourDataPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}
