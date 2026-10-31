import 'package:ronda_ui/ronda_ui.dart';

/// {@template walkthrough_art}
/// A card's picture: a row of things in birome on its tint, never people.
/// Each is a [RondaObjectIcon] or a line icon. Screen readers skip it; the
/// card's words say the same.
/// {@endtemplate}
class const WalkthroughArt({
  /// What the row shows, start to end.
  required final List<Widget> children,
  super.key,
}) extends StatelessWidget {
  /// {@macro walkthrough_art}
  this;

  /// The ronda's own things: a mate, a deck of cards and a ball.
  factory objects({Key? key}) => WalkthroughArt(
    key: key,
    children: const [
      RondaObjectIcon(RondaObject.mate),
      RondaObjectIcon(RondaObject.mazo),
      RondaObjectIcon(RondaObject.pelota),
    ],
  );

  /// What the program looks after: rain, who opens, a freed seat.
  factory logistics({Key? key}) => WalkthroughArt(
    key: key,
    children: const [
      Icon(Icons.umbrella_outlined),
      Icon(Icons.key_outlined),
      Icon(Icons.event_seat_outlined),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appSpacing;
    // Each thing sits in a circle two and a half large spacings wide, so
    // three fit a 320 wide phone.
    final circle = spacing.xlg * 2.5;
    return ExcludeSemantics(
      child: IconTheme(
        data: IconThemeData(color: scheme.primary, size: spacing.xlg * 1.25),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          spacing: spacing.md,
          children: [
            for (final child in children)
              Container(
                width: circle,
                height: circle,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.rondaPalette.biromeTint,
                  shape: BoxShape.circle,
                ),
                child: child,
              ),
          ],
        ),
      ),
    );
  }
}
