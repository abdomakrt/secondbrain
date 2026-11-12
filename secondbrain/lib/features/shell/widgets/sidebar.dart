import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../app_shell.dart';

/// Desktop sidebar (UI_SPEC §7: `Sidebar`).
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.current,
    required this.onSelect,
    required this.onOpenSearch,
  });

  final AppSection current;
  final ValueChanged<AppSection> onSelect;
  final void Function([String?]) onOpenSearch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);

    return Container(
      width: 240,
      color: theme.colorScheme.surfaceContainerLow,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
            child: Row(
              children: [
                Icon(Icons.psychology_alt_outlined,
                    color: theme.colorScheme.primary, size: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    l.appTitle,
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: _SidebarButton(
              icon: Icons.search,
              label: l.search,
              selected: current == AppSection.search,
              onTap: () => onOpenSearch(),
            ),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                _SidebarButton(
                  icon: Icons.home_outlined,
                  label: l.dashboardTitle,
                  selected: current == AppSection.dashboard,
                  onTap: () => onSelect(AppSection.dashboard),
                ),
                _SidebarButton(
                  icon: Icons.checklist_outlined,
                  label: l.tasksTitle,
                  selected: current == AppSection.tasks,
                  onTap: () => onSelect(AppSection.tasks),
                ),
                _SidebarButton(
                  icon: Icons.folder_outlined,
                  label: l.projectsTitle,
                  selected: current == AppSection.projects,
                  onTap: () => onSelect(AppSection.projects),
                ),
                _SidebarButton(
                  icon: Icons.lightbulb_outline,
                  label: l.knowledgeTitle,
                  selected: current == AppSection.knowledge,
                  onTap: () => onSelect(AppSection.knowledge),
                ),
                _SidebarButton(
                  icon: Icons.school_outlined,
                  label: l.coursesTitle,
                  selected: current == AppSection.courses,
                  onTap: () => onSelect(AppSection.courses),
                ),
                _SidebarButton(
                  icon: Icons.inbox_outlined,
                  label: l.inboxTitle,
                  selected: current == AppSection.inbox,
                  onTap: () => onSelect(AppSection.inbox),
                ),
                const Divider(height: 24),
                _SidebarButton(
                  icon: Icons.settings_outlined,
                  label: l.settingsTitle,
                  selected: current == AppSection.settings,
                  onTap: () => onSelect(AppSection.settings),
                ),
                _SidebarButton(
                  icon: Icons.delete_outline,
                  label: l.trashTitle,
                  selected: current == AppSection.trash,
                  onTap: () => onSelect(AppSection.trash),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarButton extends StatelessWidget {
  const _SidebarButton({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Material(
        color: selected
            ? theme.colorScheme.primaryContainer
            : Colors.transparent,
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected
                      ? theme.colorScheme.onPrimaryContainer
                      : theme.colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontWeight: selected ? FontWeight.bold : null,
                      color: selected
                          ? theme.colorScheme.onPrimaryContainer
                          : null,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
