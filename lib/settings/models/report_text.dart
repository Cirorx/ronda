import 'package:formz/formz.dart';

/// Why a [ReportText] is not valid.
enum ReportTextValidationError {
  /// Longer than [ReportText.maxLength].
  tooLong,
}

/// What a member types in "Contar algo que pasó", or adds to it later. It
/// may be empty when a tag says enough; leading and trailing spaces don't
/// count.
class ReportText extends FormzInput<String, ReportTextValidationError> {
  /// An untouched field.
  const new pure([super.value = '']) : super.pure();

  /// A field the person typed in.
  const new dirty([super.value = '']) : super.dirty();

  /// The longest text sent: `functions/reports.py` takes the same number of
  /// characters.
  static const maxLength = 2000;

  /// The words as they are sent: without leading or trailing spaces.
  String get words => value.trim();

  @override
  ReportTextValidationError? validator(String value) =>
      value.trim().length > maxLength
      ? ReportTextValidationError.tooLong
      : null;
}
