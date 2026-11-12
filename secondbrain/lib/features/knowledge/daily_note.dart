import 'package:flutter/material.dart';

import '../../app/app_scope.dart';
import '../../data/database.dart';

/// A quick note captured from the search box.
///
/// The quick-add button next to the search field saves what the user typed as
/// a note of the day: a «ملاحظة» in the knowledge base tagged with «اليوم»
/// so it can be found again from the knowledge screen.
class DailyNote {
  const DailyNote._();

  /// The tag used for the notes of the day.
  static const tag = 'اليوم';

  /// Creates the note from [text] and returns it.
  static Future<Item> create(BuildContext context, String text) async {
    final scope = AppScope.of(context);
    final types = await scope.db.select(scope.db.itemTypes).get();
    final noteType = types.where((t) => t.name == 'ملاحظة').firstOrNull ??
        (types.isEmpty ? null : types.first);
    final trimmed = text.trim();
    final firstLine = trimmed.split('\n').first;
    return scope.items.create(
      typeId: noteType?.id ?? '',
      title: firstLine.length > 80 ? '${firstLine.substring(0, 79)}…' : firstLine,
      bodyMd: trimmed,
      tags: const [tag],
    );
  }
}
