import 'package:uuid/uuid.dart';

/// Shared UUID helpers (spec §5.1: UUIDv7 for synced records, UUIDv5 for pair tables).
const Uuid _uuid = Uuid();

/// Time-ordered UUIDv7 — the id of every synced record.
String newId() => _uuid.v7();

/// Fixed namespace for app-generated UUIDv5 pair ids (item_tags, links).
const String _pairNamespace = '2f9a48c1-6a29-4b3a-9e4f-5c1d2b3a4f5e';

/// Deterministic id for pair tables (`item_tags`, `links`):
/// UUIDv5 of the pair so re-pairing the same records never duplicates rows.
String pairId(String table, List<String> parts) =>
    _uuid.v5(_pairNamespace, '$table\u0000${parts.join('\u0000')}');
