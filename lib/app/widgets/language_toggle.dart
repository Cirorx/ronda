import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/cubit/language_cubit.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// "English" while Ronda speaks Spanish, "Español" while it speaks English:
/// one tap switches the whole app, before anyone has signed in.
class const LanguageToggle({
  /// Whether the translate icon goes before the word; off where the line
  /// is short, such as the welcome screen's header on a phone.
  final bool showIcon = true,
  super.key,
}) extends StatelessWidget {
  /// Maestro's handle.
  static const identifier = 'language.toggle';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final english = Localizations.localeOf(context).languageCode == 'en';
    return MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: TextButton.icon(
          onPressed: () => unawaited(
            context.read<LanguageCubit>().languagePicked(
              english ? AppLanguage.spanish : AppLanguage.english,
            ),
          ),
          icon: showIcon ? const Icon(Icons.translate) : null,
          label: Text(english ? l10n.languageSpanish : l10n.languageEnglish),
        ),
      ),
    );
  }
}

/// The words for a language choice.
extension LanguageLabels on AppLocalizations {
  /// "Español", "English", or "Como el teléfono" when none was picked.
  String languageName(AppLanguage? language) => switch (language) {
    AppLanguage.spanish => languageSpanish,
    AppLanguage.english => languageEnglish,
    null => languagePhone,
  };
}
