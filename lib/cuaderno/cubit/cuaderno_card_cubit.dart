import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:cuaderno_repository/cuaderno_repository.dart';

/// The cuaderno's side of Mi ronda: the line the member chose to bring to
/// the meeting, as their own card shows it. It reads the phone only, and
/// follows the cuaderno when it changes.
///
/// The state is that line, or `null` when none is chosen.
class CuadernoCardCubit extends Cubit<String?> {
  new({required this._uid, required this._cuadernoRepository}) : super(null);

  final String _uid;
  final CuadernoRepository _cuadernoRepository;
  StreamSubscription<void>? _changes;

  /// Reads the line to bring and follows the cuaderno.
  Future<void> started() async {
    _changes = _cuadernoRepository.changes.listen((_) => unawaited(_read()));
    await _read();
  }

  Future<void> _read() async {
    try {
      final cuaderno = await _cuadernoRepository.read(_uid);
      if (!isClosed) emit(cuaderno.brought?.text);
    } on Exception {
      // An unreadable cuaderno shows no reminder; its own screen says why.
      if (!isClosed) emit(null);
    }
  }

  @override
  Future<void> close() async {
    await _changes?.cancel();
    await super.close();
  }
}
