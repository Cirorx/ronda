import 'package:ronda_ui/ronda_ui.dart';

/// {@template busy_label}
/// A button's label that, while [busy], carries a small progress ring in
/// the button's own colour: the button that was pressed shows that its
/// work is on its way. Wrap that button in an [IgnorePointer] while busy,
/// so it keeps its look but can't be pressed twice.
/// {@endtemplate}
class const BusyLabel(
  /// The button's words.
  final String label, {

  /// Whether the pressed button's work is on its way.
  final bool busy = false,
  super.key,
}) extends StatelessWidget {
  /// {@macro busy_label}
  this;

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
