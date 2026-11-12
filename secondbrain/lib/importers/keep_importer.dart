/// Google Keep import contract (spec §10).
///
/// The importer engine is scheduled for the second release (see
/// TASK_TRACKER.md — Phase 3 was deferred by the owner's decision). This file
/// fixes the contract the UI (UI-14) is built against, so the parser can be
/// dropped in later without touching the screen.
library;

import 'dart:io';

/// A summary of what a Takeout archive contains, shown before importing.
class KeepPreview {
  const KeepPreview({
    required this.notesCount,
    required this.labelsCount,
    required this.listItemsCount,
    required this.attachmentsCount,
    required this.unsupportedCount,
    this.unsupportedFeatures = const [],
  });

  final int notesCount;
  final int labelsCount;
  final int listItemsCount;
  final int attachmentsCount;
  final int unsupportedCount;

  /// Features found in the archive that the importer cannot preserve.
  final List<String> unsupportedFeatures;
}

/// The result of an import run.
class KeepImportReport {
  const KeepImportReport({
    required this.imported,
    required this.skipped,
    required this.failed,
    this.messages = const [],
  });

  final int imported;
  final int skipped;
  final int failed;
  final List<String> messages;
}

abstract class KeepImporter {
  /// True when the engine is available in this build.
  bool get isAvailable;

  /// Why the engine is unavailable (null when it is available).
  String? get unavailableReason;

  /// Scans a Takeout archive and returns a preview — never writes anything.
  Future<KeepPreview> preview(File zipFile);

  /// Imports the selected notes/labels. The source archive is never modified.
  Future<KeepImportReport> import(
    File zipFile, {
    Set<String>? selectedLabels,
    bool dryRun = false,
  });
}
