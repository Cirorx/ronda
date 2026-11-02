import 'dart:async';

import 'package:auth_repository/auth_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/my_data/my_data.dart';
import 'package:ronda/settings/cubit/account_cubit.dart';
import 'package:ronda/settings/view/notifications_page.dart';
import 'package:ronda/settings/view/report_page.dart';
import 'package:ronda/settings/view/your_data_page.dart';
import 'package:ronda/settings/widgets/account_tile.dart';
import 'package:ronda/settings/widgets/language_sheet.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The Ajustes tab: Mis datos, Avisos, "Contar algo que pasó" and "Tus
/// datos", each on its own screen under [path], the language in a sheet,
/// and, set apart by space, how this account signs in ([AccountTile]) and
/// "Salir de esta cuenta" after a confirmation. Every row presses in from
/// touch-down.
class const SettingsPage({super.key}) extends StatelessWidget {
  static const path = '/ajustes';

  /// Maestro's handles on the rows.
  static const myDataIdentifier = 'settings.myData';
  static const notificationsIdentifier = 'settings.notifications';
  static const reportIdentifier = 'settings.report';
  static const dataIdentifier = 'settings.data';
  static const languageIdentifier = 'settings.language';
  static const signOutIdentifier = 'settings.signOut';

  /// The sign-out confirmation's prefix: `signOut.primary` signs out,
  /// `signOut.secondary` closes it.
  static const signOutSheetIdentifier = 'signOut';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    Widget row(
      String identifier,
      IconData icon,
      String label,
      VoidCallback onTap, {
      bool opensScreen = true,
      String? value,
    }) => MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: PressScale(
          // A full-width row: the list would clip a ring outside it.
          ringInset: true,
          child: ListTile(
            leading: Icon(icon),
            title: Text(label),
            subtitle: value == null ? null : Text(value),
            trailing: opensScreen ? const Icon(Icons.chevron_right) : null,
            onTap: onTap,
          ),
        ),
      ),
    );

    return BlocProvider(
      create: (context) =>
          AccountCubit(authRepository: context.read<AuthRepository>()),
      child: Scaffold(
        appBar: AppBar(title: Text(l10n.settingsTabLabel)),
        body: ReadableColumn(
          child: ListView(
            children: [
              row(
                myDataIdentifier,
                Icons.person_outline,
                l10n.myDataTitle,
                () => context.go(MyDataPage.settingsPath),
              ),
              row(
                notificationsIdentifier,
                Icons.notifications_outlined,
                l10n.settingsNotificationsRow,
                () => context.go(NotificationsPage.path),
              ),
              row(
                reportIdentifier,
                Icons.support_outlined,
                l10n.settingsReportRow,
                () => context.go(ReportPage.path),
              ),
              row(
                dataIdentifier,
                Icons.description_outlined,
                l10n.settingsDataRow,
                () => context.go(YourDataPage.path),
              ),
              row(
                languageIdentifier,
                Icons.translate,
                l10n.settingsLanguageRow,
                () => LanguageSheet.show(context),
                opensScreen: false,
                value: context.select<LanguageCubit, String>(
                  (cubit) => l10n.languageName(cubit.state.language),
                ),
              ),
              SizedBox(height: context.appSpacing.lg),
              const AccountTile(),
              row(
                signOutIdentifier,
                Icons.logout,
                l10n.settingsSignOutRow,
                () => _confirmSignOut(context),
                opensScreen: false,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// "¿Salís de esta cuenta?": «Salir», felt as it is tapped, signs out
  /// through the [AppBloc], which forgets this phone's push token first; the
  /// router then shows the welcome screen. «Mejor no» only closes the sheet.
  Future<void> _confirmSignOut(BuildContext context) {
    final l10n = context.l10n;
    final appBloc = context.read<AppBloc>();
    final navigator = Navigator.of(context);
    return StepSheet(
      identifier: signOutSheetIdentifier,
      title: l10n.signOutTitle,
      body: l10n.signOutBody,
      primaryLabel: l10n.signOutConfirm,
      onPrimary: () {
        unawaited(RondaHaptics.commit());
        navigator.pop();
        appBloc.add(const AppSignOutRequested());
      },
      secondaryLabel: l10n.signOutCancel,
      onSecondary: navigator.pop,
    ).show<void>(context);
  }
}
