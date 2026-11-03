part of 'auto_form_cubit.dart';

/// Whether the screen can show the switch.
enum AutoFormStatus {
  /// Reading `config/auto_form`.
  loading,

  /// Read: [AutoFormState.settings] holds it.
  ready,

  /// The read failed.
  failure,
}

final class const AutoFormState({
  final AutoFormStatus status = AutoFormStatus.loading,
  final AutoFormSettings? settings,

  /// What the admin typed in the minutes field; `null` while it shows the
  /// saved hold.
  final String? holdDraft,

  /// Whether a change is on its way to the server.
  final bool saving = false,

  /// Whether the last change failed.
  final bool saveFailed = false,
}) extends Equatable {
  /// The minutes the field shows: the typed ones, else the saved hold.
  String get holdText => holdDraft ?? '${settings?.holdMinutes ?? ''}';

  /// The typed minutes, when they are a hold the server takes (0 to a
  /// day); `null` otherwise.
  int? get draftMinutes => switch (int.tryParse(holdText.trim())) {
    final minutes?
        when minutes >= 0 && minutes <= AutoFormSettings.maxHoldMinutes =>
      minutes,
    _ => null,
  };

  AutoFormState copyWith({
    AutoFormStatus? status,
    AutoFormSettings? settings,
    String? holdDraft,
    bool clearDraft = false,
    bool? saving,
    bool? saveFailed,
  }) => AutoFormState(
    status: status ?? this.status,
    settings: settings ?? this.settings,
    holdDraft: clearDraft ? null : holdDraft ?? this.holdDraft,
    saving: saving ?? this.saving,
    saveFailed: saveFailed ?? this.saveFailed,
  );

  @override
  List<Object?> get props => [status, settings, holdDraft, saving, saveFailed];
}
