import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/app/app.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/settings/view/notifications_page.dart';
import 'package:ronda/settings/view/report_page.dart';
import 'package:ronda/settings/view/your_data_page.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The Ajustes tab: Avisos, "Contar algo que pasó" and "Tus datos", each on
/// its own screen under [path], and, set apart by space, "Salir de esta
/// cuenta" after a confirmation. Every row presses in from touch-down.
class const SettingsPage({super.key}) extends StatelessWidget {
  static const path = '/ajustes';

  /// Maestro's handles on the rows.
  static const notificationsIdentifier = 'settings.notifications';
  static const reportIdentifier = 'settings.report';
  static const dataIdentifier = 'settings.data';
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
    }) => MergeSemantics(
      child: Semantics(
        identifier: identifier,
        child: PressScale(
          child: ListTile(
            leading: Icon(icon),
            title: Text(label),
            trailing: opensScreen ? const Icon(Icons.chevron_right) : null,
            onTap: onTap,
          ),
        ),
      ),
    );

    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTabLabel)),
      body: ListView(
        children: [
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
          SizedBox(height: context.appSpacing.lg),
          row(
            signOutIdentifier,
            Icons.logout,
            l10n.settingsSignOutRow,
            () => _confirmSignOut(context),
            opensScreen: false,
          ),
        ],
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
