part of 'voice_note_cubit.dart';

/// Where the voice note stands.
enum VoiceNoteStatus {
  /// Waiting for the person to tap "Grabar". Nothing records on its own.
  ready,

  /// Asking for the microphone and starting the recorder.
  starting,

  /// Recording; [VoiceNoteState.elapsed] counts up to the limit and
  /// [VoiceNoteState.levels] follows the voice.
  recording,

  /// "Terminé": uploading, transcribing and reading the fields, step by
  /// step in [VoiceNoteState.stage].
  reading,

  /// Read; [VoiceNoteState.signup] holds what was understood.
  read,

  /// Read, and nothing came of it. The note is already deleted.
  notUnderstood,

  /// Something failed; [VoiceNoteState.failure] says what.
  failed,
}

/// Which step of reading the note is under way, in order.
enum VoiceNoteStage {
  /// The note is on its way to Storage.
  uploading,

  /// Voice Transcribe is turning it into words.
  listening,

  /// Spark 1.3 is reading the words into the answers.
  understanding,
}

/// What failed, so the screen can say it and the error log can count it.
enum VoiceNoteFailure {
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

  /// The note was sent and reading it failed.
  readFailed,
}

final class const VoiceNoteState({
  final VoiceNoteStatus status = VoiceNoteStatus.ready,

  /// How long the note has been recording.
  final Duration elapsed = Duration.zero,

  /// What the note said, once [VoiceNoteStatus.read].
  final VoiceSignup? signup,

  /// The step under way while [VoiceNoteStatus.reading].
  final VoiceNoteStage stage = VoiceNoteStage.uploading,

  /// The words Voice Transcribe heard, once they are back: shown while the
  /// answers are still being read.
  final String? transcript,

  /// How long the reading has taken so far, in whole seconds.
  final Duration waited = Duration.zero,

  /// The last [VoiceNoteCubit.waveformLength] levels heard, newest last,
  /// each from 0 (silence) to 1.
  final List<double> levels = const [],

  /// How many levels have been heard since recording started: the
  /// waveform scrolls one bar for each.
  final int heard = 0,

  /// Whether the microphone has heard nothing for
  /// [VoiceNoteCubit.silentAfter].
  final bool silent = false,

  /// What Voice Transcribe has heard so far, live, revised as the person
  /// talks. Empty without live transcription.
  final String words = '',

  /// What failed, once [VoiceNoteStatus.failed].
  final VoiceNoteFailure? failure,

  /// What the server answered when it failed, such as Storage's
  /// `unauthorized`, for the error log. Never shown.
  final String? failureCode,
}) extends Equatable {
  /// A copy with the given fields changed.
  VoiceNoteState copyWith({
    Duration? elapsed,
    List<double>? levels,
    int? heard,
    bool? silent,
    String? words,
    VoiceNoteStage? stage,
    String? transcript,
    Duration? waited,
  }) => VoiceNoteState(
    status: status,
    elapsed: elapsed ?? this.elapsed,
    signup: signup,
    stage: stage ?? this.stage,
    transcript: transcript ?? this.transcript,
    waited: waited ?? this.waited,
    levels: levels ?? this.levels,
    heard: heard ?? this.heard,
    silent: silent ?? this.silent,
    words: words ?? this.words,
    failure: failure,
    failureCode: failureCode,
  );

  @override
  List<Object?> get props => [
    status,
    elapsed,
    signup,
    stage,
    transcript,
    waited,
    levels,
    heard,
    silent,
    words,
    failure,
    failureCode,
  ];
}
