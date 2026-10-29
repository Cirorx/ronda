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
/// Stopping, uploading or reading the note failed; recording again may work.
/// {@endtemplate}
class ReadVoiceNoteFailure implements Exception {
  /// {@macro read_voice_note_failure}
  const new();
}
