import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import '../database.dart';
import '../write_gate.dart';

/// File attachments (spec §7.6): content-addressed blobs (sha256) under
/// `blobs/<first 2 hex>/`, records go through [WriteGate] like any synced row.
/// Max 50 MB per file.
class AttachmentsRepository {
  AttachmentsRepository({
    required this.db,
    required this.gate,
    required this.blobsDir,
  }) {
    blobsDir.createSync(recursive: true);
  }

  static const int maxBytes = 50 * 1024 * 1024;

  final AppDatabase db;
  final WriteGate gate;
  final Directory blobsDir;

  Future<Attachment> addFile({
    required String ownerType,
    required String ownerId,
    required File source,
    String? mime,
    String? originalRef,
  }) async {
    if (!source.existsSync()) {
      throw StateError('الملف غير موجود: ${source.path}');
    }
    final size = source.lengthSync();
    if (size > maxBytes) {
      throw StateError('حجم المرفق يتجاوز الحد الأقصى (50MB)');
    }

    // Stream-hash so big files never load fully into memory.
    final digest = await _hashFile(source);
    final sha = digest.toString();
    final blob = _blobFile(sha);
    if (!blob.existsSync()) {
      await blob.parent.create(recursive: true);
      await source.copy(blob.path);
    }

    final filename = source.uri.pathSegments.lastWhere((p) => p.isNotEmpty);
    final resolvedMime = mime ?? mimeFromName(filename);
    final kind = resolvedMime == null ? 'file' : _kindFromMime(resolvedMime);
    return gate.write((tx) async {
      final id = sha; // content address = stable id, replay-safe
      final s = await tx.stamp('attachments', id);
      final row = Attachment(
        id: id,
        userId: 'local',
        createdAt: s.updatedAtMs,
        updatedAt: s.updatedAtMs,
        hlc: s.hlc,
        ownerType: ownerType,
        ownerId: ownerId,
        kind: kind,
        filename: filename,
        mime: resolvedMime,
        size: size,
        sha256: sha,
        originalRef: originalRef,
      );
      // Same content attached to the same owner → idempotent, no new row.
      final existing = await (tx.db.select(tx.db.attachments)
            ..where((a) => a.id.equals(id)))
          .getSingleOrNull();
      if (existing != null) return existing;
      await tx.db.into(tx.db.attachments).insert(row);
      return row;
    });
  }

  Future<List<Attachment>> listFor(String ownerType, String ownerId) =>
      (db.select(db.attachments)
            ..where((a) =>
                a.ownerType.equals(ownerType) & a.ownerId.equals(ownerId))
            ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .get();

  Stream<List<Attachment>> watchFor(String ownerType, String ownerId) =>
      (db.select(db.attachments)
            ..where((a) =>
                a.ownerType.equals(ownerType) & a.ownerId.equals(ownerId))
            ..orderBy([(a) => OrderingTerm.asc(a.createdAt)]))
          .watch();

  /// Removes the record; the blob file is deleted only if no other record
  /// references the same content.
  Future<void> delete(Attachment attachment) async {
    await gate.write((tx) async {
      await tx.stamp('attachments', attachment.id);
      await (tx.db.delete(tx.db.attachments)
            ..where((a) => a.id.equals(attachment.id)))
          .go();
    });
    await _deleteBlobIfUnreferenced(attachment.sha256);
  }

  Future<void> _deleteBlobIfUnreferenced(String sha256) async {
    final refs = await (db.select(db.attachments)
          ..where((a) => a.sha256.equals(sha256)))
        .get();
    if (refs.isEmpty) {
      final f = _blobFile(sha256);
      if (f.existsSync()) await f.delete();
    }
  }

  File fileFor(Attachment a) => _blobFile(a.sha256);

  File _blobFile(String sha) =>
      File('${blobsDir.path}/${sha.substring(0, 2)}/$sha');

  Future<Digest> _hashFile(File f) async {
    final digest = Completer<Digest>();
    final sink = sha256.startChunkedConversion(_DigestSink(digest.complete));
    await for (final chunk in f.openRead()) {
      sink.add(chunk);
    }
    sink.close();
    return digest.future;
  }

  static String _kindFromMime(String mime) {
    if (mime.startsWith('image/')) return 'image';
    if (mime.startsWith('audio/')) return 'audio';
    if (mime.startsWith('video/')) return 'video';
    if (mime == 'application/pdf') return 'pdf';
    return 'file';
  }

  /// Guesses the mime type from the file extension.
  ///
  /// The data layer owns this decision so every caller (UI, importer) stores
  /// the same kind of attachment.
  static String? mimeFromName(String name) {
    final dot = name.lastIndexOf('.');
    if (dot < 0 || dot == name.length - 1) return null;
    return _mimeByExtension[name.substring(dot + 1).toLowerCase()];
  }

  static const _mimeByExtension = <String, String>{
    'png': 'image/png',
    'jpg': 'image/jpeg',
    'jpeg': 'image/jpeg',
    'gif': 'image/gif',
    'webp': 'image/webp',
    'pdf': 'application/pdf',
    'mp3': 'audio/mpeg',
    'mp4': 'video/mp4',
  };
}

/// Sink that captures the [Digest] crypto emits on close.
class _DigestSink implements Sink<Digest> {
  _DigestSink(this.onDone);

  final void Function(Digest) onDone;

  @override
  void add(Digest data) => onDone(data);

  @override
  void close() {}
}
