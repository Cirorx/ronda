part of 'voice_note_cubit.dart';

/// Where the voice note stands.
enum VoiceNoteStatus {
  /// Asking for the microphone and starting the recorder.
  starting,

  /// Recording; [VoiceNoteState.elapsed] counts up to the limit.
  recording,

  /// "Terminé": uploading, transcribing and reading the fields.
  reading,

  /// Read; [VoiceNoteState.signup] holds what was understood.
  read,

  /// Read, and nothing came of it. The note is already deleted.
  notUnderstood,

  /// The phone or browser won't let Ronda use the microphone.
  microphoneDenied,

  /// Starting or reading failed; recording again may work.
  failure,
}

final class const VoiceNoteState({
  final VoiceNoteStatus status = VoiceNoteStatus.starting,

  /// How long the note has been recording.
  final Duration elapsed = Duration.zero,

  /// What the note said, once [VoiceNoteStatus.read].
  final VoiceSignup? signup,
}) extends Equatable {
  @override
  List<Object?> get props => [status, elapsed, signup];
}
