import 'package:auth_repository/auth_repository.dart';
import 'package:formz/formz.dart';

/// The mobile number field: `+598 ` until the person types, valid when
/// [PhoneNumber.tryParse] reads it.
class PhoneNumberInput extends FormzInput<String, PhoneNumberError> {
  /// An untouched field, with Uruguay's code filled in.
  const new pure([super.value = '${PhoneNumber.uruguayPrefix} '])
    : super.pure();

  /// A field the person typed in.
  const new dirty([super.value = '']) : super.dirty();

  /// The number to send the code to, or null while it is not valid.
  PhoneNumber? get phoneNumber => PhoneNumber.tryParse(value);

  @override
  PhoneNumberError? validator(String value) => PhoneNumber.validate(value);
}
