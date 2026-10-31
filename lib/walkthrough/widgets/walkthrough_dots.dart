import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// {@template walkthrough_dots}
/// Which card of [count] is open: one dot each, the open one longer and in
/// birome, so colour isn't the only sign. A screen reader hears
/// "Tarjeta 2 de 3".
/// {@endtemplate}
class const WalkthroughDots({
  /// The open card, from 0.
  required final int index,

  /// How many cards there are.
  required final int count,
  super.key,
}) extends StatelessWidget {
  /// {@macro walkthrough_dots}
  this;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appSpacing;
    final duration = RondaMotion.of(context)
        .durationOr(AppMotion.standardDuration);
    return Semantics(
      label: context.l10n.walkthroughProgressSemantics(index + 1, count),
      excludeSemantics: true,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        spacing: spacing.xs,
        children: [
          for (var dot = 0; dot < count; dot++)
            AnimatedContainer(
              duration: duration,
              curve: AppMotion.standardCurve,
              width: dot == index ? spacing.lg : spacing.xs,
              height: spacing.xs,
              decoration: BoxDecoration(
                color: dot == index ? scheme.primary : scheme.outlineVariant,
                borderRadius: BorderRadius.circular(spacing.xxs),
              ),
            ),
        ],
      ),
    );
  }
}
