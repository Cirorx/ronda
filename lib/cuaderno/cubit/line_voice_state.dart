part of 'line_voice_cubit.dart';

/// Where the voice line stands.
enum LineVoiceStatus {
  /// Waiting for "Decilo con la voz". Nothing records on its own.
  ready,

  /// Asking for the microphone and starting the recorder.
  starting,

  /// Recording; [LineVoiceState.elapsed] counts up to the limit.
  recording,

  /// Uploading and transcribing.
  reading,

  /// Read; [LineVoiceState.text] holds what was said.
  read,

  /// Something failed; [LineVoiceState.problem] says what.
  failed,
}

final class const LineVoiceState({
  final LineVoiceStatus status = LineVoiceStatus.ready,
  final Duration elapsed = Duration.zero,

  /// The last [LineVoiceCubit.waveformLength] levels, newest last.
  final List<double> levels = const [],

  /// How many levels have been heard: the waveform scrolls one bar each.
  final int heard = 0,

  /// What Voice Transcribe has heard so far, live, revised as the person
  /// talks. Empty without live transcription.
  final String words = '',

  /// What was said, once [LineVoiceStatus.read].
  final String? text,

  /// Why it failed, once [LineVoiceStatus.failed].
  final VoiceLineProblem? problem,

  /// What the server answered when it failed, for the error log. Never
  /// shown.
  final String? problemCode,
}) extends Equatable {
  LineVoiceState copyWith({
    Duration? elapsed,
    List<double>? levels,
    int? heard,
    String? words,
  }) => LineVoiceState(
    status: status,
    elapsed: elapsed ?? this.elapsed,
    levels: levels ?? this.levels,
    heard: heard ?? this.heard,
    words: words ?? this.words,
  );

  @override
  List<Object?> get props => [
    status,
    elapsed,
    levels,
    heard,
    text,
    problem,
    problemCode,
  ];
}
