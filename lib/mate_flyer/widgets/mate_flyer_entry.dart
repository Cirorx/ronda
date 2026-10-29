import 'package:go_router/go_router.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/mate_flyer/view/mate_flyer_page.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The host's way in to "Un mate de más" for ronda [rondaId]: one card
/// with [Hacer el volante]. Mi ronda shows it to the ronda's hosts once it
/// keeps a newcomer seat (from week 4).
class const MateFlyerEntry({
  /// The ronda whose flyer it makes.
  required final String rondaId,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handle on [Hacer el volante].
  static const identifier = 'mateFlyer.entry';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final textTheme = Theme.of(context).textTheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.mateFlyerTitle, style: textTheme.titleMedium),
            SizedBox(height: spacing.xs),
            Text(l10n.mateFlyerEntryBody, style: textTheme.bodyMedium),
            SizedBox(height: spacing.sm),
            MergeSemantics(
              child: Semantics(
                identifier: identifier,
                child: FilledButton(
                  onPressed: () =>
                      context.push(MateFlyerPage.location(rondaId)),
                  child: Text(l10n.mateFlyerMake),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
