import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'app_event.dart';
part 'app_state.dart';

/// Who is signed in, for the whole app: the router sends signed-out people
/// to the login screen and signed-in people to the tabs.
class AppBloc extends Bloc<AppEvent, AppState> {
  new({required AuthRepository authRepository})
    : _authRepository = authRepository,
      super(AppState.fromUser(authRepository.currentUser)) {
    on<AppUserSubscriptionRequested>(_onUserSubscriptionRequested);
  }

  final AuthRepository _authRepository;

  Future<void> _onUserSubscriptionRequested(
    AppUserSubscriptionRequested event,
    Emitter<AppState> emit,
  ) {
    return emit.onEach(
      _authRepository.user,
      onData: (user) => emit(AppState.fromUser(user)),
      onError: addError,
    );
  }
}
