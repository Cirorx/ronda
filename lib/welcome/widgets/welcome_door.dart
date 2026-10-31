import 'package:ronda_ui/ronda_ui.dart';

/// {@template welcome_door}
/// One way into Ronda on the welcome screen: an icon, what the door is and
/// what it takes. The whole card is one button, pressed in from touch-down;
/// its semantics identifier is [identifier].
/// {@endtemplate}
class const WelcomeDoor({
  /// Maestro's handle on the door ("welcome.buttons").
  required final String identifier,

  /// The door's icon.
  required final IconData icon,

  /// What the door is ("Tocando botones").
  required final String title,

  /// What it takes ("Siete preguntas cortas.").
  required final String subtitle,

  /// Called when the person taps the door.
  required final VoidCallback onTap,
  super.key,
}) extends StatelessWidget {
  /// {@macro welcome_door}
  this;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final spacing = context.appSpacing;
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: PressScale(
          child: Card(
            child: ListTile(
              onTap: onTap,
              contentPadding: EdgeInsetsDirectional.symmetric(
                horizontal: spacing.md,
                vertical: spacing.xs,
              ),
              leading: ExcludeSemantics(
                child: CircleAvatar(
                  backgroundColor: context.rondaPalette.biromeTint,
                  foregroundColor: scheme.primary,
                  child: Icon(icon),
                ),
              ),
              title: Text(title),
              subtitle: Text(subtitle),
            ),
          ),
        ),
      ),
    );
  }
}
