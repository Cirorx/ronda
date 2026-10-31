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

  /// The fields [kind] needs that are still empty: [what] for a place or a
  /// home, with [where] for a public place or [address] for a home. The
  /// sheet shows the same answer under each field as it is filled in.
  static Set<DespuesField> missingFields({
    required DespuesKind kind,
    String what = '',
    String where = '',
    String address = '',
  }) => {
    if (kind != DespuesKind.none && what.trim().isEmpty) DespuesField.what,
    if (kind == DespuesKind.place && where.trim().isEmpty) DespuesField.where,
    if (kind == DespuesKind.home && address.trim().isEmpty)
      DespuesField.address,
  };

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
    final missing = missingFields(
      kind: kind,
      what: what,
      where: where,
      address: address,
    ).isNotEmpty;
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
