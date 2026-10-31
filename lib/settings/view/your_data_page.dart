import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/settings/cubit/contact_cubit.dart';
import 'package:ronda/settings/widgets/contact_failure_note.dart';
import 'package:ronda/settings/widgets/email_button.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Ajustes → "Tus datos": what Ronda keeps, what it doesn't, where, and how
/// to have it changed or deleted (by writing to Ronda).
class const YourDataPage({super.key}) extends StatelessWidget {
  /// The route's segment under `/ajustes`.
  static const segment = 'datos';
  static const path = '/ajustes/$segment';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ContactCubit(contactRepository: context.read<ContactRepository>()),
      child: const YourDataView(),
    );
  }
}

/// "Lo que Ronda guarda de vos", "Lo que no guardamos", where it lives, and
/// "Para cambiar o borrar tus datos, escribinos a …" with [Escribir un
/// mail]. The mail carries the member's account id, so a person can find
/// it.
class const YourDataView({super.key}) extends StatelessWidget {
  /// Maestro's handle on [Escribir un mail].
  static const emailIdentifier = 'data.email';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final email = context.select<ContactCubit, String>(
      (cubit) => cubit.state.email,
    );

    Widget heading(String text) => Semantics(
      header: true,
      child: Text(text, style: textTheme.titleMedium),
    );

    Widget item(String text) => Padding(
      padding: EdgeInsets.only(top: spacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ExcludeSemantics(child: Text('•', style: textTheme.bodyLarge)),
          SizedBox(width: spacing.xs),
          Expanded(child: Text(text, style: textTheme.bodyLarge)),
        ],
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsDataRow)),
      body: ListView(
        padding: EdgeInsets.all(spacing.md),
        children: [
          heading(l10n.dataKeepTitle),
          for (final text in [
            l10n.dataKeepProfile,
            l10n.dataKeepSearch,
            l10n.dataKeepRonda,
            l10n.dataKeepAccount,
            l10n.dataKeepTerms,
          ])
            item(text),
          SizedBox(height: spacing.lg),
          heading(l10n.dataNotKeptTitle),
          for (final text in [l10n.dataNotKeptAudio, l10n.dataNotKeptNeeds])
            item(text),
          SizedBox(height: spacing.lg),
          Text(l10n.termsWhere, style: textTheme.bodyLarge),
          SizedBox(height: spacing.lg),
          SelectableText(l10n.dataChange(email), style: textTheme.bodyLarge),
          SizedBox(height: spacing.md),
          EmailButton(
            identifier: emailIdentifier,
            onPressed: () => context.read<ContactCubit>().emailTapped(
              subject: l10n.dataEmailSubject,
              body: l10n.dataEmailBody(context.read<AppBloc>().state.user.id),
            ),
          ),
          const ContactFailureNote(failure: ContactStatus.emailFailed),
        ],
      ),
    );
  }
}
