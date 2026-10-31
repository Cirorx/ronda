import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:error_reporter/error_reporter.dart';

part 'error_log_state.dart';

/// The admin's web error log: follows the newest reports, groups them by
/// code and screen, and opens one group.
///
/// The server decides who is admin: a refusal shows as
/// [ErrorLogStatus.forbidden].
class ErrorLogCubit extends Cubit<ErrorLogState> {
  new({required this._clientErrorLog}) : super(const ErrorLogState());

  final ClientErrorLog _clientErrorLog;
  StreamSubscription<List<ClientError>>? _errors;

  /// Follows the newest reports.
  void subscribe() {
    unawaited(_errors?.cancel());
    emit(const ErrorLogState());
    _errors = _clientErrorLog.watchRecent().listen(
      (errors) => emit(
        ErrorLogState(
          status: ErrorLogStatus.ready,
          errors: errors,
          openGroup: state.openGroup,
        ),
      ),
      onError: (Object error, StackTrace stackTrace) => emit(
        ErrorLogState(
          status:
              error is ClientErrorLogFailure &&
                  error.reason == ClientErrorLogFailureReason.forbidden
              ? ErrorLogStatus.forbidden
              : ErrorLogStatus.failure,
        ),
      ),
    );
  }

  /// Opens the group [key] ([ErrorGroup.key]).
  void groupOpened(String key) => emit(
    ErrorLogState(status: state.status, errors: state.errors, openGroup: key),
  );

  /// Back to every group.
  void groupClosed() =>
      emit(ErrorLogState(status: state.status, errors: state.errors));

  @override
  Future<void> close() async {
    await _errors?.cancel();
    await super.close();
  }
}
