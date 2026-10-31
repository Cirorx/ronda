/// Why a voice line couldn't be written.
enum VoiceLineProblem {
  /// There is no microphone to record with.
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

  /// The note was read and nothing could be understood from it.
  notUnderstood,

  /// The note was sent and reading it failed.
  readFailed,
}

/// {@template voice_line_failure}
/// A voice line couldn't be written; [problem] says why. [code] is what the
/// server answered, such as Storage's `unauthorized`, for the error log.
/// {@endtemplate}
class const VoiceLineFailure(
  /// Why it failed.
  final VoiceLineProblem problem, {

  /// What the server answered, when it did.
  final String? code,
}) implements Exception {
  /// {@macro voice_line_failure}
  this;

  @override
  String toString() =>
      'VoiceLineFailure($problem${code == null ? '' : '/$code'})';
}

/// {@template nothing_to_draw_failure}
/// The week's lines hold nothing a postcard can show: only people,
/// feelings or numbers.
/// {@endtemplate}
class NothingToDrawFailure implements Exception {
  /// {@macro nothing_to_draw_failure}
  const new();
}

/// {@template make_postcard_failure}
/// The postcard couldn't be drawn; trying again in a moment may work.
/// {@endtemplate}
class MakePostcardFailure implements Exception {
  /// {@macro make_postcard_failure}
  const new();
}

/// {@template share_postcard_failure}
/// The share sheet didn't open.
/// {@endtemplate}
class SharePostcardFailure implements Exception {
  /// {@macro share_postcard_failure}
  const new();
}
