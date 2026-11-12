import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../app_shell.dart';

/// Android bottom navigation (UI_SPEC §7: `BottomNavigation`).
///
/// «المزيد» opens a sheet with the remaining sections (courses, inbox,
/// settings, trash).
class BottomNavigation extends StatelessWidget {
  const BottomNavigation({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onMore,
  });

  final AppSection current;
  final ValueChanged<AppSection> onSelect;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final items = <NavigationDestination>[
      NavigationDestination(
        icon: const Icon(Icons.home_outlined),
        selectedIcon: const Icon(Icons.home),
        label: l.dashboardTitle,
      ),
      NavigationDestination(
        icon: const Icon(Icons.checklist_outlined),
        selectedIcon: const Icon(Icons.checklist),
        label: l.tasksTitle,
      ),
      NavigationDestination(
        icon: const Icon(Icons.folder_outlined),
        selectedIcon: const Icon(Icons.folder),
        label: l.projectsTitle,
      ),
      NavigationDestination(
        icon: const Icon(Icons.lightbulb_outline),
        selectedIcon: const Icon(Icons.lightbulb),
        label: l.knowledgeTitle,
      ),
      NavigationDestination(
        icon: const Icon(Icons.more_horiz),
        label: l.more,
      ),
    ];

    int index = switch (current) {
      AppSection.dashboard => 0,
      AppSection.tasks => 1,
      AppSection.projects => 2,
      AppSection.knowledge => 3,
      _ => 4,
    };

    return NavigationBar(
      selectedIndex: index,
      onDestinationSelected: (i) {
        if (i == 4) {
          onMore();
          return;
        }
        onSelect(switch (i) {
          0 => AppSection.dashboard,
          1 => AppSection.tasks,
          2 => AppSection.projects,
          _ => AppSection.knowledge,
        });
      },
      destinations: items,
    );
  }
}
