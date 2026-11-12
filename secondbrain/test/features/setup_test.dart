import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/setup/setup_screen.dart';
import 'package:secondbrain/features/shell/app_shell.dart';

import 'harness.dart';

/// The first run shows the setup wizard; finishing it opens the shell.
void main() {
  testWidgets('the first run opens the setup wizard', (tester) async {
    final h = await Harness.create();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    expect(find.byType(SetupScreen), findsOneWidget);
    expect(find.text('الترحيب'), findsOneWidget);
    expect(find.text('العقل الثاني'), findsWidgets);
    h.dispose();
  });

  testWidgets('finishing the setup opens the shell', (tester) async {
    final h = await Harness.create();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // Walk through the wizard: welcome → data → pairing → finish.
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('البيانات'), findsOneWidget);

    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('ربط الأجهزة'), findsOneWidget);

    await tester.tap(find.text('إنهاء الإعداد'));
    await tester.pumpAndSettle();

    expect(find.byType(AppShell), findsOneWidget);
    final done = await tester.runAsync(
      () => h.settings.getBool('setup_completed'),
    );
    expect(done, isTrue);
    h.dispose();
  });

  testWidgets('the connection test reports an honest state', (tester) async {
    final h = await Harness.create();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.widgetWithText(TextField, 'عنوان الخادم'),
      '192.168.1.10:8443',
    );
    await tester.ensureVisible(find.text('اختبار الاتصال'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختبار الاتصال'));
    await tester.pumpAndSettle();

    // The sync server does not exist yet — the UI says so instead of
    // pretending to be connected.
    expect(find.text('الخادم غير متاح'), findsWidgets);
    h.dispose();
  });
}
