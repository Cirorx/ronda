/// {@template unreadable_voice_note_exception}
/// The `extract` callable couldn't read the voice note: not the WAV the app
/// records, too short or too long, or nothing was heard. The note is
/// already deleted.
/// {@endtemplate}
class UnreadableVoiceNoteException implements Exception {
  /// {@macro unreadable_voice_note_exception}
  const new();
}

/// {@template voice_note_refused_exception}
/// Storage refused the voice note: its rules said no (no terms yet, not the
/// owner, not a WAV, too big), or the project can't evaluate them. Trying
/// again won't help.
/// {@endtemplate}
class const VoiceNoteRefusedException(
  /// Storage's error code, such as `unauthorized`.
  final String code,
) implements Exception {
  /// {@macro voice_note_refused_exception}
  this;

  @override
  String toString() => 'VoiceNoteRefusedException($code)';
}

/// {@template voice_note_upload_exception}
/// The voice note upload failed for a reason other than the rules: no
/// connection, cancelled, or a Storage error. Trying again may work.
/// {@endtemplate}
class const VoiceNoteUploadException(
  /// Storage's error code, such as `retry-limit-exceeded`.
  final String code,
) implements Exception {
  /// {@macro voice_note_upload_exception}
  this;

  @override
  String toString() => 'VoiceNoteUploadException($code)';
}

/// {@template not_a_host_exception}
/// `make_mate_flyer` refused: the caller doesn't host that ronda (or, while
/// it has no hosts yet, isn't one of its members), or the photo isn't
/// theirs.
/// {@endtemplate}
class NotAHostException implements Exception {
  /// {@macro not_a_host_exception}
  const new();
}

/// {@template nothing_to_cut_out_exception}
/// `make_mate_flyer` found no termo, mazo or mate in the photo to cut out.
/// The photo is already deleted.
/// {@endtemplate}
class NothingToCutOutException implements Exception {
  /// {@macro nothing_to_cut_out_exception}
  const new();
}
