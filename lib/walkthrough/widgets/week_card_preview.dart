import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template week_card_preview}
/// A sample of the weekly card on Mi ronda, as a picture: a day, hour and
/// place, and "¿Venís?" with [Voy] [Esta no] drawn as the real [RsvpBar].
///
/// Nothing in it can be tapped or focused, and a screen reader reads it as
/// one line that says what it shows, never as buttons.
/// {@endtemplate}
class const WeekCardPreview({super.key}) extends StatelessWidget {
  /// {@macro week_card_preview}
  this;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    return Semantics(
      container: true,
      label: l10n.walkthroughWeekPreviewSemantics,
      excludeSemantics: true,
      child: ExcludeFocus(
        child: IgnorePointer(
          child: Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: EdgeInsets.all(spacing.md),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: spacing.md,
                children: [
                  Text(
                    l10n.walkthroughWeekPreviewWhen,
                    style: textTheme.titleMedium,
                  ),
                  RsvpBar(
                    identifier: 'walkthrough.preview',
                    question: l10n.thisWeekQuestion,
                    yesLabel: l10n.thisWeekYes,
                    noLabel: l10n.thisWeekNo,
                    onYes: _nothing,
                    onNo: _nothing,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // A picture of the buttons: they keep the real look and do nothing.
  static void _nothing() {}
}
