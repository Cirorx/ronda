import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Ajustes → Idioma: "Como el teléfono", "Español" or "English". Picking one
/// switches the app at once and closes the sheet.
class const LanguageSheet({super.key}) extends StatelessWidget {
  /// Maestro's handles: `language.sheet.phone`, `.spanish`, `.english`.
  static const identifier = 'language.sheet';

  /// Opens the sheet over [context], with the [LanguageCubit] it finds there.
  static Future<void> show(BuildContext context) {
    final cubit = context.read<LanguageCubit>();
    return showRondaSheet<void>(
      context: context,
      builder: (_) =>
          BlocProvider.value(value: cubit, child: const LanguageSheet()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final spacing = context.appSpacing;
    final picked = context.select<LanguageCubit, AppLanguage?>(
      (cubit) => cubit.state.language,
    );

    Widget choice(String name, AppLanguage? language) {
      final selected = picked == language;
      return MergeSemantics(
        child: Semantics(
          identifier: '$identifier.$name',
          selected: selected,
          child: ListTile(
            title: Text(l10n.languageName(language)),
            trailing: selected ? const Icon(Icons.check) : null,
            onTap: () {
              unawaited(context.read<LanguageCubit>().languagePicked(language));
              Navigator.of(context).pop();
            },
          ),
        ),
      );
    }

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsetsDirectional.symmetric(vertical: spacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsetsDirectional.symmetric(
                horizontal: spacing.md,
                vertical: spacing.sm,
              ),
              child: Semantics(
                header: true,
                child: Text(
                  l10n.settingsLanguageRow,
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
            ),
            choice('phone', null),
            choice('spanish', AppLanguage.spanish),
            choice('english', AppLanguage.english),
          ],
        ),
      ),
    );
  }
}
