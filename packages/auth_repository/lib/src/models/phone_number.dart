import 'package:equatable/equatable.dart';

/// Why a typed number is not a [PhoneNumber].
enum PhoneNumberError {
  /// Nothing typed, or only the country code.
  empty,

  /// A Uruguayan number that is not a mobile one (a landline), so no SMS
  /// reaches it.
  notMobile,

  /// Not a phone number: wrong length, letters, a lone `+`.
  invalid,
}

/// {@template phone_number}
/// A mobile number to send the sign-in code to, in E.164 (`+598…`).
///
/// It exists only between the screen and Firebase Auth: Ronda never writes
/// it to Firestore, the phone's storage or a log, so [toString] hides it.
/// {@endtemplate}
final class PhoneNumber extends Equatable {
  const new _(this.e164);

  /// Uruguay's country code, filled in before the person types.
  static const uruguayPrefix = '+598';

  /// Uruguayan mobiles: 9 and seven more digits after the country code
  /// (`09X XXX XXX` at home).
  static final _uruguayMobile = RegExp(r'^9\d{7}$');

  /// Uruguayan landlines: 2 or 4 and seven more digits.
  static final _uruguayLandline = RegExp(r'^[24]\d{7}$');

  /// Any other country, as typed: a `+`, then 7 to 15 digits.
  static final _international = RegExp(r'^\+[1-9]\d{6,14}$');

  /// Spaces and the marks people type between digits.
  static final _separators = RegExp(r'[\s\-.()]');

  /// The number as Firebase Auth takes it.
  final String e164;

  /// Reads what the person typed: with or without `+598`, with or without
  /// the leading 0 (`099…`), spaces and dashes anywhere. Another country's
  /// number must start with `+`.
  ///
  /// Returns null when [validate] has an error for [input].
  static PhoneNumber? tryParse(String input) => _parse(input).$1;

  /// Why [input] is not a phone number, or null when it is one.
  static PhoneNumberError? validate(String input) => _parse(input).$2;

  static (PhoneNumber?, PhoneNumberError?) _parse(String input) {
    final typed = input.replaceAll(_separators, '');
    if (typed.isEmpty || typed == uruguayPrefix) {
      return (null, PhoneNumberError.empty);
    }
    final national = switch (typed) {
      _ when typed.startsWith(uruguayPrefix) => typed.substring(
        uruguayPrefix.length,
      ),
      _ when typed.startsWith('+') => null,
      _ => typed,
    };
    if (national == null) {
      return _international.hasMatch(typed)
          ? (PhoneNumber._(typed), null)
          : (null, PhoneNumberError.invalid);
    }
    final digits = national.startsWith('0') ? national.substring(1) : national;
    if (_uruguayMobile.hasMatch(digits)) {
      return (PhoneNumber._('$uruguayPrefix$digits'), null);
    }
    if (_uruguayLandline.hasMatch(digits)) {
      return (null, PhoneNumberError.notMobile);
    }
    return (null, PhoneNumberError.invalid);
  }

  /// The number as the screen shows it back: `+598 9X XXX XXX` for a
  /// Uruguayan mobile, [e164] for any other.
  String get display {
    if (!e164.startsWith(uruguayPrefix)) return e164;
    final digits = e164.substring(uruguayPrefix.length);
    return '$uruguayPrefix ${digits.substring(0, 2)} '
        '${digits.substring(2, 5)} ${digits.substring(5)}';
  }

  @override
  List<Object> get props => [e164];

  /// Hides the number, so a log or an error report never carries it.
  @override
  String toString() => 'PhoneNumber(hidden)';
}
