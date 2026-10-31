import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Why sign-in comes now ("Guardá tu lugar", or why the voice door needs
/// it), what Ronda never does with the account, the one "Seguir con Google"
/// button, which shows it is working while sign-in runs, and a link to make
/// a Google account. A failure says so in a banner that is read out.
class const LoginView({
  /// Why the screen opened.
  final LoginReason reason = LoginReason.signIn,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handle on the Google button.
  static const googleButtonIdentifier = 'login_google';

  /// Maestro's handle on the link to make a Google account.
  static const createAccountIdentifier = 'login_create_account';

  /// The spinner beside "Seguir con Google" while sign-in runs.
  static const double _spinnerSize = 18;
  static const double _spinnerStroke = 2;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final state = context.watch<LoginCubit>().state;
    final (title, body) = switch (reason) {
      LoginReason.keepSeat => (l10n.loginKeepSeatTitle, l10n.loginKeepSeatBody),
      LoginReason.voice => (l10n.loginVoiceTitle, null),
      LoginReason.signIn => (l10n.loginTitle, null),
    };
    // Disabled while the picker is open and until the router moves on.
    final inProgress =
        state.status == LoginStatus.inProgress ||
        state.status == LoginStatus.success;

    return Scaffold(
      // Its back button returns to the welcome doors.
      appBar: AppBar(title: Text(l10n.loginBarTitle)),
      body: SafeArea(
        child: ReadableColumn(
          child: ListView(
            padding: EdgeInsetsDirectional.symmetric(
              horizontal: spacing.lg,
              vertical: spacing.md,
            ),
            children: [
              Semantics(
                header: true,
                child: Text(title, style: textTheme.headlineMedium),
              ),
              if (body case final body?) ...[
                SizedBox(height: spacing.xs),
                Text(body, style: textTheme.bodyLarge),
              ],
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
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: spacing.xs,
                      children: [
                        if (inProgress)
                          SizedBox.square(
                            dimension: _spinnerSize,
                            child: CircularProgressIndicator(
                              strokeWidth: _spinnerStroke,
                              semanticsLabel: l10n.loginInProgress,
                            ),
                          ),
                        Flexible(
                          child: Text(
                            l10n.loginGoogleButton,
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: spacing.xs),
              // A link, read as one: the button keeps the 48 dp target.
              Semantics(
                container: true,
                identifier: createAccountIdentifier,
                link: true,
                linkUrl: AuthRepository.createAccountUrl,
                label: l10n.loginNoGoogleAccount,
                onTap: () => context.read<LoginCubit>().createAccountTapped(),
                excludeSemantics: true,
                child: TextButton(
                  onPressed: () =>
                      context.read<LoginCubit>().createAccountTapped(),
                  child: Text(
                    l10n.loginNoGoogleAccount,
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
