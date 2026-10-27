import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Primero, entrá con tu cuenta", what Ronda never does with the account,
/// and the one "Seguir con Google" button.
class const LoginView({super.key}) extends StatelessWidget {
  /// Maestro's handle on the Google button.
  static const googleButtonIdentifier = 'login_google';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<LoginCubit>().state;
    // Disabled while the picker is open and until the router moves on.
    final inProgress =
        state.status == LoginStatus.inProgress ||
        state.status == LoginStatus.success;

    return Scaffold(
      // Its back button returns to the welcome doors.
      appBar: AppBar(),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.md,
          ),
          children: [
            Text(l10n.loginTitle, style: textTheme.headlineMedium),
            SizedBox(height: spacing.lg),
            for (final line in [
              l10n.loginNoPosting,
              l10n.loginNoContacts,
              l10n.loginFirstNameOnly,
            ])
              Padding(
                padding: EdgeInsetsDirectional.only(bottom: spacing.sm),
                child: Text(line, style: textTheme.bodyLarge),
              ),
            SizedBox(height: spacing.lg),
            if (state.error case final error?) ...[
              NoteBanner(
                variant: error == LoginError.network
                    ? NoteBannerVariant.offline
                    : NoteBannerVariant.warning,
                message: error == LoginError.network
                    ? l10n.loginNetworkError
                    : l10n.loginError,
              ),
              SizedBox(height: spacing.md),
            ],
            MergeSemantics(
              child: Semantics(
                identifier: googleButtonIdentifier,
                child: FilledButton(
                  onPressed: inProgress
                      ? null
                      : () => context.read<LoginCubit>().signInWithGoogle(),
                  child: Text(l10n.loginGoogleButton),
                ),
              ),
            ),
            SizedBox(height: spacing.md),
            Text(
              l10n.loginNoGoogleAccount,
              textAlign: TextAlign.center,
              style: textTheme.bodyMedium,
            ),
          ],
        ),
      ),
    );
  }
}
