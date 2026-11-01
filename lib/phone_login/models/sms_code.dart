import 'package:formz/formz.dart';

/// Why an [SmsCode] is not valid.
enum SmsCodeValidationError {
  /// Not six digits.
  invalid,
}

/// The code field: the six digits Firebase Auth sends by SMS. Spaces don't
/// count, so a code pasted as "123 456" is read.
class SmsCode extends FormzInput<String, SmsCodeValidationError> {
  /// An untouched field.
  const new pure([super.value = '']) : super.pure();

  /// A field the person typed in.
  const new dirty([super.value = '']) : super.dirty();

  /// How many digits the code has.
  static const length = 6;

  static final _digits = RegExp(r'^\d{6}$');

  /// The code as it is checked: without spaces.
  String get digits => value.replaceAll(RegExp(r'\s'), '');

  @override
  SmsCodeValidationError? validator(String value) =>
      _digits.hasMatch(value.replaceAll(RegExp(r'\s'), ''))
      ? null
      : SmsCodeValidationError.invalid;
}
