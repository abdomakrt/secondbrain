import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../data/database.dart';
import '../common/widgets/common_widgets.dart';
import 'widgets/type_icons.dart';

/// Deleted (tombstoned) items. Restore only — hard delete never happens
/// (spec §7.4); retention/purge is handled by backup (later phase).
class TrashScreen extends StatelessWidget {
  const TrashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.trash)),
      body: StreamBuilder<List<Item>>(
        stream: scope.items.watchTrash(),
        builder: (context, snap) {
          final items = snap.data ?? const <Item>[];
          if (items.isEmpty) {
            return EmptyState(
              icon: Icons.delete_outline,
              title: l.emptyTrash,
            );
          }
          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, i) => ListTile(
              leading: const Icon(Icons.delete_outline),
              title: Text(
                items[i].title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(formatStamp(items[i].deletedAt ?? 0)),
              trailing: TextButton.icon(
                icon: const Icon(Icons.restore),
                label: Text(l.restore),
                onPressed: () => scope.items.restore(items[i].id),
              ),
            ),
          );
        },
      ),
    );
  }
}
