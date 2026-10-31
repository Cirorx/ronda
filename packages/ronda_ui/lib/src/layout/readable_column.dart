import 'package:ronda_ui/ronda_ui.dart';

/// {@template readable_column}
/// Keeps [child] at a readable width on wide windows: centred on the paper,
/// at most [WindowSize.readableWidth] wide, with the ruled sheet's margin
/// line running down its start side, so nothing stretches edge to edge.
///
/// On a phone ([WindowSize.compact]) it is [child] alone, as before.
/// {@endtemplate}
class const ReadableColumn({
  /// The column's content; it gets the full height.
  required final Widget child,

  /// The widest the column gets.
  final double maxWidth = WindowSize.readableWidth,
  super.key,
}) extends StatelessWidget {
  /// {@macro readable_column}
  this;

  @override
  Widget build(BuildContext context) {
    if (!context.windowSize.isWide) return child;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: RuledMargin(child: child),
      ),
    );
  }
}

/// {@template ruled_margin}
/// The ruled sheet's margin line down the start side of [child]: margen,
/// as faint as it is between a [PersonRow]'s initial and its words. It is
/// paper, not content, so screen readers never meet it.
/// {@endtemplate}
class const RuledMargin({required final Widget child, super.key})
    extends StatelessWidget {
  /// {@macro ruled_margin}
  this;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: context.rondaPalette.margen.withValues(
              alpha: PersonRow.marginLineOpacity,
            ),
          ),
        ),
      ),
      child: child,
    );
  }
}
