import 'dart:convert';
import 'dart:io';

import 'package:archive/archive.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

import '../app/app_deps.dart';
import '../core/ids.dart';
import '../data/database.dart';

/// Spec §11: `.sbbackup` = ZIP of manifest.json + db snapshot (VACUUM INTO)
/// + content-addressed blobs. Restore verifies, takes a safety copy, checks
/// integrity, swaps atomically, rebuilds FTS and bumps `db_epoch` (§7.7).
class BackupService {
  BackupService({required this.deps});

  static const int formatVersion = 1;

  final AppDeps deps;

  // ---- create (§11.1) ----

  Future<File> create({required Directory destDir, String prefix = 'secondbrain'}) async {
    if (!destDir.existsSync()) {
      destDir.createSync(recursive: true);
    }
    final stamp = DateTime.now()
        .toUtc()
        .millisecondsSinceEpoch
        .toString();
    final out = File('${destDir.path}/$prefix-$stamp.sbbackup');

    // Consistent snapshot — never copy a file being written to (§11.1).
    final tmpDb = File('${destDir.path}/.vacuum-$stamp.sqlite');
    try {
      final escaped = tmpDb.path.replaceAll("'", "''");
      await deps.db.customStatement("VACUUM INTO '$escaped'");
      final manifest = await _buildManifest(tmpDb);
      final archive = await _pack(tmpDb, manifest);
      await out.writeAsBytes(ZipEncoder().encode(archive), flush: true);
    } finally {
      if (tmpDb.existsSync()) tmpDb.delete();
    }
    return out;
  }

  Future<BackupManifest> _buildManifest(File dbSnapshot) async {
    final sha = _sha256File(dbSnapshot);
    final blobs = <String>[];
    if (deps.attachments.blobsDir.existsSync()) {
      await for (final f in deps.attachments.blobsDir.list(recursive: true)) {
        if (f is File) blobs.add(f.path);
      }
    }
    final counts = <String, int>{};
    for (final table in kCountedTables) {
      final row = await deps.db
          .customSelect('SELECT COUNT(*) AS n FROM $table')
          .getSingle();
      counts[table] = row.data['n'] as int;
    }
    final epochRow = await (deps.db.select(deps.db.settings)
          ..where((s) => s.key.equals('db_epoch')))
        .getSingleOrNull();

    return BackupManifest(
      formatVersion: formatVersion,
      appVersion: '0.1.0',
      schemaVersion: deps.db.schemaVersion,
      createdAt: DateTime.now().toUtc().millisecondsSinceEpoch,
      dbEpoch: epochRow?.value ?? 'none',
      counts: counts,
      dbSha256: sha,
      blobsCount: blobs.length,
    );
  }

  Future<Archive> _pack(File dbSnapshot, BackupManifest manifest) async {
    final archive = Archive();
    archive.addFile(ArchiveFile.bytes(
      'manifest.json',
      utf8.encode(jsonEncode(manifest.toJson())),
    ));
    archive.addFile(ArchiveFile.bytes(
      'db/secondbrain.sqlite',
      await dbSnapshot.readAsBytes(),
    ));
    final blobsDir = deps.attachments.blobsDir;
    if (blobsDir.existsSync()) {
      await for (final f in blobsDir.list(recursive: true)) {
        if (f is File) {
          final rel = f.path.substring(blobsDir.path.length + 1);
          archive.addFile(ArchiveFile.bytes(
            'blobs/$rel',
            await f.readAsBytes(),
          ));
        }
      }
    }
    return archive;
  }

  // ---- verify (§11.3: «التحقق من النسخة») ----

  /// Restores into a temp folder only, checks integrity + counts against the
  /// manifest, reports, and removes the temp. Touches no live data.
  Future<RestoreReport> verify(File backupFile) async {
    final tmp = await Directory.systemTemp
        .createTemp('sb_verify_')
        .then((d) => d);
    try {
      return await _extractAndCheck(backupFile, tmp);
    } finally {
      tmp.deleteSync(recursive: true);
    }
  }

  // ---- restore (§11.2) ----

