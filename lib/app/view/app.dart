import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:needs_repository/needs_repository.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The app's root: provides the repositories bootstrap built and the
/// [AppBloc] that follows who is signed in and whether they have a profile.
class const App({
  required final AuthRepository authRepository,
  required final NeedsRepository needsRepository,
  required final ProfileRepository profileRepository,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider.value(value: authRepository),
        RepositoryProvider.value(value: needsRepository),
        RepositoryProvider.value(value: profileRepository),
      ],
      child: BlocProvider(
        create: (_) => AppBloc(
          authRepository: authRepository,
          profileRepository: profileRepository,
        )..add(const AppUserSubscriptionRequested()),
        child: const AppView(),
      ),
    );
  }
}

/// Shows the router in Ronda's day and night themes.
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

  @override
  void dispose() {
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
