import 'package:ronda_ui/ronda_ui.dart';

/// {@template loading_status}
/// What a screen shows while it reads: a [RondaLoader] and a [StatusLine]
/// that says what it is looking for, never a bare spinner.
///
/// By default the loader sits over the line, centred in the space it has;
/// [LoadingStatus.inline] puts a small one at the start of a row, for a
/// status inside a list.
/// {@endtemplate}
class LoadingStatus extends StatelessWidget {
  /// {@macro loading_status}
  const new(this.text, {super.key}) : _inline = false;

  /// A small loader at the start of a row, the line beside it in
  /// [TextTheme.bodyLarge].
  const new inline(this.text, {super.key}) : _inline = true;

  /// What it is looking for ("Buscando tu ronda…").
  final String text;

  final bool _inline;

  /// The size of the loader in a row.
  static const double inlineSize = 24;

  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
    if (_inline) {
      final theme = Theme.of(context);
      return Row(
        spacing: spacing.sm,
        children: [
          const ExcludeSemantics(child: RondaLoader(size: inlineSize)),
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
            const ExcludeSemantics(child: RondaLoader()),
            StatusLine(text, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
