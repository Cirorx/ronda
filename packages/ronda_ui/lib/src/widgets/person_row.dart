import 'package:ronda_ui/ronda_ui.dart';

/// {@template person_row}
/// One neighbour in "Quiénes van": an initial in a circle, the first name,
/// and what they do or bring ("Llega primero · lleva el termo").
///
/// People are initials, never photos. The ruled sheet's margin line runs
/// between the initial and the text, so stacked rows read as one planilla.
/// With large text the initial and the line drop out and only the words stay.
/// The row is read as one item.
/// {@endtemplate}
class const PersonRow({
  /// The letter in the circle ("M").
  required final String initial,

  /// The first name, or "Vos" for the person using the app.
  required final String name,

  /// What they do or bring ("Llega primero · lleva el termo").
  required final String detail,

  /// Whether this row is the person using the app; its initial is in birome.
  final bool isYou = false,

  /// Whether a divider runs under the row. Off for the last one.
  final bool showDivider = true,
  super.key,
}) extends StatelessWidget {
  /// {@macro person_row}
  this;

  /// Width of the initial's column; the margin line runs at its edge.
  static const double initialColumnWidth = 50;

  /// Diameter of the initial's circle.
  static const double initialSize = 36;

  /// Shortest row, so a list of people keeps the planilla's ruling.
  static const double minRowHeight = 56;

  /// How strongly the margin line shows through.
  static const double marginLineOpacity = 0.55;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = context.appSpacing;
    final words = MergeSemantics(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(name, style: theme.textTheme.titleSmall),
          Text(
            detail,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );

    final Widget content;
    if (context.usesLargeText) {
      content = Padding(
        padding: EdgeInsets.symmetric(vertical: spacing.sm),
        child: words,
      );
    } else {
      content = IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              width: initialColumnWidth,
              child: Align(
                alignment: AlignmentDirectional.centerStart,
                child: ExcludeSemantics(
                  child: _Initial(initial: initial, isYou: isYou),
                ),
              ),
            ),
            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: BorderDirectional(
                    start: BorderSide(
                      color: context.rondaPalette.margen.withValues(
                        alpha: marginLineOpacity,
                      ),
                    ),
                  ),
                ),
                child: Padding(
                  padding: EdgeInsetsDirectional.only(
                    start: spacing.sm,
                    top: spacing.xs,
                    bottom: spacing.xs,
                  ),
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: words,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return DecoratedBox(
      decoration: BoxDecoration(
        border: showDivider
            ? Border(
                bottom: BorderSide(color: theme.colorScheme.outlineVariant),
              )
            : null,
      ),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: minRowHeight),
        child: content,
      ),
    );
  }
}

class const _Initial({required final String initial, required final bool isYou})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Container(
      width: PersonRow.initialSize,
      height: PersonRow.initialSize,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: scheme.surfaceContainer,
        border: Border.all(
          color: isYou ? scheme.primary : scheme.outlineVariant,
          width: AppTheme.borderWidth,
        ),
      ),
      child: Text(
        initial,
        style: theme.textTheme.titleSmall?.copyWith(
          color: isYou ? scheme.primary : scheme.onSurface,
        ),
      ),
    );
  }
}
