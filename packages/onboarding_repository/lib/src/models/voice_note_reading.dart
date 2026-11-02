import 'package:equatable/equatable.dart';
import 'package:onboarding_repository/src/models/voice_signup.dart';

/// How far reading a voice note has got, step by step, as
/// `OnboardingRepository.readVoiceNote` goes through them.
///
/// Live transcription while recording (#64) would add words before
/// [VoiceNoteHeard]; the steps after it stay the same.
sealed class VoiceNoteReading extends Equatable {
  /// A step.
  const new();

  @override
  List<Object?> get props => [];
}

/// {@template voice_note_uploading}
/// The note is on its way to Storage.
/// {@endtemplate}
final class const VoiceNoteUploading() extends VoiceNoteReading {
  /// {@macro voice_note_uploading}
  this;
}

/// {@template voice_note_listening}
/// Voice Transcribe is listening to it.
/// {@endtemplate}
final class const VoiceNoteListening() extends VoiceNoteReading {
  /// {@macro voice_note_listening}
  this;
}

/// {@template voice_note_heard}
/// Voice Transcribe heard [transcript], and the note is already deleted;
/// Spark 1.3 is reading the words into fields.
/// {@endtemplate}
final class const VoiceNoteHeard(final String transcript)
    extends VoiceNoteReading {
  /// {@macro voice_note_heard}
  this;

  @override
  List<Object?> get props => [transcript];
}

/// {@template voice_note_understood}
/// Done: [signup] is what the words said.
/// {@endtemplate}
final class const VoiceNoteUnderstood(final VoiceSignup signup)
    extends VoiceNoteReading {
  /// {@macro voice_note_understood}
  this;

  @override
  List<Object?> get props => [signup];
}
