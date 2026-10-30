import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:push_repository/push_repository.dart';

part 'notifications_state.dart';

/// Ajustes → Avisos: whether notifications are on, and a way to turn them
/// back on after "Ahora no" or a "no" in the system's prompt.
///
/// Turning them on forgets "Ahora no", so Mi ronda's card may ask again on
/// the next launch, and asks the phone again. Once allowed here, it saves
/// this phone's token for [_uid]; Mi ronda keeps it fresh from the next
/// launch on. A phone that refused for good is told how to allow them in
/// its settings. Failures are reported to the observer, never shown.
class NotificationsCubit extends Cubit<NotificationsState> {
  new({required this._uid, required this._pushRepository})
    : super(const NotificationsState());

  final String _uid;
  final PushRepository _pushRepository;

  /// Reads whether notifications are allowed, without asking. Called when
  /// the screen opens and when the app comes back from the phone's
  /// settings; if they were turned on there, the token is saved.
  Future<void> started() async {
    final previous = state.status;
    // The system's prompt pauses the app; its answer arrives on its own.
    if (previous == NotificationsStatus.asking) return;
    final PushPermission permission;
    try {
      permission = await _pushRepository.permission();
    } on PushPermissionFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(const NotificationsState(status: NotificationsStatus.unknown));
      }
      return;
    }
    if (isClosed) return;
    switch (permission) {
      case PushPermission.allowed:
        emit(const NotificationsState(status: NotificationsStatus.on));
        final wasOff =
            previous != NotificationsStatus.checking &&
            previous != NotificationsStatus.on;
        if (wasOff) await _register();
      // The prompt's pause can resume the app after its answer: a "no" just
      // given keeps its hint.
      case PushPermission.notAsked || PushPermission.refused
          when previous == NotificationsStatus.refused:
        break;
      case PushPermission.notAsked || PushPermission.refused:
        emit(const NotificationsState(status: NotificationsStatus.off));
      case PushPermission.blocked:
        emit(const NotificationsState(status: NotificationsStatus.blocked));
    }
  }

  /// "Prender los avisos": forgets "Ahora no", then the system's prompt,
  /// then the token when allowed.
  Future<void> turnOnTapped() async {
    emit(const NotificationsState(status: NotificationsStatus.asking));
    try {
      await _pushRepository.clearPromptSnooze();
    } on SnoozePromptFailure catch (error, stackTrace) {
      addError(error, stackTrace);
    }
    final PushPermission permission;
    try {
      permission = await _pushRepository.askPermission();
    } on PushPermissionFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(const NotificationsState(status: NotificationsStatus.unknown));
      }
      return;
    }
    if (isClosed) return;
    switch (permission) {
      case PushPermission.allowed:
        emit(const NotificationsState(status: NotificationsStatus.on));
        await _register();
      case PushPermission.blocked:
        emit(const NotificationsState(status: NotificationsStatus.blocked));
      case PushPermission.notAsked || PushPermission.refused:
        emit(const NotificationsState(status: NotificationsStatus.refused));
    }
  }

  Future<void> _register() async {
    try {
      await _pushRepository.registerDevice(_uid);
    } on RegisterDeviceFailure catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }
}
