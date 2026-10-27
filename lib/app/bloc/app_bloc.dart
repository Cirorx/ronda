import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:profile_repository/profile_repository.dart';

part 'app_event.dart';
part 'app_state.dart';

/// Who is signed in and how far they got, for the whole app: the router
/// sends signed-out people to the welcome screen, signed-in people without
/// a profile to onboarding and everyone else to the tabs.
///
/// It also carries the conditions accepted on the welcome screen across
/// sign-in: tapping a door is the acceptance, and it is written to
/// `users/{uid}` only once the person is signed in.
class AppBloc extends Bloc<AppEvent, AppState> {
  new({
    required AuthRepository authRepository,
    required this._profileRepository,
    this._now = DateTime.now,
  }) : _authRepository = authRepository,
       super(AppState.fromUser(authRepository.currentUser)) {
    on<AppUserSubscriptionRequested>(_onUserSubscriptionRequested);
    // A new user cancels the previous user's profile subscription.
    on<_AppUserChanged>(_onUserChanged, transformer: restartable());
    on<AppTermsAccepted>(_onTermsAccepted);
  }

  /// The version of "Las condiciones, en corto" the welcome screen links.
  /// Bump it whenever that text changes.
  static const termsVersion = '2026-10-27';

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final DateTime Function() _now;

  Future<void> _onUserSubscriptionRequested(
    AppUserSubscriptionRequested event,
    Emitter<AppState> emit,
  ) {
    return emit.onEach(
      _authRepository.user,
      onData: (user) => add(_AppUserChanged(user)),
      onError: addError,
    );
  }

  Future<void> _onUserChanged(
    _AppUserChanged event,
    Emitter<AppState> emit,
  ) async {
    final user = event.user;
    if (user.isEmpty) {
      emit(
        AppState(
          status: AppStatus.unauthenticated,
          pendingTerms: state.pendingTerms,
        ),
      );
      return;
    }

    emit(
      AppState(
        status: AppStatus.loadingProfile,
        user: user,
        pendingTerms: state.pendingTerms,
      ),
    );
    if (state.pendingTerms case final terms?) {
      try {
        await _profileRepository.acceptTerms(user.id, terms);
        emit(state.withPendingTerms(null));
      } on AcceptTermsFailure catch (error, stackTrace) {
        // Kept pending: the next sign-in tries again.
        addError(error, stackTrace);
      }
    }

    await emit.onEach(
      _profileRepository.watchProfile(user.id),
      onData: (profile) => emit(
        state.withStatus(
          profile == null ? AppStatus.onboarding : AppStatus.authenticated,
        ),
      ),
      onError: addError,
    );
  }

  Future<void> _onTermsAccepted(
    AppTermsAccepted event,
    Emitter<AppState> emit,
  ) async {
    final terms = TermsAcceptance(version: termsVersion, acceptedAt: _now());
    if (state.user.isEmpty) {
      emit(state.withPendingTerms(terms));
      return;
    }
    try {
      await _profileRepository.acceptTerms(state.user.id, terms);
    } on AcceptTermsFailure catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }
}
