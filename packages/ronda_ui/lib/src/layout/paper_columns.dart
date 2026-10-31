import 'package:ronda_ui/ronda_ui.dart';

/// {@template paper_columns}
/// A wide screen's two columns: the [main] one at a readable width, behind
/// the ruled margin, and beside it the [side] one with context (who is
/// going, the trace of a run, who was left out). Both are centred on the
/// paper together and each takes the full height, so each scrolls on its
/// own.
///
/// Keyboard focus goes through [main] before [side], whatever their
/// content, as a reader's eye does. Screens use it on
/// [WindowSize.expanded] only; narrower windows keep one column.
/// {@endtemplate}
class const PaperColumns({
  /// The screen's own content: the card, the proposal, the form.
  required final Widget main,

  /// The context beside it.
  required final Widget side,

  /// The widest [main] gets.
  final double mainWidth = WindowSize.readableWidth,

  /// How wide [side] is.
  final double sideWidth = WindowSize.sideWidth,
  super.key,
}) extends StatelessWidget {
  /// {@macro paper_columns}
  this;

  @override
  Widget build(BuildContext context) {
    final gap = context.appSpacing.xlg;
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: mainWidth + gap + sideWidth),
        child: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: gap,
            children: [
              Expanded(
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(0),
                  child: FocusTraversalGroup(child: RuledMargin(child: main)),
                ),
              ),
              SizedBox(
                width: sideWidth,
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: FocusTraversalGroup(child: side),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
