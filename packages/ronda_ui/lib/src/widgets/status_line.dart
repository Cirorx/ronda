import 'package:ronda_ui/ronda_ui.dart';

/// {@template status_line}
/// A short line that says what is happening ("Guardando tu respuesta…") or
/// what just happened, read out by screen readers when it appears or
/// changes.
///
/// It is muted body text by default; [style] replaces that where the line
/// carries the screen's message.
/// {@endtemplate}
class const StatusLine(
  /// What it says.
  final String text, {

  /// How it lines up.
  final TextAlign textAlign = TextAlign.start,

  /// Its style; muted [TextTheme.bodyMedium] by default.
  final TextStyle? style,
  super.key,
}) extends StatelessWidget {
  /// {@macro status_line}
  this;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      container: true,
      liveRegion: true,
      child: Text(
        text,
        textAlign: textAlign,
        style:
            style ??
            theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
      ),
    );
  }
}
