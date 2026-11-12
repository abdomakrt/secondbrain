import 'dart:io';

import 'package:archive/archive.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/app/app_deps.dart';
import 'package:secondbrain/data/database.dart';
import 'package:secondbrain/backup/backup_service.dart';
import 'package:secondbrain/backup/export_service.dart';

void main() {
  late Directory support;
  late AppDeps deps;
  late BackupService backup;

  setUp(() async {
    support = Directory.systemTemp.createTempSync('sb_backup_');
    deps = await AppDeps.open(support);
    backup = BackupService(deps: deps);
  });

  tearDown(() {
    deps.close();
    support.deleteSync(recursive: true);
  });

  Future<String> typeByName(String name) async {
    final t = await (deps.db.select(deps.db.itemTypes)
          ..where((x) => x.name.equals(name)))
        .getSingle();
    return t.id;
  }

  test('create produces valid .sbbackup; verify reports ok', () async {
    final item = await deps.items.create(
      typeId: await typeByName('ملاحظة'),
      title: 'نسخة احتياطية',
      bodyMd: 'محتوى للنسخ',
      tags: ['نسخ'],
    );
    final src = File('${support.path}/in.txt')..writeAsStringSync('مرفق');
    await deps.attachments.addFile(
        ownerType: 'item', ownerId: item.id, source: src, mime: 'text/plain');

    final out = await backup.create(destDir: Directory('${support.path}/backups'));
    expect(out.existsSync(), isTrue);
    expect(out.path.endsWith('.sbbackup'), isTrue);

    final report = await backup.verify(out);
    expect(report.integrity, 'ok');
    expect(report.counts['items'], 1);
    expect(report.counts['attachments'], 1);
    expect(report.manifestCounts['items'], 1);
    expect(report.missingBlobs, isEmpty);
    expect(report.corruptBlobs, isEmpty);
    ignore(item);
  });

  test('restore: dump → wipe → restore → full compare (§11.3)', () async {
    final item1 = await deps.items.create(
      typeId: await typeByName('ملاحظة'),
      title: 'عنصر أول',
      bodyMd: 'نص **مهم**',
      tags: ['عمل', 'فهرسة'],
    );
    await deps.items.update(item1, isPinned: true);
    await deps.items.create(
      typeId: await typeByName('سؤال'),
      title: 'سؤال ثانٍ',
      bodyMd: 'جواب',
      isInbox: true,
    );
    final src = File('${support.path}/img.png')..writeAsStringSync('bytes');
    await deps.attachments.addFile(
        ownerType: 'item', ownerId: item1.id, source: src, mime: 'image/png');

    Future<Map<String, Object?>> snapshot(AppDeps d) async {
      final items = await d.db.select(d.db.items).get();
      final tags = await d.db.select(d.db.tags).get();
      final pairs = await d.db.select(d.db.itemTags).get();
      final atts = await d.db.select(d.db.attachments).get();
      final versions = await d.db.select(d.db.itemVersions).get();
      final fts = await d.db
          .customSelect('SELECT item_id FROM items_fts WHERE items_fts MATCH ?',
              variables: [const Variable('مهم*')])
          .get();
      return {
        'items': [for (final i in items) i.toJson()],
        'tags': [for (final t in tags) t.toJson()],
        'pairs': [for (final p in pairs) p.toJson()],
        'attachments': [for (final a in atts) a.toJson()],
        'versions': versions.length,
        'fts_hits': fts.length,
      };
    }

    final before = await snapshot(deps);
    final backupFile =
        await backup.create(destDir: Directory('${support.path}/backups'));

    // WIPE + RESTORE (restore closes `current`, swaps files atomically).
    final result = await backup.restore(
        backupFile: backupFile, supportDir: support, current: deps);
    final restored = result.report;
    expect(restored.ok, isTrue);

    // Full compare against the bundle the service reopened.
    final freshDeps = result.deps;
    final after = await snapshot(freshDeps);
    expect(after['items'], before['items']);
    expect(after['tags'], before['tags']);
    expect(after['pairs'], before['pairs']);
    expect(after['attachments'], before['attachments']);
    expect(after['versions'], before['versions']);
    expect(after['fts_hits'], greaterThan(0)); // FTS rebuilt

    // Automatic safety copy exists (§11.2.2).
    final safety = Directory('${support.path}/safety');
    expect(
      safety.listSync().whereType<File>().where((f) => f.path.endsWith('.sbbackup')),
      isNotEmpty,
    );
  });

  test('restore regenerates db_epoch (§7.7)', () async {
    await deps.items.create(typeId: await typeByName('ملاحظة'), title: 'x');
    final backupFile =
        await backup.create(destDir: Directory('${support.path}/backups'));

    final epochBefore = await (deps.db.select(deps.db.settings)
          ..where((s) => s.key.equals('db_epoch')))
        .getSingleOrNull();

    final result = await backup.restore(
        backupFile: backupFile, supportDir: support, current: deps);
    final freshDeps = result.deps;

    final epochAfter = await (freshDeps.db.select(freshDeps.db.settings)
          ..where((s) => s.key.equals('db_epoch')))
        .getSingle();
    if (epochBefore == null) {
      expect(epochAfter.value, isNotEmpty);
    } else {
      expect(epochAfter.value, isNot(epochBefore.value));
    }
  });

  test('verify detects corrupted db (sha mismatch)', () async {
    await deps.items.create(typeId: await typeByName('ملاحظة'), title: 'س');
    final backupFile =
        await backup.create(destDir: Directory('${support.path}/backups'));

    // Tamper: decode, flip a byte in the db, re-encode with same manifest.
    final archive = ZipDecoder().decodeBytes(backupFile.readAsBytesSync());
    final out = Archive();
    for (final f in archive.files) {
      if (!f.isFile) continue;
      if (f.name == 'db/secondbrain.sqlite') {
        final data = Uint8List.fromList(f.content as List<int>);
        data[data.length ~/ 2] = data[data.length ~/ 2] ^ 0xFF;
        out.addFile(ArchiveFile.bytes(f.name, data));
      } else {
        out.addFile(ArchiveFile.bytes(f.name, f.content as List<int>));
      }
    }
    backupFile.writeAsBytesSync(ZipEncoder().encode(out));

    expect(() => backup.verify(backupFile), throwsA(isA<StateError>()));
  });

  test('daily auto backup: disabled → null, enabled → once per day', () async {
    final dest = Directory('${support.path}/backups');
    expect(await backup.maybeDailyBackup(destDir: dest), isNull); // disabled

    await deps.gate.write((tx) async {
      await tx.db.into(tx.db.settings).insert(
            SettingsCompanion.insert(key: 'auto_backup_daily', value: '1'),
          );
    });
    final first = await backup.maybeDailyBackup(destDir: dest);
    expect(first, isNotNull);
    final second = await backup.maybeDailyBackup(destDir: dest);
    expect(second, isNull); // within 24h
  });

  test('prune keeps newest 7 .sbbackup files', () async {
    final dest = Directory('${support.path}/backups');
    dest.createSync(recursive: true);
    await deps.gate.write((tx) async {
      await tx.db.into(tx.db.settings).insert(
            SettingsCompanion.insert(key: 'auto_backup_daily', value: '1'),
          );
    });
    // 8 old fake backups, timestamps ascending (ms in filename).
    for (var i = 0; i < 8; i++) {
      File('${dest.path}/auto-daily-100000000000$i.sbbackup')
          .writeAsStringSync('old$i');
    }
    final created = await backup.maybeDailyBackup(destDir: dest);
    if (created == null) fail('expected a daily backup to be created');
    final files = dest
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.sbbackup'))
        .toList();
    expect(files.length, 7); // newest 7 kept
    // The just-created real backup survives; oldest fake is gone.
    expect(created.existsSync(), isTrue);
    expect(files.any((f) => f.path.endsWith('1000000000000.sbbackup')), isFalse);
  });

  test('export: markdown with front matter + export.json + attachments', () async {
    final item = await deps.items.create(
      typeId: await typeByName('ملاحظة'),
      title: 'تصدير: تجربة/اختبار',
      bodyMd: 'جسم التصدير',
      tags: ['قراءة'],
    );
    final src = File('${support.path}/a.bin')..writeAsStringSync('data');
    await deps.attachments.addFile(
        ownerType: 'item', ownerId: item.id, source: src);

    final dest = Directory('${support.path}/export');
    final exporter = ExportService(
      db: deps.db,
      tags: deps.tags,
      blobsDir: deps.attachments.blobsDir,
    );
    await exporter.export(dest);

    final mdFiles = dest
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.md'))
        .toList();
    expect(mdFiles, hasLength(1));
    final md = mdFiles.single.readAsStringSync();
    expect(md, startsWith('---'));
    expect(md, contains('id: ${item.id}'));
    expect(md, contains('tags: [قراءة]'));
    expect(md, contains('جسم التصدير'));
    expect(mdFiles.single.path.contains(':'), isFalse); // unsafe chars removed

    final json = File('${dest.path}/export.json').readAsStringSync();
    expect(json, contains('secondbrain-export'));
    expect(json, contains('"item_tags"'));

    final atts = Directory('${dest.path}/attachments');
    expect(atts.existsSync(), isTrue);
    expect(atts.listSync().whereType<File>(), hasLength(1));
  });

  test('counted tables all exist in the schema', () {
    for (final table in kCountedTables) {
      expect(
        () => deps.db.customSelect('SELECT COUNT(*) FROM $table').getSingle(),
        returnsNormally,
        reason: 'جدول $table مفقود من المخطط',
      );
    }
  });
}

void ignore(Object _) {}
