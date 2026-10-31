import 'package:ronda_ui/ronda_ui.dart';

/// {@template seat_count}
/// How full a ronda is, drawn as a row of dots on a [SeatRow].
/// {@endtemplate}
class const SeatCount({
  /// Seats taken, drawn as filled dots.
  required final int filled,

  /// All seats, the rest drawn as empty rings.
  required final int total,

  /// What a screen reader says for the dots ("4 de 6 anotados").
  required final String semanticsLabel,
}) {
  /// {@macro seat_count}
  this;
}

/// {@template seat_row}
/// A ronda with room in "Cerca tuyo": the pretext, how many seats are left,
/// where and when, an optional note and optional seat dots.
///
/// The whole card is one button, read as one item; its semantics identifier
/// is [identifier]. It shrinks on touch-down ([PressScale]), and a seat that
/// fills pops in on a spring ([SpringBuilder]).
/// {@endtemplate}
class const SeatRow({
  /// Semantics identifier of the card ("cerca.mate-solymar").
  required final String identifier,

  /// The pretext ("Mate en la rambla").
  required final String title,

  /// What is left ("Quedan 2 lugares"), in yerba.
  required final String availability,

  /// Where and when ("Solymar · jueves de tarde").
  required final String detail,

  /// Called when the person taps the card.
  required final VoidCallback onTap,

  /// An optional muted line under the detail.
  final String? note,

  /// Optional dots showing how full the ronda is.
  final SeatCount? seats,
  super.key,
}) extends StatelessWidget {
  /// {@macro seat_row}
  this;

  /// Diameter of one seat dot.
  static const double dotSize = 14;

  /// How big a seat's fill starts, as a share of the dot, when it is taken:
  /// it grows and fades in from here.
  static const double fillStartScale = 0.6;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textTheme = theme.textTheme;
    final spacing = context.appSpacing;
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        button: true,
        child: PressScale(
          child: Card(
            child: InkWell(
              onTap: onTap,
              hoverDuration: AppMotion.hover,
              child: Padding(
                padding: EdgeInsets.all(spacing.md),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: spacing.xxs,
                  children: [
                    Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.end,
                      spacing: spacing.xs,
                      children: [
                        Text(title, style: textTheme.titleMedium),
                        Text(
                          availability,
                          style: textTheme.labelMedium?.copyWith(
                            color: context.rondaPalette.yerba,
                          ),
                        ),
                      ],
                    ),
                    Text(detail, style: textTheme.bodyMedium),
                    if (note case final note?)
                      Text(
                        note,
                        style: textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    if (seats case final seats?)
                      Padding(
                        padding: EdgeInsets.only(top: spacing.xxs),
                        child: _SeatDots(seats: seats),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class const _SeatDots({required final SeatCount seats})
    extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final controlOff = context.rondaPalette.controlOff;
    return Semantics(
      label: seats.semanticsLabel,
      child: ExcludeSemantics(
        child: Wrap(
          spacing: context.appSpacing.xs,
          runSpacing: context.appSpacing.xs,
          children: [
            for (var seat = 0; seat < seats.total; seat++)
              SizedBox.square(
                dimension: SeatRow.dotSize,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: controlOff,
                          width: AppTheme.borderWidth,
                        ),
                      ),
                    ),
                    // The fill grows over the ring when the seat is taken,
                    // from most of its size and clear, never from nothing.
                    SpringBuilder(
                      value: seat < seats.filled ? 1 : 0,
                      builder: (context, value, child) => Opacity(
                        opacity: value.clamp(0.0, 1.0),
                        child: Transform.scale(
                          scale:
                              SeatRow.fillStartScale +
                              (1 - SeatRow.fillStartScale) *
                                  value.clamp(0.0, double.infinity),
                          child: child,
                        ),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
