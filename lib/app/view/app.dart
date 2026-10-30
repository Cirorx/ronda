import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:contact_repository/contact_repository.dart';
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

/// The app's root: provides the repositories bootstrap built and the
/// [AppBloc] that follows who is signed in and whether they have a profile.
class const App({
  required final AuthRepository authRepository,
  required final ContactRepository contactRepository,
  required final FlyerRepository flyerRepository,
  required final NeedsRepository needsRepository,
  required final OnboardingRepository onboardingRepository,
  required final OrganiserRepository organiserRepository,
  required final ProfileRepository profileRepository,
  required final PushRepository pushRepository,
  required final RondaRepository rondaRepository,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: contactRepository),
        RepositoryProvider.value(value: flyerRepository),
        RepositoryProvider.value(value: needsRepository),
        RepositoryProvider.value(value: onboardingRepository),
        RepositoryProvider.value(value: organiserRepository),
        RepositoryProvider.value(value: profileRepository),
        RepositoryProvider.value(value: pushRepository),
        RepositoryProvider.value(value: rondaRepository),
      ],
      child: BlocProvider(
        create: (_) => AppBloc(
          authRepository: authRepository,
          profileRepository: profileRepository,
          pushRepository: pushRepository,
        )..add(const AppUserSubscriptionRequested()),
        child: const AppView(),
      ),
    );
  }
}

/// Shows the router in Ronda's day and night themes, and opens the roll
/// when "¿Quién vino hoy?" is tapped on Android, whether the tap started the
/// app or found it running.
class AppView extends StatefulWidget {
  const new({super.key});

  @override
  State<AppView> createState() => _AppViewState();
}

class _AppViewState extends State<AppView> {
  late final BlocRefreshListenable _refresh = BlocRefreshListenable(
    context.read<AppBloc>().stream,
  );
  late final GoRouter _router = createAppRouter(
    appBloc: context.read<AppBloc>(),
    refreshListenable: _refresh,
  );

  StreamSubscription<OpenedRoll>? _rolls;

  @override
  void initState() {
    super.initState();
    final push = context.read<PushRepository>();
    _rolls = push.openedRolls.listen(_openRoll);
    unawaited(
      push.launchedRoll().then((roll) {
        if (roll != null && mounted) _openRoll(roll);
      }),
    );
  }

  void _openRoll(OpenedRoll roll) =>
      unawaited(_router.push(AttendancePage.location(roll.rondaId, roll.week)));

  @override
  void dispose() {
    unawaited(_rolls?.cancel());
    _router.dispose();
    _refresh.dispose();
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
      localeListResolutionCallback: (locales, _) => resolveAppLocale(locales),
      routerConfig: _router,
    );
  }
}
