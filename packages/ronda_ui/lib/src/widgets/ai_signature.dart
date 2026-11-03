import 'package:ronda_ui/ronda_ui.dart';

/// {@template ai_signature}
/// The signature treatment on a surface the organiser agent composed: the
/// virola thread ([AiTreatment.gradient]) along the top, with a quiet label
/// chip naming the agent's work.
///
/// Every agent-composed surface wraps its card in it unconditionally; the
/// treatment comes from the theme, so call sites name no colours.
/// {@endtemplate}
class const AiSignature({
  /// Optional label naming the agent's work, in the caller's language;
  /// when null only the thread is drawn.
  final String? label,
  super.key,
}) extends StatelessWidget {
  /// {@macro ai_signature}
  this;

  @override
  Widget build(BuildContext context) {
    final ai = context.aiTreatment;
    final textTheme = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: context.appSpacing.xs,
      children: [
        Container(
          height: 3,
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: ai.gradient),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        if (label case final labelText?)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: ai.wash,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 6,
              children: [
                Container(
                  width: 7,
                  height: 7,
                  decoration: BoxDecoration(
                    color: ai.accent,
                    shape: BoxShape.circle,
                  ),
                ),
                Text(
                  labelText,
                  style: textTheme.labelSmall?.copyWith(color: ai.accent),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
