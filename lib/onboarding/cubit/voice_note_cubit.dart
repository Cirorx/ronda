import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:onboarding_repository/onboarding_repository.dart';

part 'voice_note_state.dart';

/// One voice note for onboarding: record up to [limit], then have it read.
///
/// The note goes to the server only through [OnboardingRepository], which
/// refuses it while the terms are missing. Leaving the recorder throws an
/// unfinished note away.
class VoiceNoteCubit extends Cubit<VoiceNoteState> {
  new({
    required this._uid,
    required this._onboardingRepository,
    Stream<void> Function()? ticks,
  }) : _ticks = ticks ?? _everySecond,
       super(const VoiceNoteState());

  /// The longest note: "Hablás un minuto".
  static const limit = Duration(seconds: 60);

  final String _uid;
  final OnboardingRepository _onboardingRepository;
  final Stream<void> Function() _ticks;
  StreamSubscription<void>? _tick;

  static Stream<void> _everySecond() =>
      Stream<void>.periodic(const Duration(seconds: 1));

  /// Starts a new note, from zero.
  Future<void> start() async {
    await _stopTicking();
    if (state != const VoiceNoteState()) emit(const VoiceNoteState());
    try {
      await _onboardingRepository.startVoiceNote();
    } on MicrophoneDeniedFailure {
      emit(const VoiceNoteState(status: VoiceNoteStatus.microphoneDenied));
      return;
    } on Exception {
      emit(const VoiceNoteState(status: VoiceNoteStatus.failure));
      return;
    }
    emit(const VoiceNoteState(status: VoiceNoteStatus.recording));
    _tick = _ticks().listen((_) => _onTick());
  }

  void _onTick() {
    final elapsed = state.elapsed + const Duration(seconds: 1);
    emit(VoiceNoteState(status: VoiceNoteStatus.recording, elapsed: elapsed));
    if (elapsed >= limit) unawaited(finish());
  }

  /// "Borrar y empezar de nuevo": the note is thrown away and a new one
  /// starts.
  Future<void> restart() async {
    await _stopTicking();
    await _onboardingRepository.discardVoiceNote();
    await start();
  }

  /// "Terminé", or the limit: the note is read. Does nothing unless
  /// recording. Cancelled while reading, the answer is dropped.
  Future<void> finish() async {
    if (state.status != VoiceNoteStatus.recording) return;
    await _stopTicking();
    emit(
      VoiceNoteState(status: VoiceNoteStatus.reading, elapsed: state.elapsed),
    );
    final read = await _read();
    if (!isClosed) emit(read);
  }

  /// What reading the note came to.
  Future<VoiceNoteState> _read() async {
    try {
      final signup = await _onboardingRepository.readVoiceNote(_uid);
      return VoiceNoteState(status: VoiceNoteStatus.read, signup: signup);
    } on VoiceNoteNotUnderstoodFailure {
      return const VoiceNoteState(status: VoiceNoteStatus.notUnderstood);
    } on Exception {
      return const VoiceNoteState(status: VoiceNoteStatus.failure);
    }
  }

  Future<void> _stopTicking() async {
    await _tick?.cancel();
    _tick = null;
  }

  /// Throws away a note still recording.
  @override
  Future<void> close() async {
    // Released at once, before anything awaits: the screen is going away.
    final discarded = state.status == VoiceNoteStatus.recording
        ? _onboardingRepository.discardVoiceNote()
        : null;
    await _stopTicking();
    await discarded;
    await super.close();
  }
}
