part of 'push_cubit.dart';

/// Where the notifications ask stands.
enum PushStatus {
  /// Reading whether notifications are allowed.
  checking,

  /// Not allowed yet and the phone can still ask: the card shows.
  offered,

  /// The system's prompt is open.
  requesting,

  /// Allowed: this phone's token is saved, and kept fresh.
  allowed,

  /// The phone refused without asking: the card says how to turn them on.
  blocked,

  /// "Ahora no", a "no" in the system's prompt, or refused for good before
  /// the card ever showed: nothing to show until the next launch.
  dismissed,
}

final class const PushState({final PushStatus status = PushStatus.checking})
    extends Equatable {
  /// Whether the card shows.
  bool get showsPrompt => switch (status) {
    PushStatus.offered || PushStatus.requesting || PushStatus.blocked => true,
    PushStatus.checking || PushStatus.allowed || PushStatus.dismissed => false,
  };

  @override
  List<Object> get props => [status];
}
