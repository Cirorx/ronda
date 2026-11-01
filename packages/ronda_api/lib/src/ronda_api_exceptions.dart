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

/// {@template nothing_to_draw_exception}
/// `make_postcard` found nothing in the lines a postcard can show: only
/// people, feelings or numbers.
/// {@endtemplate}
class NothingToDrawException implements Exception {
  /// {@macro nothing_to_draw_exception}
  const new();
}

/// {@template donde_queda_refused_exception}
/// `post_donde_queda` refused the photo or its words, and says why:
/// `houseNumber`, `person`, `empty` or `words`. The upload is already
/// deleted.
/// {@endtemplate}
class const DondeQuedaRefusedException(
  /// Why: `houseNumber`, `person`, `empty` or `words`.
  final String reason,
) implements Exception {
  /// {@macro donde_queda_refused_exception}
  this;

  @override
  String toString() => 'DondeQuedaRefusedException($reason)';
}

/// {@template not_your_turn_exception}
/// A ¿Dónde queda? call came too late or from the wrong person: the turn
/// passed on, the game closed, or the photo is the caller's own.
/// {@endtemplate}
class NotYourTurnException implements Exception {
  /// {@macro not_your_turn_exception}
  const new();
}

/// {@template already_guessed_exception}
/// The member already dropped their one pin on this week's photo.
/// {@endtemplate}
class AlreadyGuessedException implements Exception {
  /// {@macro already_guessed_exception}
  const new();
}

/// {@template shared_plan_held_exception}
/// A plan was not opened to the ronda: [reason] says why, in the words of
/// `functions/shared_plans.py`: `past`, `time`, `words`, `money`, `address`,
/// `phone`, `place` or `other`. The plan stays private.
/// {@endtemplate}
class const SharedPlanHeldException(
  /// Why it was held.
  final String reason,
) implements Exception {
  /// {@macro shared_plan_held_exception}
  this;

  @override
  String toString() => 'SharedPlanHeldException($reason)';
}

/// {@template shared_plan_gone_exception}
/// A plan someone tried to join is over or was withdrawn.
/// {@endtemplate}
class SharedPlanGoneException implements Exception {
  /// {@macro shared_plan_gone_exception}
  const new();
}
