import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:onboarding_repository/onboarding_repository.dart';

part 'voice_note_state.dart';

/// One voice note for onboarding: the person taps "Grabar", records up to
/// [limit] while the waveform follows their voice, then has it read.
///
/// The note goes to the server only through [OnboardingRepository], which
/// refuses it while the terms are missing. Leaving the recorder throws an
/// unfinished note away. Every failure lands in [VoiceNoteState.failure],
/// typed, so the screen can say what went wrong and the error log can
/// report it.
class VoiceNoteCubit extends Cubit<VoiceNoteState> {
  new({
    required this._uid,
    required this._onboardingRepository,
    Stream<void> Function()? ticks,
  }) : _ticks = ticks ?? _everySecond,
       super(const VoiceNoteState());

  /// The longest note: "Hablás un minuto".
  static const limit = Duration(seconds: 60);

  /// How many bars the waveform shows: about two seconds of voice.
  static const waveformLength = 48;

  /// A level above this is a voice, or at least a sound; below it, silence.
  static const silenceLevel = 0.05;

  /// How long nothing is heard before the screen says "No te escuchamos".
  static const silentAfter = Duration(seconds: 3);

  final String _uid;
  final OnboardingRepository _onboardingRepository;
  final Stream<void> Function() _ticks;
  StreamSubscription<void>? _tick;
  StreamSubscription<double>? _levels;

  /// Whether anything above [silenceLevel] was heard since the last tick.
  bool _heardThisSecond = false;

  /// Whole seconds in a row with nothing heard.
  int _quietSeconds = 0;

  static Stream<void> _everySecond() =>
      Stream<void>.periodic(const Duration(seconds: 1));

  /// "Grabar": starts a new note, from zero.
  Future<void> start() async {
    await _stopListening();
    emit(const VoiceNoteState(status: VoiceNoteStatus.starting));
    try {
      await _onboardingRepository.startVoiceNote();
    } on NoMicrophoneFailure {
      return _fail(VoiceNoteFailure.noMicrophone);
    } on MicrophoneDeniedFailure {
      return _fail(VoiceNoteFailure.microphoneDenied);
    } on Exception {
      return _fail(VoiceNoteFailure.recorderFailed);
    }
    if (isClosed) {
      // The person left while the microphone was starting.
      await _onboardingRepository.discardVoiceNote();
      return;
    }
    _heardThisSecond = false;
    _quietSeconds = 0;
    emit(const VoiceNoteState(status: VoiceNoteStatus.recording));
    _tick = _ticks().listen((_) => _onTick());
    _levels = _onboardingRepository.voiceLevels().listen(
      _onLevel,
      // A level that can't be read is a bar that isn't drawn.
      onError: (Object _) {},
    );
  }

  void _fail(VoiceNoteFailure failure, {String? code}) {
    if (isClosed) return;
    emit(
      VoiceNoteState(
        status: VoiceNoteStatus.failed,
        failure: failure,
        failureCode: code,
      ),
    );
  }

  void _onLevel(double level) {
    final loud = level > silenceLevel;
    if (loud) _heardThisSecond = true;
    final levels = [...state.levels, level];
    emit(
      state.copyWith(
        levels: levels.length > waveformLength
            ? levels.sublist(levels.length - waveformLength)
            : levels,
        heard: state.heard + 1,
        silent: state.silent && !loud,
      ),
    );
  }

  void _onTick() {
    _quietSeconds = _heardThisSecond ? 0 : _quietSeconds + 1;
    _heardThisSecond = false;
    final elapsed = state.elapsed + const Duration(seconds: 1);
    emit(
      state.copyWith(
        elapsed: elapsed,
        silent: _quietSeconds >= silentAfter.inSeconds,
      ),
    );
    if (elapsed >= limit) unawaited(finish());
  }

  /// "Borrar y empezar de nuevo": the note is thrown away and a new one
  /// starts.
  Future<void> restart() async {
    await _stopListening();
    await _onboardingRepository.discardVoiceNote();
    await start();
  }

  /// "Terminé", or the limit: the note is read. Does nothing unless
  /// recording. Cancelled while reading, the answer is dropped.
  Future<void> finish() async {
    if (state.status != VoiceNoteStatus.recording) return;
    await _stopListening();
    emit(
      VoiceNoteState(status: VoiceNoteStatus.reading, elapsed: state.elapsed),
    );
    final read = await _read();
    if (!isClosed) emit(read);
  }

  /// What reading the note came to.
  Future<VoiceNoteState> _read() async {
    VoiceNoteState failed(VoiceNoteFailure failure, [String? code]) =>
        VoiceNoteState(
          status: VoiceNoteStatus.failed,
          failure: failure,
          failureCode: code,
        );
    try {
      final signup = await _onboardingRepository.readVoiceNote(_uid);
      return VoiceNoteState(status: VoiceNoteStatus.read, signup: signup);
    } on VoiceNoteNotUnderstoodFailure {
      return const VoiceNoteState(status: VoiceNoteStatus.notUnderstood);
    } on RecordVoiceNoteFailure {
      return failed(VoiceNoteFailure.recorderFailed);
    } on TermsNotAcceptedFailure {
      return failed(VoiceNoteFailure.termsMissing);
    } on UploadVoiceNoteFailure catch (failure) {
      return failed(
        failure.refused
            ? VoiceNoteFailure.uploadRefused
            : VoiceNoteFailure.uploadFailed,
        failure.code,
      );
    } on Exception {
      return failed(VoiceNoteFailure.readFailed);
    }
  }

  Future<void> _stopListening() async {
    await _tick?.cancel();
    await _levels?.cancel();
    _tick = null;
    _levels = null;
  }

  /// Throws away a note still recording.
  @override
  Future<void> close() async {
    // Released at once, before anything awaits: the screen is going away.
    final discarded = state.status == VoiceNoteStatus.recording
        ? _onboardingRepository.discardVoiceNote()
        : null;
    await _stopListening();
    await discarded;
    await super.close();
  }
}
