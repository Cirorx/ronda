/// {@template no_microphone_failure}
/// There is no microphone to record with: a computer without one, or one
/// that is unplugged.
/// {@endtemplate}
class NoMicrophoneFailure implements Exception {
  /// {@macro no_microphone_failure}
  const new();
}

/// {@template microphone_denied_failure}
/// The phone or the browser won't let Ronda use the microphone.
/// {@endtemplate}
class MicrophoneDeniedFailure implements Exception {
  /// {@macro microphone_denied_failure}
  const new();
}

/// {@template start_voice_note_failure}
/// The recorder couldn't start.
/// {@endtemplate}
class StartVoiceNoteFailure implements Exception {
  /// {@macro start_voice_note_failure}
  const new();
}

/// {@template record_voice_note_failure}
/// The recorder stopped without a note: it failed, or nothing reached it.
/// {@endtemplate}
class RecordVoiceNoteFailure implements Exception {
  /// {@macro record_voice_note_failure}
  const new();
}

/// {@template upload_voice_note_failure}
/// The note couldn't be sent. [refused] when Storage said no, which trying
/// again won't change; otherwise the connection or Storage failed and it
/// may work in a moment. [code] says what Storage answered, for the error
/// log.
/// {@endtemplate}
class const UploadVoiceNoteFailure({
  /// Whether Storage refused the note rather than failing to take it.
  final bool refused = false,

  /// What Storage answered, such as `unauthorized`, when it answered.
  final String? code,
}) implements Exception {
  /// {@macro upload_voice_note_failure}
  this;
}

/// {@template terms_not_accepted_failure}
/// `users/{uid}.terms` is missing, so the voice note stays on the phone and
/// is thrown away.
/// {@endtemplate}
class TermsNotAcceptedFailure implements Exception {
  /// {@macro terms_not_accepted_failure}
  const new();
}

/// {@template voice_note_not_understood_failure}
/// The note was read and nothing could be understood from it: too short,
/// silent, or too noisy. It is already deleted.
/// {@endtemplate}
class VoiceNoteNotUnderstoodFailure implements Exception {
  /// {@macro voice_note_not_understood_failure}
  const new();
}

/// {@template read_voice_note_failure}
/// The note was sent and reading it failed (the `extract` callable, or a
/// model behind it); recording again may work.
/// {@endtemplate}
class ReadVoiceNoteFailure implements Exception {
  /// {@macro read_voice_note_failure}
  const new();
}
