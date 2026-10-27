import 'package:material_ui/material_ui.dart';
import 'package:ronda/l10n/l10n.dart';

/// The Ajustes tab. A placeholder until the settings exist.
class const SettingsPage({super.key}) extends StatelessWidget {
  static const path = '/ajustes';

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTabLabel)),
      body: Center(
        child: Text(
          l10n.settingsPlaceholder,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
