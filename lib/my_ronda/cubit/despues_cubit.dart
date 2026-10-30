import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:ronda_repository/ronda_repository.dart';

part 'despues_state.dart';

/// "¿Hay después esta semana?": saves what this week's host set for ronda
/// [_rondaId]'s meeting of [_week].
class DespuesCubit extends Cubit<DespuesState> {
  new({
    required this._rondaId,
    required this._week,
    required this._rondaRepository,
  }) : super(const DespuesState());

  final String _rondaId;
  final String _week;
  final RondaRepository _rondaRepository;

  /// Saves the después: [kind] with [what], and [where] for a public place
  /// or [homeOfUid] and [address] for a home. Empty fields it needs stop it
  /// before it is sent ([DespuesState.missing]).
  Future<void> save({
    required DespuesKind kind,
    String what = '',
    String where = '',
    String? homeOfUid,
    String address = '',
  }) async {
    if (state.saving) return;
    String? text(String value) => value.trim().isEmpty ? null : value.trim();
    final missing = switch (kind) {
      DespuesKind.none => false,
      DespuesKind.place => text(what) == null || text(where) == null,
      DespuesKind.home => text(what) == null || text(address) == null,
    };
    if (missing) {
      emit(const DespuesState(missing: true));
      return;
    }
    emit(const DespuesState(saving: true));
    try {
      await _rondaRepository.setDespues(
        rondaId: _rondaId,
        week: _week,
        kind: kind,
        what: kind == DespuesKind.none ? null : text(what),
        where: kind == DespuesKind.place ? text(where) : null,
        homeOfUid: kind == DespuesKind.home ? homeOfUid : null,
        address: kind == DespuesKind.home ? text(address) : null,
      );
    } on HostsFailure catch (failure, stackTrace) {
      addError(failure, stackTrace);
      emit(DespuesState(failure: failure.reason));
      return;
    }
    emit(const DespuesState(saved: true));
  }
}
