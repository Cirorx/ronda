import 'package:go_router/go_router.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/welcome/welcome.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "Las condiciones, en corto": the six plain points the welcome screen
/// links, set apart by space rather than rules, and where each thing
/// happens. "Condiciones" in the top bar, with the way back to the doors.
class const TermsPage({super.key}) extends StatelessWidget {
  /// The path under [WelcomePage.path].
  static const segment = 'condiciones';

  static const path = '/bienvenida/$segment';

  /// Maestro's handle on "Entendido".
  static const doneIdentifier = 'terms.done';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final spacing = context.appSpacing;
    final points = [
      l10n.termsFree,
      l10n.termsPublicAdults,
      l10n.termsWhatWeKeep,
      l10n.termsAudio,
      l10n.termsYourData,
      l10n.termsReports,
    ];

    return Scaffold(
      appBar: AppBar(title: Text(l10n.termsBarTitle)),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: spacing.lg,
            vertical: spacing.md,
          ),
          children: [
            Semantics(
              header: true,
              child: Text(l10n.termsTitle, style: textTheme.headlineMedium),
            ),
            SizedBox(height: spacing.md),
            for (final (index, point) in points.indexed) ...[
              if (index > 0) SizedBox(height: spacing.sm),
              MergeSemantics(
                child: Padding(
                  padding: EdgeInsetsDirectional.symmetric(
                    vertical: spacing.xs,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: spacing.sm,
                    children: [
                      Text(
                        '${index + 1}',
                        style: textTheme.titleMedium?.copyWith(
                          color: theme.colorScheme.primary,
                        ),
                      ),
                      Expanded(child: Text(point, style: textTheme.bodyLarge)),
                    ],
                  ),
                ),
              ),
            ],
            SizedBox(height: spacing.md),
            Text(
              l10n.termsWhere,
              style: textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            SizedBox(height: spacing.lg),
            MergeSemantics(
              child: Semantics(
                identifier: doneIdentifier,
                child: FilledButton(
                  onPressed: () => context.go(WelcomePage.path),
                  child: Text(l10n.termsDone),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
