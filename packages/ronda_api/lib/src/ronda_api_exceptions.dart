/// {@template unreadable_voice_note_exception}
/// The `extract` callable couldn't read the voice note: not the WAV the app
/// records, too short or too long, or nothing was heard. The note is
/// already deleted.
/// {@endtemplate}
class UnreadableVoiceNoteException implements Exception {
  /// {@macro unreadable_voice_note_exception}
  const new();
}
