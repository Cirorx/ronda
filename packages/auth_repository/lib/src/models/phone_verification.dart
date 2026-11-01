import 'package:auth_repository/auth_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart' as firebase_auth;

/// {@template phone_verification}
/// A code sent by SMS and waiting to be typed: what
/// `AuthRepository.confirmPhoneCode` checks it against, and when another
/// code may be asked for.
///
/// `AuthRepository.sendPhoneCode` makes it; the screen holds it in memory
/// and passes it back. Its [toString] hides the number.
/// {@endtemplate}
final class PhoneVerification extends Equatable {
  /// {@macro phone_verification}
  const new({
    required this.phoneNumber,
    required this.sentAt,
    this.sends = 1,
    this.verificationId,
    this.resendToken,
    this.confirmation,
  });

  /// Who the code went to.
  final PhoneNumber phoneNumber;

  /// When the latest code went out.
  final DateTime sentAt;

  /// How many codes went out to [phoneNumber] on this screen, this one
  /// included.
  final int sends;

  /// Phones: what Firebase Auth checks the typed code against.
  final String? verificationId;

  /// Android: lets a resend skip the app check it already passed.
  final int? resendToken;

  /// Web: the pending sign-in that takes the typed code.
  final firebase_auth.ConfirmationResult? confirmation;

  /// How long to wait after the first, second and third code before asking
  /// for another; after the fourth there are no more on this screen. SMS
  /// bills per message, and Firebase Auth blocks a number that asks too
  /// often.
  static const resendCooldowns = [
    Duration(seconds: 30),
    Duration(seconds: 60),
    Duration(seconds: 120),
  ];

  /// When another code may be asked for, or null when no more may be.
  DateTime? get resendAvailableAt => sends > resendCooldowns.length
      ? null
      : sentAt.add(resendCooldowns[sends - 1]);

  @override
  List<Object?> get props => [
    phoneNumber,
    sentAt,
    sends,
    verificationId,
    resendToken,
    confirmation,
  ];

  /// Hides the number, so a log or an error report never carries it.
  @override
  String toString() => 'PhoneVerification(sends: $sends)';
}
