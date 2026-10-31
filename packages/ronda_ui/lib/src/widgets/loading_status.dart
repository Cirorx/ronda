import 'package:ronda_ui/ronda_ui.dart';

/// {@template loading_status}
/// What a screen shows while it reads: a progress ring and a [StatusLine]
/// that says what it is looking for, never a bare spinner.
///
/// By default the ring sits over the line, centred in the space it has;
/// [LoadingStatus.inline] puts a small ring at the start of a row, for a
/// status inside a list.
/// {@endtemplate}
class LoadingStatus extends StatelessWidget {
  /// {@macro loading_status}
  const new(this.text, {super.key}) : _inline = false;

  /// A small ring at the start of a row, the line beside it in
  /// [TextTheme.bodyLarge].
  const new inline(this.text, {super.key}) : _inline = true;

  /// What it is looking for ("Buscando tu ronda…").
  final String text;

  final bool _inline;

  /// The size of the ring in a row.
  static const double inlineSize = 24;

  /// How thick the ring in a row is.
  static const double inlineStrokeWidth = 3;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    if (_inline) {
      final theme = Theme.of(context);
      return Row(
        spacing: spacing.sm,
        children: [
          const ExcludeSemantics(
            child: SizedBox.square(
              dimension: inlineSize,
              child: CircularProgressIndicator(strokeWidth: inlineStrokeWidth),
            ),
          ),
          Expanded(
            child: StatusLine(
              text,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      );
    }
    return Center(
      child: Padding(
        padding: EdgeInsetsDirectional.all(spacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: spacing.sm,
          children: [
            const ExcludeSemantics(child: CircularProgressIndicator()),
            StatusLine(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
