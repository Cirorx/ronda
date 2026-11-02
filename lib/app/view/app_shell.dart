import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:ronda/app/cubit/admin_access_cubit.dart';
import 'package:ronda/app/cubit/unread_reports_cubit.dart';
import 'package:ronda/l10n/l10n.dart';
import 'package:ronda/safety_queue/widgets/safety_queue_link.dart';
import 'package:ronda_ui/ronda_ui.dart';

/// The navigation around the tabs: Mi ronda, Cerca, Ajustes and, for the
/// admin only, Admin. On a phone or a tablet they sit in the bottom bar; on
/// a desktop window ([WindowSize.expanded]) they stand in a rail at the
/// start side, the same ones, so the screen keeps its height for content.
/// Each tab presses in from touch-down; changing tabs is navigation, so it
/// is never felt.
///
/// The Admin tab follows [AdminAccessCubit]: it shows once the signed-in
/// account's token carries the admin claim and goes when a renewed token no
/// longer does. It is the last branch, so hiding it moves no other tab. It
/// carries the count of reports the admin hasn't seen
/// ([UnreadReportsCubit]), the only alert of a new one.
class const AppShell({
  required final StatefulNavigationShell navigationShell,
  super.key,
}) extends StatelessWidget {
  /// The Admin tab's branch in the router's shell.
  static const adminBranch = 3;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final admin = context.select<AdminAccessCubit, bool>(
      (cubit) => cubit.state == AdminAccess.admin,
    );
    final unread = context.watch<UnreadReportsCubit>().state;
    final tabs = <(IconData, IconData, String)>[
      (Icons.groups_outlined, Icons.groups, l10n.myRondaTabLabel),
      (Icons.near_me_outlined, Icons.near_me, l10n.cercaTabLabel),
      (Icons.settings_outlined, Icons.settings, l10n.settingsTabLabel),
      // Kept while it is the open tab, for the frame before the router
      // moves someone without the claim away from it.
      if (admin || navigationShell.currentIndex == adminBranch)
        (
          Icons.admin_panel_settings_outlined,
          Icons.admin_panel_settings,
          l10n.adminTabLabel,
        ),
    ];

    // The Admin tab's icon carries the unread count; its label says it too.
    Widget tabIcon(int index, IconData icon) => index == adminBranch
        ? UnreadBadge(count: unread, child: Icon(icon))
        : Icon(icon);
    String tabLabel(int index, String label) =>
        index == adminBranch && unread > 0
        ? '$label, ${l10n.safetyUnread(unread)}'
        : label;

    void select(int index) => navigationShell.goBranch(
      index,
      // Tapping the open tab again returns it to its first screen.
      initialLocation: index == navigationShell.currentIndex,
    );

    if (context.windowSize == WindowSize.expanded) {
      return Scaffold(
        // The rail is reached before the tab's content, as the bottom bar
        // is read after it: the rail comes first on the line.
        body: FocusTraversalGroup(
          policy: OrderedTraversalPolicy(),
          child: Row(
            children: [
              FocusTraversalOrder(
                order: const NumericFocusOrder(0),
                child: FocusTraversalGroup(
                  child: SafeArea(
                    child: NavigationRail(
                      selectedIndex: navigationShell.currentIndex,
                      onDestinationSelected: select,
                      destinations: [
                        for (final (index, (icon, selectedIcon, label))
                            in tabs.indexed)
                          NavigationRailDestination(
                            icon: PressScale(child: tabIcon(index, icon)),
                            selectedIcon: PressScale(
                              child: tabIcon(index, selectedIcon),
                            ),
                            label: Semantics(
                              label: tabLabel(index, label),
                              excludeSemantics: true,
                              child: Text(label),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              Expanded(
                child: FocusTraversalOrder(
                  order: const NumericFocusOrder(1),
                  child: FocusTraversalGroup(child: navigationShell),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: select,
        destinations: [
          for (final (index, (icon, selectedIcon, label)) in tabs.indexed)
            PressScale(
              child: NavigationDestination(
                icon: tabIcon(index, icon),
                selectedIcon: tabIcon(index, selectedIcon),
                label: label,
                tooltip: tabLabel(index, label),
              ),
            ),
        ],
      ),
    );
  }
}
