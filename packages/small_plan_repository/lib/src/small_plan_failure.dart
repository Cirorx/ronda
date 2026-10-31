/// What went wrong, so the screen can say it and the error log can count it.
enum SmallPlanFailureKind {
  /// The phone or computer has no microphone to use.
  noMicrophone,

  /// The phone or browser won't let Ronda use the microphone.
  microphoneDenied,

  /// The recorder didn't start, or stopped without a note.
  recorderFailed,

  /// `users/{uid}.terms` is missing, so nothing was sent.
  termsMissing,

  /// Storage refused the note; trying again won't change that.
  uploadRefused,

  /// The note couldn't be sent: the connection or Storage failed.
  uploadFailed,

  /// There was nothing to read in what was said or typed.
  notUnderstood,

  /// The words were sent and reading them failed.
  readFailed,

  /// The suggestions couldn't be had.
  suggestFailed,

  /// The calendar couldn't be opened, or the file couldn't be saved.
  calendarUnavailable,

  /// The phone couldn't keep or read the plan.
  storageFailed,
}

/// {@template small_plan_failure}
/// A step of Algo chico failed: [kind] says which. [code] is what Storage
/// answered when the upload failed, for the error log; never shown.
/// {@endtemplate}
class const SmallPlanFailure(
  final SmallPlanFailureKind kind, {
  final String? code,
}) implements Exception {
  /// {@macro small_plan_failure}
  this;

  @override
  String toString() => 'SmallPlanFailure(${kind.name})';
}
