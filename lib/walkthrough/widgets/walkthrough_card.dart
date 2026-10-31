import 'package:ronda_ui/ronda_ui.dart';

/// {@template walkthrough_card}
/// One card of "¿Cómo funciona?": its picture, a heading and a short text.
///
/// It sits in the middle of the space it has while it fits, and scrolls
/// when it doesn't (large text). Large text drops the picture when it is
/// only decoration ([decorative]); the sample weekly card stays.
/// {@endtemplate}
class const WalkthroughCard({
  /// What the card shows above its heading.
  required final Widget art,

  /// The card's heading ("Los mismos 5 o 6, cada semana").
  required final String title,

  /// The text under the heading.
  required final String body,

  /// Whether [art] only decorates, so large text may drop it.
  final bool decorative = true,
  super.key,
}) extends StatelessWidget {
  /// {@macro walkthrough_card}
  this;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final showArt = !decorative || !context.usesLargeText;
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: EdgeInsetsDirectional.symmetric(
          horizontal: spacing.lg,
          vertical: spacing.md,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            minHeight: constraints.maxHeight - 2 * spacing.md,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: spacing.md,
            children: [
              if (showArt) ...[art, SizedBox(height: spacing.sm)],
              Semantics(
                header: true,
                child: Text(title, style: textTheme.headlineMedium),
              ),
              Text(body, style: textTheme.bodyLarge),
            ],
          ),
        ),
      ),
    );
  }
}
