import 'package:drift/drift.dart';

// Synced tables (spec §5.2). Every one carries the standard columns:
// id (UUIDv7), user_id, created_at, updated_at, hlc, deleted_at.
// No strict FKs on synced tables — ids are stored and indexed only.

/// Standard columns shared by all synced tables.
mixin SyncedColumns on Table {
  TextColumn get id => text()();
  TextColumn get userId => text().withDefault(const Constant('local'))();
  IntColumn get createdAt => integer()();
  IntColumn get updatedAt => integer()();
  TextColumn get hlc => text()();
  IntColumn get deletedAt => integer().nullable()();
}

class Projects extends Table with SyncedColumns {
  TextColumn get name => text()();
  TextColumn get goal => text().withDefault(const Constant(''))();
  TextColumn get description => text().withDefault(const Constant(''))();
  // planned | active | paused | completed | archived
  TextColumn get status => text().withDefault(const Constant('planned'))();
  // auto | manual
  TextColumn get progressMode => text().withDefault(const Constant('auto'))();
  IntColumn get manualProgress => integer().withDefault(const Constant(0))();
  TextColumn get lastStop => text().nullable()();
  TextColumn get nextStep => text().nullable()();
  // The link the project came from (course page, repository, …).
  TextColumn get sourceUrl => text().nullable()();
}

class Milestones extends Table with SyncedColumns {
  TextColumn get projectId => text()();
  TextColumn get title => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
  IntColumn get doneAt => integer().nullable()();
}

