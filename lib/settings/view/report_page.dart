import 'package:contact_repository/contact_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/settings/cubit/contact_cubit.dart';
import 'package:ronda/settings/widgets/contact_failure_note.dart';
import 'package:ronda/settings/widgets/email_button.dart';
import 'package:ronda/settings/widgets/helpline_block.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// Ajustes → "Contar algo que pasó": who reads it, where to write, and the
/// helplines.
class const ReportPage({super.key}) extends StatelessWidget {
  /// The route's segment under `/ajustes`.
  static const segment = 'contar';
  static const path = '/ajustes/$segment';

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) =>
          ContactCubit(contactRepository: context.read<ContactRepository>()),
      child: const ReportView(),
    );
  }
}

/// "Contá qué pasó. Lo lee una persona, no un programa…", the address with
/// [Escribir un mail], then the [HelplineBlock].
class const ReportView({super.key}) extends StatelessWidget {
  /// Maestro's handle on [Escribir un mail].
  static const emailIdentifier = 'report.email';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final textTheme = Theme.of(context).textTheme;
    final spacing = context.appSpacing;
    final email = context.select<ContactCubit, String>(
      (cubit) => cubit.state.email,
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsReportRow)),
      body: ListView(
        padding: EdgeInsets.all(spacing.md),
        children: [
          Text(l10n.reportBody, style: textTheme.bodyLarge),
          SizedBox(height: spacing.sm),
          SelectableText(l10n.reportWriteTo(email), style: textTheme.bodyLarge),
          SizedBox(height: spacing.md),
          EmailButton(
            identifier: emailIdentifier,
            onPressed: () => context.read<ContactCubit>().emailTapped(
              subject: l10n.reportEmailSubject,
            ),
          ),
          const ContactFailureNote(failure: ContactStatus.emailFailed),
          SizedBox(height: spacing.lg),
          const HelplineBlock(),
        ],
      ),
    );
  }
}
