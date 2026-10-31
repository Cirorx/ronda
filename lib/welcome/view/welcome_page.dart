import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/login/login.dart';
import 'package:ronda/onboarding/onboarding.dart';
import 'package:ronda/walkthrough/walkthrough.dart';
import 'package:ronda/welcome/welcome.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Whether the welcome screen shows "Con un audio".
const voiceDoorEnabled = true;

/// Where signed-out people land: what Ronda is, the doors in, and the
/// conditions they accept by going through one.
///
/// Tapping a door adds [AppTermsAccepted]; once [AppBloc] holds the
/// acceptance, this page moves on: "Tocando botones" to the questions,
/// signed out (sign-in comes after the payoff); "Con un audio" to sign-in,
/// because the server reads the audio. Someone sent here to sign in and
/// return (`?from=/admin`) goes to sign-in through either door, keeping
/// that query. "¿Cómo funciona?" opens the walkthrough again over it.
class const WelcomePage({
  /// Whether "Con un audio" is shown; [voiceDoorEnabled] in the app.
  final bool showVoiceDoor = voiceDoorEnabled,
  super.key,
}) extends StatelessWidget {
  static const path = '/bienvenida';

  /// Maestro's handle on "Con un audio".
  static const voiceDoorIdentifier = 'welcome.voice';

  /// Maestro's handle on "Tocando botones".
  static const buttonsDoorIdentifier = 'welcome.buttons';

  /// Maestro's handle on "¿Cómo funciona?".
  static const howItWorksIdentifier = 'welcome.howItWorks';

  /// Maestro's handle on the conditions link.
  static const termsLinkIdentifier = 'welcome.terms';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final spacing = context.appSpacing;
    final wide = context.windowSize.isWide;

    void acceptTerms(OnboardingDoor door) =>
        context.read<AppBloc>().add(AppTermsAccepted(door: door));

    return BlocListener<AppBloc, AppState>(
      listenWhen: (previous, current) =>
          current.pendingTerms != null &&
          current.pendingTerms != previous.pendingTerms,
      listener: (context, state) {
        final uri = GoRouterState.of(context).uri;
        final returning = uri.queryParameters.containsKey(returnToParameter);
        context.go(
          state.door == OnboardingDoor.buttons && !returning
              ? OnboardingPage.path
              : uri.replace(path: LoginPage.path).toString(),
        );
      },
      child: Scaffold(
        body: SafeArea(
          // On a phone the doors and the terms note sit at the bottom while
          // they fit; wider up the screen keeps to the readable column, with
          // the doors right under the copy and the two centred together.
          // Either way the whole screen scrolls when it doesn't fit (large
          // text, a short window).
          child: ReadableColumn(
            child: LayoutBuilder(
              builder: (context, constraints) => SingleChildScrollView(
                padding: EdgeInsetsDirectional.symmetric(
                  horizontal: spacing.lg,
                  vertical: spacing.xlg,
                ),
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: constraints.maxHeight - 2 * spacing.xlg,
                  ),
                  child: Column(
                    mainAxisAlignment: wide
                        ? MainAxisAlignment.center
                        : MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    spacing: wide ? spacing.xlg : spacing.lg,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: spacing.md,
                        children: [
                          // The link shares the name's line, so the doors
                          // don't move down for it.
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  l10n.appTitle,
                                  style: textTheme.headlineSmall?.copyWith(
                                    color: theme.colorScheme.primary,
                                  ),
                                ),
                              ),
                              const Flexible(child: _HowItWorksLink()),
                            ],
                          ),
                          Semantics(
                            header: true,
                            child: Text(
                              l10n.welcomeTitle,
                              style: textTheme.headlineMedium,
                            ),
                          ),
                          Text(l10n.welcomeBody, style: textTheme.bodyLarge),
                        ],
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: spacing.sm,
                        children: [
                          Text(
                            l10n.welcomeDoorsHeading,
                            style: textTheme.titleSmall?.copyWith(
                              color: theme.colorScheme.onSurfaceVariant,
                            ),
                          ),
                          if (showVoiceDoor)
                            WelcomeDoor(
                              identifier: voiceDoorIdentifier,
                              icon: Icons.mic_none,
                              title: l10n.welcomeVoiceDoorTitle,
                              subtitle: l10n.welcomeVoiceDoorSubtitle,
                              onTap: () => acceptTerms(OnboardingDoor.voice),
                            ),
                          WelcomeDoor(
                            identifier: buttonsDoorIdentifier,
                            icon: Icons.touch_app_outlined,
                            title: l10n.welcomeButtonsDoorTitle,
                            subtitle: l10n.welcomeButtonsDoorSubtitle,
                            onTap: () => acceptTerms(OnboardingDoor.buttons),
                          ),
                          TermsNote(
                            identifier: termsLinkIdentifier,
                            lead: l10n.welcomeTermsLead,
                            linkLabel: l10n.welcomeTermsLink,
                            trailing: l10n.welcomeTermsTrailing,
                            onLinkTap: () => context.go(TermsPage.path),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// "¿Cómo funciona?": the walkthrough again, over the welcome screen.
class const _HowItWorksLink() extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: AlignmentDirectional.centerEnd,
      child: MergeSemantics(
        child: Semantics(
          identifier: WelcomePage.howItWorksIdentifier,
          child: TextButton(
            onPressed: () => context.push(WalkthroughPage.path),
            child: Text(context.l10n.welcomeHowItWorks),
          ),
        ),
      ),
    );
  }
}
