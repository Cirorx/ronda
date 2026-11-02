import 'package:auth_repository/auth_repository.dart';
import 'package:equatable/equatable.dart';

/// How someone signs in to Ronda.
enum SignInMethod {
  /// With a Google account.
  google,

  /// With a code sent by SMS to a mobile number.
  phone,
}

/// {@template sign_in_account}
/// The account the signed-in person enters with: Google and its email, or a
/// mobile number.
///
/// It is shown only to that person, on their own phone (Ajustes). Ronda
/// never writes it to Firestore, the phone's storage or a log, so
/// [toString] hides [address].
/// {@endtemplate}
class const SignInAccount({
  /// Google or a phone number.
  required final SignInMethod method,

  /// The Google account's email, or the number in E.164; null when Firebase
  /// Auth didn't keep one.
  final String? address,
}) extends Equatable {
  /// {@macro sign_in_account}
  this;

  /// [address] as the screen shows it: a Uruguayan mobile as
  /// `+598 9X XXX XXX`, anything else as kept.
  String? get displayAddress => switch (method) {
    SignInMethod.phone when address != null =>
      PhoneNumber.tryParse(address!)?.display ?? address,
    _ => address,
  };

  @override
  List<Object?> get props => [method, address];

  /// Hides the email or the number, so a log or an error report never
  /// carries it.
  @override
  String toString() => 'SignInAccount($method)';
}
