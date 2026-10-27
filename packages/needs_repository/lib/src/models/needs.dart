import 'package:equatable/equatable.dart';
import 'package:needs_repository/src/models/need.dart';

/// {@template needs}
/// A member's needs. They live only on this phone and work as seat filters.
/// {@endtemplate}
class const Needs(
  /// The needs the member marked.
  final Set<Need> values,
) extends Equatable {
  /// {@macro needs}
  this;

  /// No needs: every seat is eligible.
  static const none = Needs({});

  @override
  List<Object?> get props => [values];
}
