import 'package:equatable/equatable.dart';

/// {@template user}
/// The person signed in to Ronda, as the app sees them.
///
/// Only the Firebase uid: Ronda knows people by the first name they give in
/// onboarding, never by their Google profile, so no name, email or photo is
/// carried here. [User.empty] stands for "nobody is signed in".
/// {@endtemplate}
class const User({
  /// The Firebase Auth uid; also the id of the `users/{uid}` document.
  required final String id,
}) extends Equatable {
  /// {@macro user}
  this;

  /// Nobody is signed in.
  static const empty = User(id: '');

  /// Whether this is [User.empty].
  bool get isEmpty => this == empty;

  /// Whether someone is signed in.
  bool get isNotEmpty => !isEmpty;

  @override
  List<Object> get props => [id];
}
