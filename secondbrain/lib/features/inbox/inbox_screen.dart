import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../core/dates.dart';
import '../../data/database.dart';
import '../common/dialogs.dart';
import '../common/labels.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/meta_label.dart';
import '../knowledge/item_detail_screen.dart';
import '../knowledge/widgets/type_icons.dart';
import '../shell/app_shell.dart';

/// Inbox (UI_SPEC §5, UI-10).
///
/// Everything captured but not yet organized. Quick actions per item: link to
/// a project, add tags, change the type, open and edit, archive.
class InboxScreen extends StatefulWidget {
  const InboxScreen({super.key});

  @override
  State<InboxScreen> createState() => _InboxScreenState();
}

class _InboxScreenState extends State<InboxScreen> {
  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return StreamBuilder<List<Item>>(
      stream: scope.items.watchList(onlyInbox: true, onlyArchived: false),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const LoadingView();
        }
        final items = snap.data!;
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.inbox_outlined,
            title: l.emptyInbox,
            message: l.emptyInboxHint,
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return _InboxTile(
              item: item,
              onOpen: () => openDetail(
                context,
                title: item.title.isEmpty ? item.bodyMd : item.title,
                builder: (_) => ItemDetailScreen(itemId: item.id),
              ),
              onAction: (action) => _handle(context, item, action),
            );
          },
        );
      },
    );
  }

  Future<void> _handle(
    BuildContext context,
    Item item,
    InboxAction action,
  ) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    switch (action) {
      case InboxAction.linkProject:
        final projectId = await _pickProject(context);
        if (projectId == null) return;
        await scope.items.update(item, projectId: projectId);
        if (!context.mounted) return;
        showToast(context, l.projectLinked);
      case InboxAction.addTags:
        final tags = await askForTags(context);
        if (tags == null) return;
        final existing = await scope.items.tagsOf(item.id);
        final names = [
          ...existing.map((t) => t.name),
          ...tags.where((t) => !existing.any((e) => e.name == t)),
        ];
        await scope.items.update(item, tags: names);
        if (!context.mounted) return;
        showToast(context, l.tagsUpdated);
      case InboxAction.changeType:
        final typeId = await _pickType(context);
        if (typeId == null) return;
        await scope.items.update(item, typeId: typeId);
        if (!context.mounted) return;
        showToast(context, l.typeChanged);
      case InboxAction.archive:
        await scope.items.update(item, isArchived: true);
        if (!context.mounted) return;
        showToast(context, l.archived);
      case InboxAction.organize:
        // Organized = out of the inbox (linked to a project or typed).
        await scope.items.update(item, isInbox: false);
        if (!context.mounted) return;
        showToast(context, l.itemOrganized);
    }
  }

  Future<String?> _pickProject(BuildContext context) async {
    final scope = AppScope.of(context);
    final projects = await scope.projects.all();
    if (!context.mounted) return null;
    return showOptionSheet<String>(
      context,
      options: [
        for (final p in projects)
          SheetOption(p.id, p.name, icon: Icons.folder_outlined),
      ],
    );
  }

  Future<String?> _pickType(BuildContext context) async {
    final scope = AppScope.of(context);
    final types = await scope.itemTypes.builtin();
    if (!context.mounted) return null;
    return showOptionSheet<String>(
      context,
      options: [
        for (final t in types) SheetOption(t.id, t.name, icon: iconForType(t.name)),
      ],
    );
  }
}

/// Quick actions available on every inbox item.
enum InboxAction { linkProject, addTags, changeType, archive, organize }

class _InboxTile extends StatelessWidget {
  const _InboxTile({
    required this.item,
    required this.onOpen,
    required this.onAction,
  });

  final Item item;
  final VoidCallback onOpen;
  final ValueChanged<InboxAction> onAction;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final title = itemDisplayTitle(context, item);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: InkWell(
        onTap: onOpen,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                  PopupMenuButton<InboxAction>(
                    tooltip: l.quickActions,
                    onSelected: onAction,
                    itemBuilder: (context) => [
                      PopupMenuItem(
                        value: InboxAction.organize,
                        child: Text(l.markAsOrganized),
                      ),
                      PopupMenuItem(
                        value: InboxAction.linkProject,
                        child: Text(l.linkToProject),
                      ),
                      PopupMenuItem(
                        value: InboxAction.addTags,
                        child: Text(l.addTag),
                      ),
                      PopupMenuItem(
                        value: InboxAction.changeType,
                        child: Text(l.changeType),
                      ),
                      PopupMenuItem(
                        value: InboxAction.archive,
                        child: Text(l.archive),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  if ((item.sourceApp ?? '').isNotEmpty ||
                      (item.sourceTitle ?? '').isNotEmpty)
                    MetaLabel(
                      icon: Icons.open_in_new,
                      text: (item.sourceTitle ?? item.sourceApp ?? '').trim(),
                    ),
                  MetaLabel(
                    icon: Icons.schedule_outlined,
                    text: item.capturedAt != null
                        ? formatRelativeTime(item.capturedAt!)
                        : formatRelativeTime(item.createdAt),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
