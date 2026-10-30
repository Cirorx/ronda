import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:bloc/bloc.dart';
import 'package:bloc_concurrency/bloc_concurrency.dart';
import 'package:equatable/equatable.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:push_repository/push_repository.dart';

part 'app_event.dart';
part 'app_state.dart';

/// Who is signed in and how far they got, for the whole app: the router
/// sends signed-out people to the welcome screen, signed-in people without
/// a profile to onboarding and everyone else to the tabs.
///
/// It also carries the conditions accepted on the welcome screen across
/// sign-in: tapping a door is the acceptance, held in memory and on this
/// phone, and it is written to `users/{uid}` only once the person is signed
/// in, so it survives backing out of sign-in or the app being closed. Once
/// a profile exists, the phone stops holding onboarding answers.
///
/// Signing out goes through here too ([AppSignOutRequested]), so this
/// phone's push token is forgotten while the member may still delete it.
class AppBloc extends Bloc<AppEvent, AppState> {
  new({
    required AuthRepository authRepository,
    required this._profileRepository,
    required this._pushRepository,
    this._now = DateTime.now,
  }) : _authRepository = authRepository,
       super(AppState.fromUser(authRepository.currentUser)) {
    on<AppUserSubscriptionRequested>(_onUserSubscriptionRequested);
    // A new user cancels the previous user's profile subscription.
    on<_AppUserChanged>(_onUserChanged, transformer: restartable());
    on<AppTermsAccepted>(_onTermsAccepted);
    // A second tap while the first sign-out runs does nothing.
    on<AppSignOutRequested>(_onSignOutRequested, transformer: droppable());
  }

  /// The version of "Las condiciones, en corto" the welcome screen links.
  /// Bump it whenever that text changes.
  static const termsVersion = '2026-10-27';

  final AuthRepository _authRepository;
  final ProfileRepository _profileRepository;
  final PushRepository _pushRepository;
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
          door: state.door,
        ),
      );
      return;
    }

    emit(
      AppState(
        status: AppStatus.loadingProfile,
        user: user,
        pendingTerms: state.pendingTerms,
        door: state.door,
      ),
    );
    // Held on the phone too, for a sign-in that outlived the app.
    final terms = state.pendingTerms ?? await _profileRepository.heldTerms();
    if (terms != null) {
      try {
        await _profileRepository.acceptTerms(user.id, terms);
        emit(state.withPendingTerms(null));
        await _profileRepository.clearHeldTerms();
      } on AcceptTermsFailure catch (error, stackTrace) {
        // Kept pending: the next sign-in tries again.
        addError(error, stackTrace);
      } on HoldOnPhoneFailure catch (error, stackTrace) {
        addError(error, stackTrace);
      }
    }

    await emit.onEach(
      _profileRepository.watchProfile(user.id),
      onData: (profile) {
        if (profile != null && state.status != AppStatus.authenticated) {
          // Saved, or saved before on another phone: nothing left to hold.
          unawaited(_clearHeldAnswers());
        }
        emit(
          state.withStatus(
            profile == null ? AppStatus.onboarding : AppStatus.authenticated,
          ),
        );
      },
      onError: addError,
    );
  }

  Future<void> _clearHeldAnswers() async {
    try {
      await _profileRepository.clearHeldAnswers();
    } on HoldOnPhoneFailure catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  /// Deletes this phone's push token and its document first, while the
  /// member is still signed in (only they may delete it), then signs out.
  /// A token that can't be deleted is reported and never holds the sign-out
  /// back. The state follows from the auth stream, as for any sign-out.
  Future<void> _onSignOutRequested(
    AppSignOutRequested event,
    Emitter<AppState> emit,
  ) async {
    final user = state.user;
    if (user.isEmpty) return;
    try {
      await _pushRepository.unregisterDevice(user.id);
    } on UnregisterDeviceFailure catch (error, stackTrace) {
      addError(error, stackTrace);
    }
    try {
      await _authRepository.signOut();
    } on SignOutFailure catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  Future<void> _onTermsAccepted(
    AppTermsAccepted event,
    Emitter<AppState> emit,
  ) async {
    final terms = TermsAcceptance(version: termsVersion, acceptedAt: _now());
    if (state.user.isEmpty) {
      emit(state.withDoor(event.door).withPendingTerms(terms));
      try {
        await _profileRepository.holdTerms(terms);
      } on HoldOnPhoneFailure catch (error, stackTrace) {
        // Still held in memory: only closing the app before sign-in loses it.
        addError(error, stackTrace);
      }
      return;
    }
    if (state.door != event.door) emit(state.withDoor(event.door));
    try {
      await _profileRepository.acceptTerms(state.user.id, terms);
    } on AcceptTermsFailure catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }
}
