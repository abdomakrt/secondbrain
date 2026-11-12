import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/capture/capture_window.dart';
import 'package:secondbrain/features/settings/settings_screen.dart';

import 'harness.dart';

/// Reproduces the settings interactions reported by the user.
void main() {
  testWidgets('settings: open the capture shortcut dialog', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    // Settings live behind «المزيد» on Android.
    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الإعدادات').last);
    await tester.pumpAndSettle();
    expect(find.byType(SettingsScreen), findsOneWidget);

    await tester.dragUntilVisible(
      find.text('اختصار الالتقاط'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('اختصار الالتقاط'));
    await tester.pumpAndSettle();

    // The dialog must open without an exception.
    expect(find.byType(AlertDialog), findsOneWidget);
    h.dispose();
  });

  testWidgets('settings: open the capture window', (tester) async {
    final h = await Harness.create();
    await h.completeSetup();
    await tester.pumpWidget(h.app());
    await tester.pumpAndSettle();

    await tester.tap(find.text('المزيد').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('الإعدادات').last);
    await tester.pumpAndSettle();

    await tester.dragUntilVisible(
      find.text('فتح نافذة الالتقاط'),
      find.byType(ListView).last,
      const Offset(0, -300),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('فتح نافذة الالتقاط'));
    await tester.pumpAndSettle();

    expect(find.byType(CaptureWindow), findsOneWidget);
    h.dispose();
  });
}
