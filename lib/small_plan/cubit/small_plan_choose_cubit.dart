import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:ronda/small_plan/models/models.dart';
import 'package:small_plan_repository/small_plan_repository.dart';

part 'small_plan_choose_state.dart';

/// The choice of a small plan, in a sheet: three ideas from the server, or
/// the member's own, said ("Decilo vos": a voice note while the waveform
/// follows the voice) or typed, shaped into a plan they confirm.
///
/// Nothing is kept here: the sheet closes with [SmallPlanChooseState.chosen]
/// and Mi ronda keeps it on the phone. A note goes to the server only
/// through [SmallPlanRepository], which refuses it while the terms are
/// missing; leaving throws away a note still recording. Every failure lands
/// in [SmallPlanChooseState.failure], typed, so the sheet can say what went
/// wrong and the error log can report it.
class SmallPlanChooseCubit extends Cubit<SmallPlanChooseState>
    implements StepNamed {
  new({
    required this._uid,
    required this._smallPlanRepository,
    Stream<void> Function()? ticks,
  }) : _ticks = ticks ?? _everySecond,
       super(const SmallPlanChooseState());

  /// The longest note.
  static const limit = Duration(seconds: 60);

  /// How many bars the waveform shows: about two seconds of voice.
  static const waveformLength = 48;

  /// A level above this is a voice, or at least a sound.
  static const silenceLevel = 0.05;

  /// How long nothing is heard before the sheet says so.
  static const silentAfter = Duration(seconds: 3);

  final String _uid;
  final SmallPlanRepository _smallPlanRepository;
  final Stream<void> Function() _ticks;
  StreamSubscription<void>? _tick;
  StreamSubscription<double>? _levels;
  StreamSubscription<String>? _words;
  bool _heardThisSecond = false;
  int _quietSeconds = 0;

  static Stream<void> _everySecond() =>
      Stream<void>.periodic(const Duration(seconds: 1));

  /// Brings the three ideas.
  Future<void> load() async {
    emit(state.copyWith(ideas: SmallPlanIdeas.loading));
    try {
      final suggestions = await _smallPlanRepository.suggestions();
      if (isClosed) return;
      emit(
        state.copyWith(ideas: SmallPlanIdeas.ready, suggestions: suggestions),
      );
    } on SmallPlanFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      if (!isClosed) emit(state.copyWith(ideas: SmallPlanIdeas.failure));
    }
  }

  /// One of the three ideas was tapped.
  void suggestionTapped(SmallPlanSuggestion suggestion) =>
      emit(state.copyWith(chosen: () => suggestion.plan));

  /// "Decilo vos": the member's own plan.
  void sayTapped() => emit(
    state.copyWith(
      step: SmallPlanStep.say,
      dropped: () => null,
      failure: () => null,
      failureCode: () => null,
    ),
  );

  /// "Volver a las ideas".
  void ideasTapped() => emit(state.copyWith(step: SmallPlanStep.ideas));

  /// The text field changed.
  void textChanged(String value) => emit(
    state.copyWith(
      text: PlanText.dirty(value),
      dropped: () => null,
      failure: () => null,
      failureCode: () => null,
    ),
  );

  /// "Listo": shapes what was typed.
  Future<void> textSubmitted() async {
    if (!state.text.isValid) {
      emit(state.copyWith(textTried: true));
      return;
    }
    emit(state.copyWith(step: SmallPlanStep.reading));
    try {
      _reading(await _smallPlanRepository.shapeText(_uid, state.text.words));
    } on SmallPlanFailure catch (failure) {
      _failed(failure);
    }
  }

  /// "Grabar": starts a new note, from zero.
  Future<void> recordTapped() async {
    await _stopListening();
    emit(
      state.copyWith(
        step: SmallPlanStep.say,
        elapsed: Duration.zero,
        levels: const [],
        heard: 0,
        silent: false,
        words: '',
        dropped: () => null,
        failure: () => null,
        failureCode: () => null,
      ),
    );
    try {
      await _smallPlanRepository.startVoiceNote(_uid);
    } on SmallPlanFailure catch (failure) {
      _failed(failure);
      return;
    }
    if (isClosed) {
      // The person left while the microphone was starting.
      await _smallPlanRepository.discardVoiceNote();
      return;
    }
    _heardThisSecond = false;
    _quietSeconds = 0;
    emit(state.copyWith(step: SmallPlanStep.recording));
    _tick = _ticks().listen((_) => _onTick());
    _levels = _smallPlanRepository.voiceLevels().listen(
      _onLevel,
      // A level that can't be read is a bar that isn't drawn.
      onError: (Object _) {},
    );
    _words = _smallPlanRepository.liveWords().listen(
      _onWords,
      // Live words are a bonus: without them the note is read at the end.
      onError: (Object _) {},
    );
  }

  void _onWords(String words) {
    if (state.step == SmallPlanStep.recording) {
      emit(state.copyWith(words: words));
    }
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
    if (elapsed >= limit) unawaited(finishTapped());
  }

  /// "Terminé", or the limit: the note is read.
  Future<void> finishTapped() async {
    if (state.step != SmallPlanStep.recording) return;
    await _stopListening();
    emit(state.copyWith(step: SmallPlanStep.reading));
    try {
      _reading(await _smallPlanRepository.shapeVoiceNote(_uid));
    } on SmallPlanFailure catch (failure) {
      _failed(failure);
    }
  }

  /// "Cancelar" while recording: the note is thrown away.
  Future<void> recordingCancelled() async {
    await _stopListening();
    await _smallPlanRepository.discardVoiceNote();
    if (!isClosed) emit(state.copyWith(step: SmallPlanStep.say));
  }

  void _reading(SmallPlanReading reading) {
    if (isClosed) return;
    switch (reading) {
      case final SmallPlanRead read:
        emit(state.copyWith(step: SmallPlanStep.review, read: () => read));
      case SmallPlanDropped(:final reason):
        emit(state.copyWith(step: SmallPlanStep.say, dropped: () => reason));
    }
  }

  void _failed(SmallPlanFailure failure) {
    if (isClosed) return;
    emit(
      state.copyWith(
        step: SmallPlanStep.say,
        failure: () => failure.kind,
        failureCode: () => failure.code,
      ),
    );
  }

  /// "Sí, es esto": the plan is the member's.
  void confirmTapped() {
    if (state.read case final read?) {
      emit(state.copyWith(chosen: () => read.plan));
    }
  }

  /// "Probar de nuevo": back to saying it.
  void againTapped() =>
      emit(state.copyWith(step: SmallPlanStep.say, read: () => null));

  Future<void> _stopListening() async {
    await _tick?.cancel();
    await _levels?.cancel();
    await _words?.cancel();
    _tick = null;
    _levels = null;
    _words = null;
  }

  /// Throws away a note still recording.
  @override
  Future<void> close() async {
    // Released at once, before anything awaits: the sheet is going away.
    final discarded = state.step == SmallPlanStep.recording
        ? _smallPlanRepository.discardVoiceNote()
        : null;
    await _stopListening();
    await discarded;
    await super.close();
  }

  @override
  String get reportStep => 'SmallPlanChooseCubit';
}
