import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../importers/keep_importer.dart';
import '../common/widgets/common_widgets.dart';

/// Google Keep import (UI_SPEC §5, UI-14).
///
/// The flow is: download the Takeout archive, choose the ZIP, inspect it,
/// review the preview, choose what to import, confirm, and read the report.
///
/// The importer engine itself ships in the second release (TASK_TRACKER —
/// Phase 3 deferred by the owner's decision). Until then the screen walks the
/// user through the steps and says plainly what is not available yet — it
/// never claims a feature that was not tested against a real Takeout file.
class KeepImportScreen extends StatefulWidget {
  const KeepImportScreen({super.key, this.importer});

  final KeepImporter? importer;

  @override
  State<KeepImportScreen> createState() => _KeepImportScreenState();
}

class _KeepImportScreenState extends State<KeepImportScreen> {
  File? _archive;
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      appBar: AppBar(title: Text(l.keepImport)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    l.keepImportDeferred,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    l.keepImportDeferredHint,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            l.keepImportSteps,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          _Steps(steps: l.keepImportStepsList.split('\n')),
          const SizedBox(height: 16),
          Text(
            l.keepImportPreserves,
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          ...l.keepImportPreservesList.split('\n').map(
            (s) => ListTile(
              dense: true,
              leading: const Icon(Icons.check_circle_outline),
              title: Text(s),
            ),
          ),
          const Divider(height: 32),
          FilledButton.icon(
            onPressed: _busy ? null : _pickArchive,
            icon: const Icon(Icons.folder_open),
            label: Text(l.chooseKeepArchive),
          ),
          if (_archive != null) ...[
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.archive_outlined),
              title: Text(_archive!.path.split('/').last),
              subtitle: Text(l.keepArchiveSelected),
              trailing: IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => setState(() => _archive = null),
              ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 16),
            const LoadingView(),
          ],
        ],
      ),
    );
  }

  Future<void> _pickArchive() async {
    final l = AppLocalizations.of(context)!;
    final importer = widget.importer;
    if (importer == null || !importer.isAvailable) {
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: Text(l.keepImportDeferred),
          content: Text(
            importer?.unavailableReason ?? l.keepImportDeferredHint,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: Text(l.close),
            ),
          ],
        ),
      );
      return;
    }
    final file = await openFile(acceptedTypeGroups: const [
      XTypeGroup(label: 'ZIP', extensions: ['zip']),
    ]);
    if (file == null) return;
    setState(() => _busy = true);
    try {
      await importer.preview(File(file.path));
      if (!mounted) return;
      setState(() => _archive = File(file.path));
    } on Object catch (e) {
      debugPrint('keep preview failed: $e');
      if (!mounted) return;
      showErrorWithRetry(context, message: l.keepImportFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}

class _Steps extends StatelessWidget {
  const _Steps({required this.steps});

  final List<String> steps;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < steps.length; i++)
          ListTile(
            dense: true,
            leading: CircleAvatar(
              radius: 12,
              child: Text('${i + 1}'),
            ),
            title: Text(steps[i]),
          ),
      ],
    );
  }
}
