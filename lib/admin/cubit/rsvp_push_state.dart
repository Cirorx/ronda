part of 'rsvp_push_cubit.dart';

/// Where "Mandarlo ahora" stands.
enum RsvpPushStatus { idle, sending, sent, failed }

final class const RsvpPushState({
  final RsvpPushStatus status = RsvpPushStatus.idle,

  /// What the last send did, once [status] is [RsvpPushStatus.sent].
  final RsvpPushResult? result,
}) extends Equatable {
  @override
  List<Object?> get props => [status, result];
}
