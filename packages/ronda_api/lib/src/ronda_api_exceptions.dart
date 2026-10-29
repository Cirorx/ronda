/// {@template unreadable_voice_note_exception}
/// The `extract` callable couldn't read the voice note: not the WAV the app
/// records, too short or too long, or nothing was heard. The note is
/// already deleted.
/// {@endtemplate}
class UnreadableVoiceNoteException implements Exception {
  /// {@macro unreadable_voice_note_exception}
  const new();
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
