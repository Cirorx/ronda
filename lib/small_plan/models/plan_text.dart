import 'package:formz/formz.dart';

/// Why a [PlanText] is not valid.
enum PlanTextValidationError {
  /// Nothing but spaces.
  empty,

  /// Longer than [PlanText.maxLength].
  tooLong,
}

/// What a member types to say their own small plan: free words, a short
/// sentence. Leading and trailing spaces don't count.
class PlanText extends FormzInput<String, PlanTextValidationError> {
  /// An untouched field.
  const new pure([super.value = '']) : super.pure();

  /// A field the person typed in.
  const new dirty([super.value = '']) : super.dirty();

  /// The longest text sent: `functions/small_plans.py` reads the same
  /// number of characters.
  static const maxLength = 300;

  /// The words as they are sent: without leading or trailing spaces.
  String get words => value.trim();

  @override
  PlanTextValidationError? validator(String value) {
    final words = value.trim();
    if (words.isEmpty) return PlanTextValidationError.empty;
    if (words.length > maxLength) return PlanTextValidationError.tooLong;
    return null;
  }
}
