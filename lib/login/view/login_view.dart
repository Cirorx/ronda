import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda_ui/ronda_ui.dart';
import 'package:url_launcher/url_launcher.dart';

/// Opens [uri] outside the app; `false` when nothing could open it.
typedef LinkOpener = Future<bool> Function(Uri uri);

/// Opens [uri] in the phone's browser.
Future<bool> openInBrowser(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

/// Why sign-in comes now ("Guardá tu lugar", or why the voice door needs
/// it), what Ronda never does with the account, the one "Seguir con Google"
/// button, and a link to make a Google account.
class const LoginView({
  /// Why the screen opened.
  final LoginReason reason = LoginReason.signIn,

  /// Opens Google's page to make an account; [openInBrowser] in the app.
  final LinkOpener openLink = openInBrowser,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handle on the Google button.
  static const googleButtonIdentifier = 'login_google';

  /// Maestro's handle on the link to make a Google account.
  static const createAccountIdentifier = 'login_create_account';

  /// Google's page to make an account.
  static final Uri createAccountUrl = Uri.parse(
    'https://accounts.google.com/signup',
  );

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
      appBar: AppBar(),
      body: SafeArea(
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
                  child: Text(l10n.loginGoogleButton),
                ),
              ),
            ),
            SizedBox(height: spacing.xs),
            // A link, read as one: the button keeps the 48 dp target.
            Semantics(
              container: true,
              identifier: createAccountIdentifier,
              link: true,
              linkUrl: createAccountUrl,
              label: l10n.loginNoGoogleAccount,
              onTap: () => openLink(createAccountUrl),
              excludeSemantics: true,
              child: TextButton(
                onPressed: () => openLink(createAccountUrl),
                child: Text(
                  l10n.loginNoGoogleAccount,
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
