import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:equatable/equatable.dart';

part 'line_voice_state.dart';

/// A short voice note that writes a line: "Decilo con la voz".
///
/// Nothing records before the tap, the note is at most [limit] long, and
/// the words come back to the screen to be read and changed before they
/// are written: nothing is written to the cuaderno here. The note goes to
/// the server only through [CuadernoRepository], which refuses it before
/// the terms, and is deleted once read. Leaving the screen throws an
/// unfinished note away.
class LineVoiceCubit extends Cubit<LineVoiceState> {
  new({
    required this._uid,
    required this._cuadernoRepository,
    Stream<void> Function()? ticks,
  }) : _ticks = ticks ?? _everySecond,
       super(const LineVoiceState());

  /// The longest note.
  static const limit = Duration(seconds: 30);

  /// How many bars the waveform shows.
  static const waveformLength = 48;

  final String _uid;
  final CuadernoRepository _cuadernoRepository;
  final Stream<void> Function() _ticks;
  StreamSubscription<void>? _tick;
  StreamSubscription<double>? _levels;

  static Stream<void> _everySecond() =>
      Stream<void>.periodic(const Duration(seconds: 1));

  /// "Decilo con la voz": starts a note.
  Future<void> start() async {
    await _stopListening();
    emit(const LineVoiceState(status: LineVoiceStatus.starting));
    try {
      await _cuadernoRepository.startVoiceNote();
    } on VoiceLineFailure catch (failure) {
      return _fail(failure);
    } on Exception {
      return _fail(const VoiceLineFailure(VoiceLineProblem.recorderFailed));
    }
    if (isClosed) {
      await _cuadernoRepository.discardVoiceNote();
      return;
    }
    emit(const LineVoiceState(status: LineVoiceStatus.recording));
    _tick = _ticks().listen((_) => _onTick());
    _levels = _cuadernoRepository.voiceLevels().listen(
      _onLevel,
      // A level that can't be read is a bar that isn't drawn.
      onError: (Object _) {},
    );
  }

  void _fail(VoiceLineFailure failure) {
    if (isClosed) return;
    emit(
      LineVoiceState(
        status: LineVoiceStatus.failed,
        problem: failure.problem,
        problemCode: failure.code,
      ),
    );
  }

  void _onLevel(double level) {
    final levels = [...state.levels, level];
    emit(
      state.copyWith(
        levels: levels.length > waveformLength
            ? levels.sublist(levels.length - waveformLength)
            : levels,
        heard: state.heard + 1,
      ),
    );
  }

  void _onTick() {
    final elapsed = state.elapsed + const Duration(seconds: 1);
    emit(state.copyWith(elapsed: elapsed));
    if (elapsed >= limit) unawaited(finish());
  }

  /// "Terminé", or the limit: the note is read.
  Future<void> finish() async {
    if (state.status != LineVoiceStatus.recording) return;
    await _stopListening();
    emit(const LineVoiceState(status: LineVoiceStatus.reading));
    try {
      final text = await _cuadernoRepository.readVoiceLine(_uid);
      if (!isClosed) {
        emit(LineVoiceState(status: LineVoiceStatus.read, text: text));
      }
    } on VoiceLineFailure catch (failure) {
      _fail(failure);
    } on Exception {
      _fail(const VoiceLineFailure(VoiceLineProblem.readFailed));
    }
  }

  /// "Cancelar": the note is thrown away, or the failure dismissed.
  Future<void> cancel() async {
    await _stopListening();
    if (state.status == LineVoiceStatus.recording) {
      await _cuadernoRepository.discardVoiceNote();
    }
    emit(const LineVoiceState());
  }

  /// The screen took the words: back to waiting for "Decilo con la voz".
  void textTaken() => emit(const LineVoiceState());

  Future<void> _stopListening() async {
    await _tick?.cancel();
    await _levels?.cancel();
    _tick = null;
    _levels = null;
  }

  /// Throws away a note still recording.
  @override
  Future<void> close() async {
    final discarded = state.status == LineVoiceStatus.recording
        ? _cuadernoRepository.discardVoiceNote()
        : null;
    await _stopListening();
    await discarded;
    await super.close();
  }
}