class Tasks extends Table with SyncedColumns {
  TextColumn get projectId => text().nullable()();
  TextColumn get milestoneId => text().nullable()();
  TextColumn get parentTaskId => text().nullable()();
  TextColumn get lessonId => text().nullable()();
  TextColumn get title => text()();
  TextColumn get notesMd => text().nullable()();
  // todo | doing | done | canceled
  TextColumn get status => text().withDefault(const Constant('todo'))();
  BoolColumn get isImportant => boolean().withDefault(const Constant(false))();
  BoolColumn get isUrgent => boolean().withDefault(const Constant(false))();
  IntColumn get estMinutes => integer().nullable()();
  IntColumn get actualMinutes => integer().nullable()();
  IntColumn get dueAt => integer().nullable()();
  IntColumn get plannedDate => integer().nullable()();
  IntColumn get plannedStartMin => integer().nullable()();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get postponedCount => integer().withDefault(const Constant(0))();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class Courses extends Table with SyncedColumns {
  TextColumn get title => text()();
  TextColumn get description => text().withDefault(const Constant(''))();
  TextColumn get status => text().withDefault(const Constant('planned'))();
  TextColumn get projectId => text().nullable()();
  TextColumn get currentLessonId => text().nullable()();
  TextColumn get lastStop => text().nullable()();
  // The link the course comes from (a playlist, a site, a PDF…).
  TextColumn get sourceUrl => text().nullable()();
}

class CourseUnits extends Table with SyncedColumns {
  TextColumn get courseId => text()();
  TextColumn get title => text()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class Lessons extends Table with SyncedColumns {
  TextColumn get courseId => text()();
  TextColumn get unitId => text().nullable()();
  TextColumn get title => text()();
  // todo | in_progress | done
  TextColumn get status => text().withDefault(const Constant('todo'))();
  IntColumn get completedAt => integer().nullable()();
  IntColumn get sortOrder => integer().withDefault(const Constant(0))();
}

class ItemTypes extends Table with SyncedColumns {
  TextColumn get name => text()();
  TextColumn get icon => text().nullable()();
  BoolColumn get isBuiltin => boolean().withDefault(const Constant(false))();
}

class Items extends Table with SyncedColumns {
  TextColumn get typeId => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get bodyMd => text().withDefault(const Constant(''))();
  TextColumn get commentMd => text().nullable()();
  TextColumn get answerMd => text().nullable()();
  IntColumn get reviewedAt => integer().nullable()();
  TextColumn get projectId => text().nullable()();
  TextColumn get courseId => text().nullable()();
  TextColumn get lessonId => text().nullable()();
  TextColumn get taskId => text().nullable()();
  BoolColumn get isInbox => boolean().withDefault(const Constant(false))();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isArchived => boolean().withDefault(const Constant(false))();
  TextColumn get color => text().nullable()();
  TextColumn get sourceUrl => text().nullable()();
  TextColumn get sourceTitle => text().nullable()();
  TextColumn get sourceApp => text().nullable()();
  // capture | share | manual | keep_import
  TextColumn get sourceKind => text().withDefault(const Constant('manual'))();
  IntColumn get capturedAt => integer().nullable()();
}

class Tags extends Table with SyncedColumns {
  TextColumn get name => text()();
  TextColumn get nameNormalized => text()();
}

@TableIndex(name: 'idx_item_tags_pair', unique: true, columns: {#itemId, #tagId})
class ItemTags extends Table with SyncedColumns {
  TextColumn get itemId => text()();
  TextColumn get tagId => text()();
}

@TableIndex(
  name: 'idx_links_pair',
  unique: true,
  columns: {#fromType, #fromId, #toType, #toId, #kind},
)
class Links extends Table with SyncedColumns {
  TextColumn get fromType => text()();
  TextColumn get fromId => text()();
  TextColumn get toType => text()();
  TextColumn get toId => text()();
  // related | source | derived_from
  TextColumn get kind => text()();
}

class Attachments extends Table with SyncedColumns {
  TextColumn get ownerType => text()();
  TextColumn get ownerId => text()();
  TextColumn get kind => text()();
  TextColumn get filename => text()();
  TextColumn get mime => text().nullable()();
  IntColumn get size => integer()();
  TextColumn get sha256 => text()();
  TextColumn get originalRef => text().nullable()();
}

@DataClassName('Setting')
class Settings extends Table {
  TextColumn get key => text()();
  TextColumn get value => text()();
  BoolColumn get synced => boolean().withDefault(const Constant(false))();

  @override
  Set<Column> get primaryKey => {key};
}

// Local-only tables (spec §5.3) — never synced.

@DataClassName('OplogEntry')
class Oplog extends Table {
  IntColumn get seq => integer().autoIncrement()();
  TextColumn get entity => text()();
  TextColumn get recordId => text()();
  TextColumn get hlc => text()();
  TextColumn get originDevice => text()();
  IntColumn get createdAt => integer()();
}

@DataClassName('SyncStateRow')
class SyncState extends Table {
  TextColumn get peerId => text()();
  IntColumn get lastPulledSeq => integer().nullable()();
  IntColumn get lastPushedSeq => integer().nullable()();
  TextColumn get dbEpoch => text()();

  @override
  Set<Column> get primaryKey => {peerId};
}

class Devices extends Table {
  TextColumn get deviceId => text()();
  TextColumn get name => text()();
  TextColumn get tokenHash => text()();
  IntColumn get pairedAt => integer()();
  IntColumn get lastSeenAt => integer().nullable()();
  IntColumn get revokedAt => integer().nullable()();

  @override
  Set<Column> get primaryKey => {deviceId};
}

class ItemVersions extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get title => text()();
  TextColumn get bodyMd => text()();
  // conflict | local_edit
  TextColumn get reason => text()();
  IntColumn get savedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

class LocalPaths extends Table {
  TextColumn get id => text()();
  TextColumn get ownerType => text()();
  TextColumn get ownerId => text()();
  TextColumn get path => text()();
  TextColumn get label => text().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}

@DataClassName('ImportMapEntry')
class ImportMap extends Table {
  TextColumn get source => text()();
  TextColumn get sourceKey => text()();
  TextColumn get itemId => text()();
  TextColumn get contentHash => text()();
  IntColumn get importedAt => integer()();

  @override
  Set<Column> get primaryKey => {source, sourceKey};
}

class ImportBatches extends Table {
  TextColumn get id => text()();
  TextColumn get source => text()();
  IntColumn get startedAt => integer()();
  IntColumn get finishedAt => integer().nullable()();
  TextColumn get report => text()();

  @override
  Set<Column> get primaryKey => {id};
}

class CaptureDrafts extends Table {
  TextColumn get id => text()();
  TextColumn get content => text()();
  IntColumn get savedAt => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
