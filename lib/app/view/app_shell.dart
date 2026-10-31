import 'package:go_router/go_router.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The bottom navigation around the three tabs: Mi ronda, Cerca, Ajustes.
/// Each tab presses in from touch-down; changing tabs is navigation, so it
/// is never felt.
class const AppShell({
  required final StatefulNavigationShell navigationShell,
  super.key,
}) extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: (index) => navigationShell.goBranch(
          index,
          // Tapping the open tab again returns it to its first screen.
          initialLocation: index == navigationShell.currentIndex,
        ),
        destinations: [
          for (final (icon, selectedIcon, label) in [
            (Icons.groups_outlined, Icons.groups, l10n.myRondaTabLabel),
            (Icons.near_me_outlined, Icons.near_me, l10n.cercaTabLabel),
            (Icons.settings_outlined, Icons.settings, l10n.settingsTabLabel),
          ])
            PressScale(
              child: NavigationDestination(
                icon: Icon(icon),
                selectedIcon: Icon(selectedIcon),
                label: label,
              ),
            ),
        ],
      ),
    );
  }
}
