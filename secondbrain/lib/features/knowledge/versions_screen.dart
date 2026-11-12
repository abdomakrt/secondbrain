import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../data/database.dart';
import '../common/widgets/common_widgets.dart';
import 'widgets/type_icons.dart';

/// The last kept versions of an item (spec §7.5) with restore.
/// Restoring is itself a new edit (it snapshots the current state first).
class VersionsScreen extends StatelessWidget {
  const VersionsScreen({super.key, required this.itemId});

  final String itemId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l.versions)),
      body: FutureBuilder<List<ItemVersion>>(
        future: (scope.db.select(scope.db.itemVersions)
              ..where((v) => v.itemId.equals(itemId))
              ..orderBy([(v) => OrderingTerm.desc(v.savedAt)]))
            .get(),
        builder: (context, snap) {
          final versions = snap.data ?? const <ItemVersion>[];
          if (versions.isEmpty) {
            return EmptyState(
              icon: Icons.history,
              title: l.noVersions,
            );
          }
          return ListView.builder(
            itemCount: versions.length,
            itemBuilder: (context, i) {
              final v = versions[i];
              return ListTile(
                title: Text(
                  v.title.isEmpty ? l.bodyLabel : v.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  '${formatStamp(v.savedAt)} · ${v.bodyMd.length}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                trailing: TextButton(
                  child: Text(l.restoreVersion),
                  onPressed: () async {
                    final item = await scope.items.byId(itemId);
                    if (item == null) return;
                    await scope.items.update(
                      item,
                      title: v.title,
                      bodyMd: v.bodyMd,
                    );
                    if (context.mounted) Navigator.of(context).pop();
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }
}