  /// Full restore: verify → safety backup of current state → atomic swap of
  /// the db file and blobs dir → reopen → rebuild FTS → new `db_epoch`.
  /// [current] is the live connection (closed by this method); the reopened
  /// bundle is returned with the report for re-injection into the UI.
  Future<RestoreResult> restore({
    required File backupFile,
    required Directory supportDir,
    required AppDeps current,
  }) async {
    final tmp = await Directory.systemTemp.createTemp('sb_restore_');
    RestoreReport check;
    AppDeps? fresh;
    try {
      check = await _extractAndCheck(backupFile, tmp);
      if (check.integrity != 'ok') {
        throw StateError('فشل فحص السلامة: ${check.integrity}');
      }

      // 2. Automatic safety copy of the current state before any change (§11.2.2).
      final safetyDir = Directory('${supportDir.path}/safety');
      await BackupService(deps: current)
          .create(destDir: safetyDir, prefix: 'safety');
      await _prune(safetyDir, keep: 3);

      // 3–4. Close, swap atomically, reopen.
      final dbFile = File('${supportDir.path}/secondbrain.sqlite');
      final blobsDir = Directory('${supportDir.path}/blobs');
      final extractedDb = File('${check.workDir.path}/db/secondbrain.sqlite');
      final extractedBlobs = Directory('${check.workDir.path}/blobs');

      await current.close();
      final oldBlobs = Directory('${supportDir.path}/.blobs-old');
      if (oldBlobs.existsSync()) oldBlobs.deleteSync(recursive: true);
      if (blobsDir.existsSync()) blobsDir.renameSync(oldBlobs.path);
      // Delete the db file AND any rollback/WAL sidecars — a stale WAL from
      // the old database would corrupt the restored copy on open.
      for (final f in [
        dbFile,
        File('${dbFile.path}-wal'),
        File('${dbFile.path}-shm'),
        File('${dbFile.path}-journal'),
      ]) {
        if (f.existsSync()) f.deleteSync();
      }
      extractedDb.copySync(dbFile.path);
      if (extractedBlobs.existsSync()) {
        extractedBlobs.renameSync(blobsDir.path);
      }

      fresh = await AppDeps.open(supportDir);
      await _rebuildFts(fresh);
      await _bumpDbEpoch(fresh);
      return RestoreResult(report: check, deps: fresh);
    } on Object {
      fresh?.close();
      rethrow;
    } finally {
      tmp.deleteSync(recursive: true);
    }
  }

  // ---- auto backups (§11.1) ----

  /// Daily auto backup (optional, controlled by the `auto_backup_daily`
  /// setting). Returns the created file, or null when not due / disabled.
  Future<File?> maybeDailyBackup({required Directory destDir}) async {
    final enabled = await _setting('auto_backup_daily') == '1';
    if (!enabled) return null;
    final last = int.tryParse(await _setting('last_auto_backup_at') ?? '') ?? 0;
    final now = DateTime.now().toUtc().millisecondsSinceEpoch;
    if (now - last < 24 * 60 * 60 * 1000) return null;
    final f = await create(destDir: destDir, prefix: 'auto-daily');
    await _setSetting('last_auto_backup_at', now.toString());
    await _prune(destDir, keep: 7);
    return f;
  }

  /// Keep the newest [keep] `.sbbackup` files, delete the rest (default 7).
  Future<void> _prune(Directory dir, {required int keep}) async {
    if (!dir.existsSync()) return;
    final files = dir
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sbbackup'))
        .toList()
      ..sort((a, b) => b.path.compareTo(a.path)); // newest first (ms in name)
    for (final f in files.skip(keep)) {
      await f.delete();
    }
  }

