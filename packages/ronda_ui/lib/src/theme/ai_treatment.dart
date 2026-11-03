import 'package:ronda_ui/ronda_ui.dart';

/// {@template ai_treatment}
/// The signature treatment for surfaces the organiser agent composed (the
/// weekly card, Algo chico's suggestions, the postcard, the flyer,
/// auto-formed proposals): the virola thread, a yerba → ochre → silver
/// gradient line drawn along the top of the card with a quiet label chip.
///
/// Only agent-composed surfaces use it. Anything else that draws a gradient
/// is decoration, not the agent's work.
/// {@endtemplate}
class AiTreatment extends ThemeExtension<AiTreatment> {
  /// {@macro ai_treatment}
  const new({required this.gradient, required this.accent, required this.wash});

  /// The virola thread: yerba → ochre → silver by day, its night values
  /// after dark.
  static const light = AiTreatment(
    gradient: [Color(0xFFB9C48A), Color(0xFFD9A441), Color(0xFFC9C2B8)],
    accent: Color(0xFF8F5E0B),
    wash: Color(0xFFFAF0DA),
  );

  /// The virola thread at night.
  static const dark = AiTreatment(
    gradient: [Color(0xFFC2D191), Color(0xFFEBC078), Color(0xFFD8D2C8)],
    accent: Color(0xFFEBC078),
    wash: Color(0xFF3D2E14),
  );

  /// The thread drawn at the top of an agent-composed card.
  final List<Color> gradient;

  /// The dot / label colour naming the agent's work.
  final Color accent;

  /// A faint wash behind the agent's label.
  final Color wash;

  @override
  AiTreatment copyWith({List<Color>? gradient, Color? accent, Color? wash}) =>
      AiTreatment(
        gradient: gradient ?? this.gradient,
        accent: accent ?? this.accent,
        wash: wash ?? this.wash,
      );

  @override
  AiTreatment lerp(AiTreatment? other, double t) {
    if (other is! AiTreatment) return this;
    return AiTreatment(
      gradient: [
        for (var i = 0; i < gradient.length; i++)
          Color.lerp(gradient[i], other.gradient[i], t)!,
      ],
      accent: Color.lerp(accent, other.accent, t)!,
      wash: Color.lerp(wash, other.wash, t)!,
    );
  }
}

/// Reads the [AiTreatment] of the active theme.
extension AiTreatmentContext on BuildContext {
  /// The theme's AI treatment.
  AiTreatment get aiTreatment => Theme.of(this).extension<AiTreatment>()!;
}
