import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cuaderno_repository/cuaderno_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:error_reporter/error_reporter.dart';
import 'package:ronda/cuaderno/cubit/cuaderno_hook.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'cuaderno_state.dart';

/// El cuaderno del barrio (`docs/PRODUCT.md` § El cuaderno del barrio):
/// today's line, the lines written, the one chosen to bring to the meeting
/// and the week's postcard.
///
/// It keeps no streak and counts nothing. Everything but the postcard
/// stays on the phone through [CuadernoRepository]; the postcard is drawn
/// from the week's lines (the last seven days) and held in memory, offered
/// only on the day before the ronda's meeting and on the day itself, and
/// only when the week has lines.
class CuadernoCubit extends Cubit<CuadernoState> implements StepNamed {
  new({
    required this._uid,
    required this._cuadernoRepository,
    required this._rondaRepository,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now,
       super(const CuadernoState());

  final String _uid;
  final CuadernoRepository _cuadernoRepository;
  final RondaRepository _rondaRepository;
  final DateTime Function() _now;
  StreamSubscription<void>? _changes;
  StreamSubscription<ThisWeek?>? _week;

  DateTime _today() {
    final now = _now();
    return DateTime(now.year, now.month, now.day);
  }

  /// Reads the cuaderno, and follows it and the ronda's next meeting.
  Future<void> started() async {
    _changes = _cuadernoRepository.changes.listen((_) => unawaited(_load()));
    _week = _rondaRepository
        .watchThisWeek(_uid)
        .listen(
          (week) => emit(state.copyWith(meetingDate: () => week?.date)),
          // No ronda to read is no postcard, not a broken cuaderno.
          onError: (Object _) => emit(state.copyWith(meetingDate: () => null)),
        );
    await _load();
  }

  /// Reads the cuaderno again; "Probar de nuevo".
  Future<void> retry() async {
    emit(state.copyWith(status: CuadernoStatus.loading));
    await _load();
  }

  Future<void> _load() async {
    try {
      final cuaderno = await _cuadernoRepository.read(_uid);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: CuadernoStatus.ready,
          cuaderno: cuaderno,
          today: _today(),
        ),
      );
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) emit(state.copyWith(status: CuadernoStatus.failure));
    }
  }

  /// "Anotar": today's line. An empty one is ignored.
  Future<void> writeToday(String text) async {
    if (text.trim().isEmpty || state.writing) return;
    emit(state.copyWith(writing: true, wrote: false, failure: () => null));
    try {
      await _cuadernoRepository.saveEntry(_uid, day: _today(), text: text);
      if (!isClosed) emit(state.copyWith(writing: false, wrote: true));
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(
          state.copyWith(writing: false, failure: () => CuadernoFailure.write),
        );
      }
    }
  }

  /// "Borrar esta línea".
  Future<void> deleteEntry(CuadernoEntry entry) =>
      _change(() => _cuadernoRepository.deleteEntry(_uid, entry.day));

  /// "Deshacer" after a deleted line: it goes back, as it was.
  Future<void> restoreEntry(CuadernoEntry entry) => _change(
    () => _cuadernoRepository.saveEntry(_uid, day: entry.day, text: entry.text),
  );

  /// "Llevar esta línea" ([bring] true), or "Ya no la llevo".
  Future<void> bringToggled(CuadernoEntry entry, {required bool bring}) =>
      _change(() => _cuadernoRepository.bring(_uid, bring ? entry.day : null));

  Future<void> _change(Future<Object?> Function() change) async {
    emit(state.copyWith(failure: () => null));
    try {
      await change();
    } on Exception catch (error, stackTrace) {
      addError(error, stackTrace);
      if (!isClosed) {
        emit(state.copyWith(failure: () => CuadernoFailure.write));
      }
    }
  }

  /// "Dibujar la postal": the week's lines become a postcard.
  Future<void> postcardRequested() async {
    if (!state.postcardOffered || state.makingPostcard) return;
    emit(state.copyWith(makingPostcard: true, failure: () => null));
    try {
      final postcard = await _cuadernoRepository.makePostcard([
        for (final entry in state.weekLines) entry.text,
      ]);
      if (!isClosed) {
        emit(state.copyWith(makingPostcard: false, postcard: () => postcard));
      }
    } on NothingToDrawFailure {
      _postcardFailed(CuadernoFailure.nothingToDraw);
    } on Exception {
      _postcardFailed(CuadernoFailure.postcard);
    }
  }

  void _postcardFailed(CuadernoFailure failure) {
    if (!isClosed) {
      emit(state.copyWith(makingPostcard: false, failure: () => failure));
    }
  }

  /// "Guardar en el teléfono": the share sheet, titled [title].
  Future<void> shareRequested({required String title}) async {
    final postcard = state.postcard;
    if (postcard == null) return;
    try {
      await _cuadernoRepository.sharePostcard(postcard, title: title);
    } on Exception {
      if (!isClosed) {
        emit(state.copyWith(failure: () => CuadernoFailure.share));
      }
    }
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    await _week?.cancel();
    await super.close();
  }

  @override
  String get reportStep => 'CuadernoCubit';
}
