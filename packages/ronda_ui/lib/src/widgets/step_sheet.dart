import 'package:ronda_ui/ronda_ui.dart';

/// {@template step_sheet}
/// A bottom sheet for one step: a title, a short body, an optional [child]
/// (steps, a picker) and a primary action with an optional secondary one.
///
/// The sheet scrolls, so it holds at large text sizes. It never closes
/// itself: the callbacks decide. The actions' semantics identifiers are
/// `<identifier>.primary` and `<identifier>.secondary`.
/// {@endtemplate}
class const StepSheet({
  /// Prefix of the actions' semantics identifiers ("microfono").
  required final String identifier,

  /// The sheet's title ("No podemos usar el micrófono").
  required final String title,

  /// The text under the title.
  required final String body,

  /// What the primary action says.
  required final String primaryLabel,

  /// Called when the person taps the primary action.
  required final VoidCallback onPrimary,

  /// What the secondary action says. Shown only with [onSecondary].
  final String? secondaryLabel,

  /// Called when the person taps the secondary action.
  final VoidCallback? onSecondary,

  /// Optional content between the body and the actions.
  final Widget? child,
  super.key,
}) extends StatelessWidget {
  /// {@macro step_sheet}
  this;

  /// Shows this sheet as a modal bottom sheet, sized to its content up to
  /// the full screen.
  Future<T?> show<T>(BuildContext context) {
    return showModalBottomSheet<T>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => this,
    );
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    return SingleChildScrollView(
      padding: EdgeInsets.only(
        left: spacing.lg,
        right: spacing.lg,
        bottom: spacing.lg,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing.md,
        children: [
          Semantics(
            header: true,
            child: Text(title, style: textTheme.headlineSmall),
          ),
          Text(body, style: textTheme.bodyMedium),
          ?child,
          MergeSemantics(
            child: Semantics(
              identifier: '$identifier.primary',
              child: FilledButton(
                onPressed: onPrimary,
                child: Text(primaryLabel, textAlign: TextAlign.center),
              ),
            ),
          ),
          if ((secondaryLabel, onSecondary) case (final label?, final onTap?))
            MergeSemantics(
              child: Semantics(
                identifier: '$identifier.secondary',
                child: OutlinedButton(
                  onPressed: onTap,
                  child: Text(label, textAlign: TextAlign.center),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
