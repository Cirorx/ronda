import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:safety_repository/safety_repository.dart';

/// How many reports the admin hasn't seen: the Admin tab's count, the only
/// alert of a new report (no push goes to the admin).
///
/// It reads only while [follow] says the account is the admin; otherwise it
/// is 0 and nothing is asked of the server. A refused or failed read counts
/// as 0.
class UnreadReportsCubit extends Cubit<int> {
  new({required this._safetyRepository}) : super(0);

  final SafetyRepository _safetyRepository;
  StreamSubscription<int>? _count;

  /// Starts reading the count when [admin], stops and shows 0 otherwise.
  void follow({required bool admin}) {
    unawaited(_count?.cancel());
    _count = null;
    if (!admin) {
      emit(0);
      return;
    }
    _count = _safetyRepository.watchUnreadCount().listen(
      emit,
      onError: (Object error, StackTrace stackTrace) {
        addError(error, stackTrace);
        emit(0);
      },
    );
  }

  @override
  Future<void> close() async {
    await _count?.cancel();
    await super.close();
  }
}
