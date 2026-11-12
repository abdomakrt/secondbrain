import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../../app/app_scope.dart';
import '../../../data/database.dart';
import '../dialogs.dart';
import 'common_widgets.dart';
import 'db_stream_builder.dart';

/// The folders linked to a project or a course (spec §12).
///
/// Desktop only: on Android the section is not shown. The folders are never
/// indexed — the app only remembers where the material lives, and checks
/// that the folder still exists when it is opened.
class LinkedFoldersSection extends StatelessWidget {
  const LinkedFoldersSection({
    super.key,
    required this.ownerType,
    required this.ownerId,
  });

  /// 'project' or 'course'.
  final String ownerType;
  final String ownerId;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    if (!scope.opener.isSupported) return const SizedBox.shrink();

    return DbStreamBuilder<List<LocalPath>>(
      streamFactory: () => scope.localPaths.watchFor(ownerType, ownerId),
      builder: (context, snap) {
        final folders = snap.data ?? const <LocalPath>[];
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    l.linkedFolders,
                    style: Theme.of(context)
                        .textTheme
                        .titleSmall
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.create_new_folder_outlined),
                  label: Text(l.addFolder),
                  onPressed: () => _addFolder(context),
                ),
              ],
            ),
            if (folders.isEmpty)
              Text(
                l.noFolders,
                style: Theme.of(context).textTheme.bodySmall,
              )
            else
              for (final folder in folders)
                _FolderTile(folder: folder),
          ],
        );
      },
    );
  }

  /// Picks a folder and links it (asking for an optional label).
  Future<void> _addFolder(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final path = await getDirectoryPath(confirmButtonText: l.addFolder);
    if (path == null || path.isEmpty) return;
    if (!context.mounted) return;
    final label = await _askLabel(context, path);
    if (label == null) return;
    if (!context.mounted) return;
    await scope.localPaths.add(
      ownerType: ownerType,
      ownerId: ownerId,
      path: path,
      label: label.isEmpty ? null : label,
    );
  }

  /// Asks for an optional name for the folder.
  Future<String?> _askLabel(BuildContext context, String path) {
    final l = AppLocalizations.of(context)!;
    return showTextPrompt(
      context,
      title: l.folderLabel,
      hint: path,
      confirmLabel: l.addFolder,
    );
  }
}

class _FolderTile extends StatelessWidget {
  const _FolderTile({required this.folder});

  final LocalPath folder;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final exists = Directory(folder.path).existsSync();
    final label = (folder.label ?? '').isNotEmpty ? folder.label! : folder.path;

    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        exists ? Icons.folder_outlined : Icons.folder_off_outlined,
        color: exists ? theme.colorScheme.primary : theme.colorScheme.error,
      ),
      title: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.ltr,
      ),
      subtitle: Text(
        exists ? folder.path : '${l.folderMissing}\n${folder.path}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textDirection: TextDirection.ltr,
        style: exists
            ? theme.textTheme.bodySmall
            : theme.textTheme.bodySmall
                ?.copyWith(color: theme.colorScheme.error),
      ),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            tooltip: l.openFolder,
            icon: const Icon(Icons.open_in_new),
            onPressed: () => _open(context),
          ),
          IconButton(
            tooltip: l.copyPath,
            icon: const Icon(Icons.copy_all_outlined),
            onPressed: () => _copy(context),
          ),
          IconButton(
            tooltip: l.removeFolder,
            icon: const Icon(Icons.link_off),
            onPressed: () => _remove(context),
          ),
        ],
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final ok = await scope.opener.openPath(folder.path);
    if (!context.mounted || ok) return;
    showToast(context, l.folderOpenFailed);
  }

  Future<void> _copy(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    await Clipboard.setData(ClipboardData(text: folder.path));
    if (!context.mounted) return;
    showToast(context, l.pathCopied);
  }

  Future<void> _remove(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final confirmed = await confirmDialog(
      context,
      title: l.removeFolder,
      message: l.removeFolderConfirm,
      confirmLabel: l.removeFolder,
      destructive: true,
    );
    if (!confirmed) return;
    await scope.localPaths.remove(folder.id);
  }
}
