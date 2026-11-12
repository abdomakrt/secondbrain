import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/app/app_scope.dart';
import 'package:secondbrain/features/backup/backup_screen.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../features/harness.dart';

void main() {
  testWidgets('backup screen renders and auto-daily toggle writes setting',
      (tester) async {
    final h = await Harness.create();
    addTearDown(() => h.dispose());
    await h.seedTypes();

    await tester.pumpWidget(MaterialApp(
      locale: const Locale('ar'),
      supportedLocales: const [Locale('ar')],
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      home: AppScope(
        deps: h.deps(),
        child: const BackupScreen(),
      ),
    ));
    await tester.pump();

    // The main actions render (Arabic strings from app_ar.arb).
    expect(find.byType(BackupScreen), findsOneWidget);
    expect(find.byIcon(Icons.backup), findsOneWidget);
    expect(find.byIcon(Icons.restore), findsOneWidget);
    expect(find.byType(SwitchListTile), findsOneWidget);

    // Toggle «نسخ تلقائي يومي» on → settings row written through the gate.
    await tester.tap(find.byType(SwitchListTile));
    await tester.pump();
    final row = await tester.runAsync(() async {
      final db = h.db;
      return (db.select(db.settings)
            ..where((s) => s.key.equals('auto_backup_daily')))
          .getSingleOrNull();
    });
    expect(row?.value, '1');
  });
}