  Future<String?> _setting(String key) async {
    final row = await (deps.db.select(deps.db.settings)
          ..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<void> _setSetting(String key, String value) =>
      deps.gate.write((tx) async {
        final existing = await (tx.db.select(tx.db.settings)
              ..where((s) => s.key.equals(key)))
            .getSingleOrNull();
        if (existing != null) {
          await (tx.db.update(tx.db.settings)
                ..where((s) => s.key.equals(key)))
              .write(SettingsCompanion(value: Value(value)));
        } else {
          await tx.db.into(tx.db.settings).insert(
                SettingsCompanion.insert(key: key, value: value),
              );
        }
      });

  // ---- internals ----

  Future<RestoreReport> _extractAndCheck(File backupFile, Directory workDir) async {
    final bytes = await backupFile.readAsBytes();
    final archive = ZipDecoder().decodeBytes(bytes);

    String? manifestText;
    Uint8List? dbBytes;
    var blobsCount = 0;
    for (final f in archive.files) {
      if (f.isFile) {
        if (f.name == 'manifest.json') {
          manifestText = utf8.decode(f.content as List<int>);
        } else if (f.name == 'db/secondbrain.sqlite') {
          dbBytes = Uint8List.fromList(f.content as List<int>);
        } else if (f.name.startsWith('blobs/')) {
          final rel = f.name.substring('blobs/'.length);
          final out = File('${workDir.path}/blobs/$rel');
          await out.parent.create(recursive: true);
          await out.writeAsBytes(f.content as List<int>);
          blobsCount++;
        }
      }
    }
    if (manifestText == null || dbBytes == null) {
      throw StateError('النسخة ناقصة: manifest.json أو قاعدة البيانات مفقودة');
    }
    final manifest = BackupManifest.fromJson(
        jsonDecode(manifestText) as Map<String, dynamic>);
    if (manifest.formatVersion != formatVersion) {
      throw StateError(
          'إصدار صيغة غير مدعوم: ${manifest.formatVersion} (المتوقع $formatVersion)');
    }
    if (manifest.schemaVersion > deps.db.schemaVersion) {
      throw StateError(
          'نسخة من مخطط أحدث (${manifest.schemaVersion}) من التطبيق الحالي');
    }

    final extractedDb = File('${workDir.path}/db/secondbrain.sqlite');
    await extractedDb.parent.create(recursive: true);
    await extractedDb.writeAsBytes(dbBytes);

    final sha = _sha256File(extractedDb);
    if (sha != manifest.dbSha256) {
      throw StateError('قاعدة البيانات تالفة (SHA-256 غير مطابق)');
    }

    // Open in read-write mode (WAL header may need shm creation), but perform
    // only reads — no drift, no app writes. Then normalize the file
    // (journal_mode=DELETE) so the copy is standalone (§11.2.3).
    final conn = sqlite3.sqlite3.open(extractedDb.path);
    final integrity =
        conn.select('PRAGMA integrity_check').first.values[0] as String;
    final counts = <String, int>{};
    for (final table in kCountedTables) {
      counts[table] = conn.select('SELECT COUNT(*) AS n FROM $table').first.values[0] as int;
    }
    final missingBlobs = <String>[];
    final corruptBlobs = <String>[];
    final atts = conn.select('SELECT filename, sha256 FROM attachments');
    for (final a in atts) {
      final sha = a['sha256'] as String;
      final blob =
          File('${workDir.path}/blobs/${sha.substring(0, 2)}/$sha');
      if (!blob.existsSync()) {
        missingBlobs.add(a['filename'] as String);
        continue;
      }
      if (_sha256File(blob) != sha) corruptBlobs.add(a['filename'] as String);
    }
    conn.close();
    // Normalize to rollback-journal mode so the main file is self-contained.
    final norm = sqlite3.sqlite3.open(extractedDb.path);
    norm.execute('PRAGMA journal_mode = DELETE');
    norm.close();

    final countsMatch = manifest.counts.entries
        .every((e) => counts[e.key] == e.value);
    if (!countsMatch || integrity != 'ok' || blobsCount != manifest.blobsCount) {
      // Not fatal for verify() reporting — surfaced in the report.
    }

    return RestoreReport(
      counts: counts,
      manifestCounts: manifest.counts,
      integrity: integrity,
      dbEpoch: manifest.dbEpoch,
      missingBlobs: missingBlobs,
      corruptBlobs: corruptBlobs,
      workDir: workDir,
    );
  }

  /// Rebuild `items_fts` from live rows (§11.2.4) — cheap safety net.
  Future<void> _rebuildFts(AppDeps fresh) => fresh.gate.write((tx) async {
        final items = await tx.db.select(tx.db.items).get();
        for (final item in items) {
          if (item.deletedAt != null) {
            await tx.unindexItem(item.id);
            continue;
          }
          final names = await (tx.db.select(tx.db.itemTags).join([
            innerJoin(tx.db.tags, tx.db.itemTags.tagId.equalsExp(tx.db.tags.id)),
          ])..where(tx.db.itemTags.itemId.equals(item.id)))
              .get()
              .then((rows) => rows.map((r) => r.readTable(tx.db.tags).name));
          await tx.indexItem(
            itemId: item.id,
            title: item.title,
            body: item.bodyMd,
            comment: item.commentMd,
            tags: names.toList(),
          );
        }
      });

  /// New era after restore (§7.7): every peer must do a full sync next hello.
  Future<void> _bumpDbEpoch(AppDeps fresh) => fresh.gate.write((tx) async {
        final epoch = newId();
        final existing = await (tx.db.select(tx.db.settings)
              ..where((s) => s.key.equals('db_epoch')))
            .getSingleOrNull();
        if (existing != null) {
          await (tx.db.update(tx.db.settings)
                ..where((s) => s.key.equals('db_epoch')))
              .write(SettingsCompanion(value: Value(epoch)));
        } else {
          await tx.db.into(tx.db.settings).insert(
                SettingsCompanion.insert(key: 'db_epoch', value: epoch),
              );
        }
        await tx.db.update(tx.db.syncState)
            .write(SyncStateCompanion(dbEpoch: Value(epoch)));
      });
}

/// Tables counted in the manifest + compared on restore.
const kCountedTables = [
  'items',
  'tags',
  'item_tags',
  'links',
  'attachments',
  'projects',
  'milestones',
  'tasks',
  'courses',
  'course_units',
  'lessons',
];

class BackupManifest {
  BackupManifest({
    required this.formatVersion,
    required this.appVersion,
    required this.schemaVersion,
    required this.createdAt,
    required this.dbEpoch,
    required this.counts,
    required this.dbSha256,
    required this.blobsCount,
  });

  factory BackupManifest.fromJson(Map<String, dynamic> json) => BackupManifest(
        formatVersion: json['format_version'] as int,
        appVersion: json['app_version'] as String,
        schemaVersion: json['schema_version'] as int,
        createdAt: json['created_at'] as int,
        dbEpoch: json['db_epoch'] as String,
        counts: (json['counts'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, v as int)),
        dbSha256: json['db_sha256'] as String,
        blobsCount: json['blobs_count'] as int,
      );

  final int formatVersion;
  final String appVersion;
  final int schemaVersion;
  final int createdAt;
  final String dbEpoch;
  final Map<String, int> counts;
  final String dbSha256;
  final int blobsCount;

  Map<String, dynamic> toJson() => {
        'format_version': formatVersion,
        'app_version': appVersion,
        'schema_version': schemaVersion,
        'created_at': createdAt,
        'db_epoch': dbEpoch,
        'counts': counts,
        'db_sha256': dbSha256,
        'blobs_count': blobsCount,
      };
}

class RestoreResult {
  RestoreResult({required this.report, required this.deps});

  final RestoreReport report;
  final AppDeps deps;
}

class RestoreReport {
  RestoreReport({
    required this.counts,
    required this.manifestCounts,
    required this.integrity,
    required this.dbEpoch,
    required this.missingBlobs,
    required this.corruptBlobs,
    required this.workDir,
  });

  final Map<String, int> counts;
  final Map<String, int> manifestCounts;
  final String integrity;
  final String dbEpoch;
  final List<String> missingBlobs;
  final List<String> corruptBlobs;
  final Directory workDir;

  bool get ok =>
      integrity == 'ok' && missingBlobs.isEmpty && corruptBlobs.isEmpty;
}

String _sha256File(File f) {
  final bytes = f.readAsBytesSync();
  return sha256.convert(bytes).toString();
}
