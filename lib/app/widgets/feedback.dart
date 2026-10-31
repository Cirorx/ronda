import 'package:ronda_ui/ronda_ui.dart';

/// {@template status_line}
/// A short line that says what is happening ("Guardando tu respuesta…") or
/// what just happened, read out by screen readers when it appears or
/// changes.
/// {@endtemplate}
class const StatusLine(
  /// What it says.
  final String text, {
  final TextAlign textAlign = TextAlign.start,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Text(
        text,
        textAlign: textAlign,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// {@template loading_status}
/// What a screen shows while it reads: a small progress ring over a
/// [StatusLine] that says what it is looking for, never a bare spinner.
/// {@endtemplate}
class const LoadingStatus(
  /// What it is looking for ("Buscando tu ronda…").
  final String text, {
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final spacing = context.appSpacing;
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

/// {@template busy_label}
/// A button's label that, while [busy], carries a small progress ring in
/// the button's own colour: the button that was pressed shows that its
/// work is on its way. Wrap that button in an `IgnorePointer` while busy,
/// so it keeps its look but can't be pressed twice.
/// {@endtemplate}
class const BusyLabel(
  /// The button's words.
  final String label, {

  /// Whether the pressed button's work is on its way.
  final bool busy = false,
  super.key,
}) extends StatelessWidget {
  /// How thick the ring is.
  static const double strokeWidth = 2;

  @override
  Widget build(BuildContext context) {
    final text = Text(label, textAlign: TextAlign.center);
    if (!busy) return text;
    final icon = IconTheme.of(context);
    final size = MediaQuery.textScalerOf(context)
        .scale(icon.size ?? const IconThemeData.fallback().size!);
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: context.appSpacing.xs,
      children: [
        ExcludeSemantics(
          child: SizedBox.square(
            dimension: size,
            child: CircularProgressIndicator(
              strokeWidth: strokeWidth,
              color: icon.color,
            ),
          ),
        ),
        Flexible(child: text),
      ],
    );
  }
}

/// A [RondaSwap] layout for states stacked in a column: both states take
/// the column's width and hang from its top start while they swap, so the
/// shorter one never floats in the middle of the taller one.
Widget topStartSwapLayout(Widget? current, List<Widget> previous) =>
    Stack(fit: StackFit.passthrough, children: [...previous, ?current]);
