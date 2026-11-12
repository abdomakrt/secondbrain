import 'package:drift/drift.dart';

import '../../core/ids.dart';
import '../database.dart';
import '../write_gate.dart';

/// Linked folders on the local disk (spec §12).
///
/// The table is local-only: paths are never synced and never indexed — the
/// app only remembers *where* the material of a project/course lives.
///
/// Desktop only: on Android the section is not shown at all.
class LocalPathsRepository {
  LocalPathsRepository({required this.db, required this.gate});

  final AppDatabase db;
  final WriteGate gate;

  /// Owner kinds: 'project' | 'course'.
  static const ownerProject = 'project';
  static const ownerCourse = 'course';

  /// The folders linked to an owner, oldest first.
  Stream<List<LocalPath>> watchFor(String ownerType, String ownerId) =>
      (db.select(db.localPaths)
            ..where((p) =>
                p.ownerType.equals(ownerType) & p.ownerId.equals(ownerId))
            ..orderBy([(p) => OrderingTerm.asc(p.path)]))
          .watch();

  Future<List<LocalPath>> listFor(String ownerType, String ownerId) =>
      (db.select(db.localPaths)
            ..where((p) =>
                p.ownerType.equals(ownerType) & p.ownerId.equals(ownerId))
            ..orderBy([(p) => OrderingTerm.asc(p.path)]))
          .get();

  /// Links a folder. The same path is never linked twice for one owner.
  Future<LocalPath> add({
    required String ownerType,
    required String ownerId,
    required String path,
    String? label,
  }) =>
      gate.write((tx) async {
        final existing = await (tx.db.select(tx.db.localPaths)
              ..where((p) =>
                  p.ownerType.equals(ownerType) &
                  p.ownerId.equals(ownerId) &
                  p.path.equals(path)))
            .getSingleOrNull();
        if (existing != null) {
          if (label == null || label.isEmpty) return existing;
          await (tx.db.update(tx.db.localPaths)
                ..where((p) => p.id.equals(existing.id)))
              .write(LocalPathsCompanion(label: Value(label)));
          return existing.copyWith(label: Value(label));
        }
        final id = newId();
        final row = LocalPath(
          id: id,
          ownerType: ownerType,
          ownerId: ownerId,
          path: path,
          label: (label == null || label.isEmpty) ? null : label,
        );
        await tx.db.into(tx.db.localPaths).insert(row);
        return row;
      });

  /// Removes the link (the folder itself is never touched).
  Future<void> remove(String id) => gate.write((tx) async {
        await (tx.db.delete(tx.db.localPaths)
              ..where((p) => p.id.equals(id)))
            .go();
      });
}
