import 'dart:io';

import 'package:drift/drift.dart' hide Column;
import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:secondbrain/data/database.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_deps.dart';
import '../../app/app_scope.dart';
import '../../backup/backup_service.dart';
import '../../backup/export_service.dart';
import '../common/widgets/content_width.dart';

/// Backup/restore/export screen (spec §11).
///
/// - إنشاء نسخة: `.sbbackup` (ZIP: manifest + db snapshot + blobs) في مجلد
///   يحدده المستخدم.
/// - التحقق من النسخة (§11.3): استعادة في مجلد مؤقت فقط وفحص السلامة والعدّادات.
/// - استعادة (§11.2): نسخة أمان تلقائية ثم تبديل ذري وحقبة جديدة، ثم تبديل
///   حزمة التبعيات الحية عبر [appDepsSwapRequest].
/// - نسخ تلقائي يومي (اختياري) عبر مفتاح الإعداد `auto_backup_daily`.
/// - تصدير Markdown (§11.4).
class BackupScreen extends StatefulWidget {
  const BackupScreen({super.key});

  @override
  State<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends State<BackupScreen> {
  bool _daily = false;
  bool _busy = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadDaily();
  }

  Future<void> _loadDaily() async {
    final scope = AppScope.of(context);
    final row = await (scope.db.select(
      scope.db.settings,
    )..where((s) => s.key.equals('auto_backup_daily'))).getSingleOrNull();
    if (mounted) setState(() => _daily = row?.value == '1');
  }

  Future<void> _setDaily(bool value) async {
    final scope = AppScope.of(context);
    await scope.gate.write((tx) async {
      final existing = await (tx.db.select(
        tx.db.settings,
      )..where((s) => s.key.equals('auto_backup_daily'))).getSingleOrNull();
      if (existing != null) {
        await (tx.db.update(tx.db.settings)
              ..where((s) => s.key.equals('auto_backup_daily')))
            .write(SettingsCompanion(value: Value(value ? '1' : '0')));
      } else {
        await tx.db
            .into(tx.db.settings)
            .insert(
              SettingsCompanion.insert(
                key: 'auto_backup_daily',
                value: value ? '1' : '0',
              ),
            );
      }
    });
    if (mounted) setState(() => _daily = value);
  }

  /// Runs [action] with a busy spinner; on failure shows a snackbar and
  /// swallows the error (user-facing; details stay in the console log).
  Future<void> _run(Future<void> Function() action) async {
    setState(() => _busy = true);
    try {
      await action();
    } on Object catch (e) {
      debugPrint('backup action failed: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${AppLocalizations.of(context)!.restoreFailed}: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _createBackup() async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final dirPath = await getDirectoryPath();
    if (dirPath == null) return; // المستخدم ألغى الاختيار
    await _run(() async {
      final file = await BackupService(deps: scope.deps)
          .create(destDir: Directory(dirPath));
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('${l.backupDone} ${file.path}')));
      }
    });
  }

  Future<void> _verifyBackup() async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final picked = await openFile();
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    RestoreReport? report;
    await _run(() async {
      report = await BackupService(deps: scope.deps).verify(file);
    });
    if (report == null || !mounted) return;
    final r = report!;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(r.ok ? l.verifyOk : l.restoreFailed),
        content: SingleChildScrollView(
          child: ListBody(
            children: [
              Text('${l.backupIntegrity}: ${r.integrity}'),
              Text('${l.backupCounts}: ${r.counts}'),
              Text(
                '${l.missingBlobs}: ${r.missingBlobs.isEmpty ? l.noMissingBlobs : r.missingBlobs.join(", ")}',
              ),
              Text(
                '${l.corruptBlobs}: ${r.corruptBlobs.isEmpty ? l.noCorruptBlobs : r.corruptBlobs.join(", ")}',
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(AppLocalizations.of(context)!.back),
          ),
        ],
      ),
    );
  }

  Future<void> _restoreBackup() async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final picked = await openFile();
    if (picked == null || !mounted) return;
    final file = File(picked.path);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l.restoreConfirmTitle),
        content: Text(l.restoreConfirmBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(l.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(l.restoreBackup),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (!mounted) return;
    AppDeps? newDeps;
    await _run(() async {
      final result = await BackupService(deps: scope.deps).restore(
        backupFile: file,
        supportDir: scope.deps.supportDir,
        current: scope.deps,
      );
      newDeps = result.deps;
    });
    if (newDeps == null) return;
    // Rebuild the whole app on the restored database connection.
    appDepsSwapRequest.value = newDeps;
    if (mounted) {
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(l.restoreDone)));
    }
  }

  Future<void> _exportMarkdown() async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final dirPath = await getDirectoryPath();
    if (dirPath == null) return;
    await _run(() async {
      await ExportService(
        db: scope.db,
        tags: scope.tags,
        blobsDir: scope.attachments.blobsDir,
      ).export(Directory(dirPath));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('$l.exportDone $dirPath')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(title: Text(l.backupTitle)),
      body: ContentWidth(
        maxWidth: ContentWidths.form,
        child: AbsorbPointer(
          absorbing: _busy,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              FilledButton.icon(
                icon: const Icon(Icons.backup),
                label: Text(l.createBackup),
                onPressed: _createBackup,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.verified_outlined),
                label: Text(l.verifyBackup),
                onPressed: _verifyBackup,
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                icon: const Icon(Icons.restore),
                label: Text(l.restoreBackup),
                onPressed: _restoreBackup,
              ),
              const Divider(height: 32),
              SwitchListTile(
                title: Text(l.autoDailyBackup),
                value: _daily,
                onChanged: (v) => _setDaily(v),
              ),
              const Divider(height: 32),
              OutlinedButton.icon(
                icon: const Icon(Icons.file_upload_outlined),
                label: Text(l.exportMd),
                onPressed: _exportMarkdown,
              ),
              if (_busy)
                const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
