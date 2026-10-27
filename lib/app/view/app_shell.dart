import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:ronda/l10n/l10n.dart';

/// The bottom navigation around the three tabs: Mi ronda, Cerca, Ajustes.
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
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: l10n.myRondaTabLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.near_me_outlined),
            selectedIcon: const Icon(Icons.near_me),
            label: l10n.cercaTabLabel,
          ),
          NavigationDestination(
            icon: const Icon(Icons.settings_outlined),
            selectedIcon: const Icon(Icons.settings),
            label: l10n.settingsTabLabel,
          ),
        ],
      ),
    );
  }
}
