import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'first_visit_state.dart';

/// A member's side of Así va a ser (#70): follows what their ronda asks of
/// them about newcomers, picks who waits for one, and says "No puedo".
///
/// The rules of when each shows live here:
/// - the newcomer's own card from [cardDaysAhead] days before their first
///   meeting until its day (a later joiner sees it at once);
/// - a host's question until the meeting's day;
/// - a waiter's "No puedo" only when someone else picked them, until the
///   meeting's day (a host who picked themself changes it instead).
class FirstVisitCubit extends Cubit<FirstVisitState> {
  new({
    required this._uid,
    required this._rondaRepository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const FirstVisitState());

  /// How many days before the meeting the newcomer sees "Así va a ser".
  static const cardDaysAhead = 2;

  final String _uid;
  final RondaRepository _rondaRepository;
  final DateTime Function() _now;
  StreamSubscription<FirstVisit?>? _subscription;

  /// Follows the member's ronda's newcomers.
  void subscribe() {
    unawaited(_subscription?.cancel());
    _subscription = _rondaRepository
        .watchFirstVisit(_uid)
        .listen(
          (visit) => emit(_ready(visit)),
          onError: (Object error, StackTrace stackTrace) {
            addError(error, stackTrace);
            emit(const FirstVisitState(status: FirstVisitStatus.failure));
          },
        );
  }

  FirstVisitState _ready(FirstVisit? visit) {
    final now = _now();
    final today = DateTime(now.year, now.month, now.day);
    bool ahead(Welcome welcome) => !welcome.date.isBefore(today);
    final mine = visit?.mine;
    final soon = today.add(const Duration(days: cardDaysAhead));
    return FirstVisitState(
      status: FirstVisitStatus.ready,
      card: mine != null && ahead(mine) && !mine.date.isAfter(soon)
          ? mine
          : null,
      toChoose: [...?visit?.toChoose.where(ahead)],
      waitingFor: [
        for (final welcome in visit?.waitingFor ?? const <Welcome>[])
          if (ahead(welcome) && welcome.setBy?.uid != _uid) welcome,
      ],
      save: state.save,
      failure: state.failure,
    );
  }

  /// The sheet opened: no earlier save shows.
  void sheetOpened() =>
      emit(state.copyWith(save: WelcomeSaveStatus.idle, failure: () => null));

  /// A host picks [waiterUid] to wait for [welcome]'s newcomer, with
  /// [sign], how to recognise them.
  Future<void> picked(
    Welcome welcome, {
    required String waiterUid,
    required String sign,
  }) => _save(
    () => _rondaRepository.setWelcome(
      rondaId: welcome.rondaId,
      newcomerUid: welcome.newcomerUid,
      waiterUid: waiterUid,
      sign: sign.trim(),
    ),
  );

  /// "No puedo" from the member picked to wait for [welcome]'s newcomer.
  Future<void> declined(Welcome welcome) => _save(
    () => _rondaRepository.declineWelcome(
      rondaId: welcome.rondaId,
      newcomerUid: welcome.newcomerUid,
    ),
  );

  Future<void> _save(Future<void> Function() call) async {
    if (state.save == WelcomeSaveStatus.saving) return;
    emit(state.copyWith(save: WelcomeSaveStatus.saving, failure: () => null));
    try {
      await call();
    } on WelcomeFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      if (!isClosed) {
        emit(
          state.copyWith(
            save: WelcomeSaveStatus.failed,
            failure: () => failure.reason,
          ),
        );
      }
      return;
    }
    if (!isClosed) emit(state.copyWith(save: WelcomeSaveStatus.saved));
  }

  @override
  Future<void> close() async {
    await _subscription?.cancel();
    await super.close();
  }
}
