import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:contact_repository/contact_repository.dart';
import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:donde_queda_repository/donde_queda_repository.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flyer_repository/flyer_repository.dart';
import 'package:go_router/go_router.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:onboarding_repository/onboarding_repository.dart';
import 'package:organiser_repository/organiser_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:push_repository/push_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/attendance/attendance.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_repository/ronda_repository.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

/// The app's root: provides the repositories bootstrap built, the [AppBloc]
/// that follows who is signed in and whether they have a profile, and the
/// [AdminAccessCubit] that reads whether they are the admin.
class const App({
  required final AuthRepository authRepository,
  required final ContactRepository contactRepository,
  required final CuadernoRepository cuadernoRepository,
  required final DondeQuedaRepository dondeQuedaRepository,
  required final FlyerRepository flyerRepository,
  required final NeedsRepository needsRepository,
  required final OnboardingRepository onboardingRepository,
  required final OrganiserRepository organiserRepository,
  required final ProfileRepository profileRepository,
  required final PushRepository pushRepository,
  required final RondaRepository rondaRepository,
  required final SmallPlanRepository smallPlanRepository,

  /// Whether this phone has shown "¿Cómo funciona?", read before the app
  /// starts so the first screen is already the right one.
  required final bool walkthroughSeen,

  /// The language picked on this phone, read before the app starts;
  /// `null` follows the phone's language.
  final AppLanguage? language,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: contactRepository),
        RepositoryProvider.value(value: cuadernoRepository),
        RepositoryProvider.value(value: dondeQuedaRepository),
        RepositoryProvider.value(value: flyerRepository),
        RepositoryProvider.value(value: needsRepository),
        RepositoryProvider.value(value: onboardingRepository),
        RepositoryProvider.value(value: organiserRepository),
        RepositoryProvider.value(value: profileRepository),
        RepositoryProvider.value(value: pushRepository),
        RepositoryProvider.value(value: rondaRepository),
        RepositoryProvider.value(value: smallPlanRepository),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) => AppBloc(
              authRepository: authRepository,
              profileRepository: profileRepository,
              pushRepository: pushRepository,
              walkthroughSeen: walkthroughSeen,
            )..add(const AppUserSubscriptionRequested()),
          ),
          BlocProvider(
            create: (_) => LanguageCubit(
              profileRepository: profileRepository,
              initial: language,
            ),
          ),
          BlocProvider(
            create: (_) =>
                AdminAccessCubit(authRepository: authRepository)..subscribe(),
          ),
        ],
        child: const AppView(),
      ),
    );
  }
}

/// Shows the router in Ronda's day and night themes, in the language picked
/// on this phone (else the phone's), and opens the roll
/// when "¿Quién vino hoy?" is tapped on Android, whether the tap started the
/// app or found it running. Tells the [ErrorReporter] bootstrap provides, if
/// any, which route pattern is on screen, so error reports say where.
class AppView extends StatefulWidget {
  const new({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  late final BlocRefreshListenable _appRefresh = BlocRefreshListenable(
    context.read<AppBloc>().stream,
  );
  late final BlocRefreshListenable _adminRefresh = BlocRefreshListenable(
    context.read<AdminAccessCubit>().stream,
  );
  late final GoRouter _router = createAppRouter(
    appBloc: context.read<AppBloc>(),
    adminAccess: context.read<AdminAccessCubit>(),
    refreshListenable: Listenable.merge([_appRefresh, _adminRefresh]),
  );

  StreamSubscription<OpenedRoll>? _rolls;
  ErrorReporter? _errorReporter;

  @override
  void initState() {
    super.initState();
    _errorReporter = context.read<ErrorReporter?>();
    _router.routerDelegate.addListener(_reportScreen);
    _reportScreen();
    final push = context.read<PushRepository>();
    _rolls = push.openedRolls.listen(_openRoll);
    unawaited(
      push.launchedRoll().then((roll) {
        if (roll != null && mounted) _openRoll(roll);
      }),
    );
  }

  // The pattern (`/acta/:rondaId`), never the filled path with its ids.
  void _reportScreen() => _errorReporter?.setScreen(
    _router.routerDelegate.currentConfiguration.fullPath,
  );

  void _openRoll(OpenedRoll roll) =>
      unawaited(_router.push(AttendancePage.location(roll.rondaId, roll.week)));

  @override
  void dispose() {
    unawaited(_rolls?.cancel());
    _router.routerDelegate.removeListener(_reportScreen);
    _router.dispose();
    _appRefresh.dispose();
    _adminRefresh.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      onGenerateTitle: (context) => context.l10n.appTitle,
      // Dark mode follows the system (themeMode defaults to system).
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: context.select<LanguageCubit, Locale?>(
        (cubit) => cubit.state.locale,
      ),
      localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
      routerConfig: _router,
    );
  }
}
