import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:profile_repository/profile_repository.dart';

/// The language Ronda shows: the one picked on this phone, or, with none
/// picked, the phone's own (the app's locale resolution decides).
class const LanguageState({
  /// The picked language; `null` follows the phone.
  final AppLanguage? language,
}) extends Equatable {
  /// The locale the app is pinned to, or `null` to follow the phone.
  Locale? get locale => switch (language) {
    AppLanguage.spanish => const Locale('es', '419'),
    AppLanguage.english => const Locale('en'),
    null => null,
  };

  @override
  List<Object?> get props => [language];
}

/// Switches Ronda's language at once and remembers the pick on this phone,
/// so the next start opens in it.
class LanguageCubit extends Cubit<LanguageState> {
  /// [initial] is the language read from the phone before the app started.
  new({required this._profileRepository, AppLanguage? initial})
    : super(LanguageState(language: initial));

  final ProfileRepository _profileRepository;

  /// Shows [language] now, or the phone's language with `null`, and keeps
  /// the pick. A phone that can't keep it still switches, for this time.
  Future<void> languagePicked(AppLanguage? language) async {
    emit(LanguageState(language: language));
    try {
      await _profileRepository.holdLanguage(language);
    } on HoldOnPhoneFailure {
      // Switched for now; only the next start won't remember it.
    }
  }
}
