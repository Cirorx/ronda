part of 'notifications_cubit.dart';

/// Whether this phone lets Ronda notify, as Ajustes → Avisos shows it.
enum NotificationsStatus {
  /// Reading the permission.
  checking,

  /// Allowed.
  on,

  /// Not allowed, and the phone can still ask: [Prender los avisos].
  off,

  /// The system's prompt is open.
  asking,

  /// Asked just now, and still off: the phone said no, or a browser that
  /// refused before didn't ask at all.
  refused,

  /// Refused for good: only the phone's settings turn them on.
  blocked,

  /// The permission couldn't be read or asked.
  unknown,
}

final class const NotificationsState({
  final NotificationsStatus status = NotificationsStatus.checking,
}) extends Equatable {
  /// Whether [Prender los avisos] shows.
  bool get canTurnOn => switch (status) {
    NotificationsStatus.off ||
    NotificationsStatus.asking ||
    NotificationsStatus.refused ||
    NotificationsStatus.unknown => true,
    NotificationsStatus.checking ||
    NotificationsStatus.on ||
    NotificationsStatus.blocked => false,
  };

  @override
  List<Object> get props => [status];
}
