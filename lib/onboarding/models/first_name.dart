import 'package:formz/formz.dart';

/// Why a [FirstName] is not valid.
enum FirstNameValidationError {
  /// Nothing but spaces.
  empty,

  /// Longer than [FirstName.maxLength].
  tooLong,

  /// Holds something other than letters, spaces, hyphens or apostrophes.
  invalid,
}

/// The first name people will know the member by, as typed in onboarding.
///
/// Letters in any script (ñ and accents included), with spaces, hyphens and
/// apostrophes inside ("María José", "D'Angelo"). Leading and trailing
/// spaces don't count; [name] is the value without them.
class FirstName extends FormzInput<String, FirstNameValidationError> {
  /// An untouched field.
  const new pure([super.value = '']) : super.pure();

  /// A field the person typed in.
  const new dirty([super.value = '']) : super.dirty();

  /// The longest name accepted; `firestore.rules` holds the same limit.
  static const maxLength = 30;

  static final _pattern = RegExp(r"^\p{L}[\p{L}\p{M}' -]*$", unicode: true);

  /// The name as it is saved: without leading or trailing spaces.
  String get name => value.trim();

  @override
  FirstNameValidationError? validator(String value) {
    final name = value.trim();
    if (name.isEmpty) return FirstNameValidationError.empty;
    if (name.length > maxLength) return FirstNameValidationError.tooLong;
    if (!_pattern.hasMatch(name)) return FirstNameValidationError.invalid;
    return null;
  }
}
