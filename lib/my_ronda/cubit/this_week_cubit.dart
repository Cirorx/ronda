import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'this_week_state.dart';

/// The Mi ronda card: follows [_uid]'s ronda and its upcoming meeting, and
/// records "Voy" or "Esta no".
///
/// An "Esta no" from the card opens the sheet that never asks why
/// ([ThisWeekState.estaNoSheet]); from it the member stays in, pauses two
/// weeks, or takes it back. A failed answer leaves the card as it was, with
/// [ThisWeekState.answerFailed] for the line that says so.
///
/// It also answers what the card asks this member about the week: "¿Abrís
/// vos?" ([handoffAnswered]) and the después at their home
/// ([homeAnswered]).
class ThisWeekCubit extends Cubit<ThisWeekState> {
  new({required this._uid, required this._rondaRepository})
    : super(const ThisWeekState());

  final String _uid;
  final RondaRepository _rondaRepository;
  StreamSubscription<ThisWeek?>? _subscription;

  /// Follows the member's ronda and its week.
  void subscribe() {
    unawaited(_subscription?.cancel());
    emit(const ThisWeekState());
    _subscription = _rondaRepository
        .watchThisWeek(_uid)
        .listen(
          (week) => emit(
            ThisWeekState(
              status: week == null
                  ? ThisWeekStatus.noGroup
                  : ThisWeekStatus.ready,
              week: week,
              answering: state.answering,
              estaNoSheet: state.estaNoSheet,
              acting: state.acting,
              actionFailure: state.actionFailure,
            ),
          ),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emit(const ThisWeekState(status: ThisWeekStatus.failure));
          },
        );
  }

  /// "Voy".
  Future<void> yesTapped() => _answer(RsvpAnswer.yes);

  /// "Esta no" on the card: records it, then opens the sheet.
  Future<void> noTapped() => _answer(RsvpAnswer.no, openSheet: true);

  /// "Pausar 2 semanas" on the sheet.
  Future<void> pauseTapped() => _answer(RsvpAnswer.no, pause: true);

  /// "Cambiar mi respuesta": the question shows again.
  void changeTapped() => emit(state.copyWith(changing: true));

  /// The sheet closed, whichever way.
  void sheetClosed() => emit(state.copyWith(estaNoSheet: false));

  /// "Sí, abro yo" ([yes]) or "Hoy no puedo".
  Future<void> handoffAnswered({required bool yes}) async {
    final week = state.week;
    final ask = week?.handoffAsk;
    if (week == null || ask == null) return;
    await _act(
      () => _rondaRepository.answerHandoff(
        rondaId: week.rondaId,
        week: ask.week,
        yes: yes,
      ),
    );
  }

  /// "Sí, puede ser" ([yes]) or "Mejor no" to the después at this member's
  /// home.
  Future<void> homeAnswered({required bool yes}) async {
    final week = state.week;
    final meeting = week?.week;
    if (week == null || meeting == null) return;
    await _act(
      () => _rondaRepository.answerDespues(
        rondaId: week.rondaId,
        week: meeting,
        yes: yes,
      ),
    );
  }

  Future<void> _act(Future<void> Function() call) async {
    if (state.acting) return;
    emit(state.copyWith(acting: true, actionFailure: () => null));
    try {
      await call();
    } on HostsFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      if (!isClosed) {
        emit(
          state.copyWith(acting: false, actionFailure: () => failure.reason),
        );
      }
      return;
    }
    if (!isClosed) emit(state.copyWith(acting: false));
  }

  Future<void> _answer(
    RsvpAnswer answer, {
    bool pause = false,
    bool openSheet = false,
  }) async {
    final week = state.week;
    if (week == null || state.answering != null) return;
    emit(state.copyWith(answering: () => answer, answerFailed: false));
    try {
      await _rondaRepository.answerRsvp(
        rondaId: week.rondaId,
        answer: answer,
        pause: pause,
      );
    } on RsvpFailure catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(answering: () => null, answerFailed: true));
      }
      return;
    }
    if (isClosed) return;
    emit(
      state.copyWith(
        answering: () => null,
        changing: false,
        estaNoSheet: openSheet || state.estaNoSheet,
      ),
    );
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
