import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/knowledge/widgets/arabic_markdown.dart';

/// Spike S6 (Phase 0): Markdown RTL behavior with flutter_markdown.
/// Verifies: Arabic paragraphs inherit the app's RTL direction, a single
/// newline renders as a line break (Keep notes requirement), and code
/// blocks are wrapped in an explicit LTR [Directionality] (the library
/// inherits ambient direction otherwise — documented spike finding).
void main() {
  Future<void> pumpMarkdown(WidgetTester tester, String data) async {
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.rtl,
      child: MaterialApp(home: Scaffold(body: ArabicMarkdownBody(data: data))),
    ));
    await tester.pump();
  }

  testWidgets('Arabic paragraph inherits the ambient RTL direction',
      (tester) async {
    await pumpMarkdown(tester, 'هذا نص عربي للتأكد من الاتجاه');
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    // null = inherits from Directionality( rtl ) above → effectively RTL.
    expect(rich.textDirection, isNull);
    expect(
      tester.widget<Directionality>(
        find.ancestor(
          of: find.byType(RichText).first,
          matching: find.byType(Directionality).first,
        ),
      ).textDirection,
      TextDirection.rtl,
    );
  });

  testWidgets('single newline renders as a line break (Keep notes)',
      (tester) async {
    await pumpMarkdown(tester, 'سطر أول\nسطر ثانٍ');
    // softLineBreak keeps the \n inside the span; without it the builder
    // replaces it with a space.
    final rich = tester.widget<RichText>(find.byType(RichText).first);
    final text = (rich.text as TextSpan).toPlainText();
    expect(text, contains('سطر أول'));
    expect(text, contains('\n'));
    expect(text, isNot(contains('سطر أول سطر ثانٍ')));
  });

  testWidgets('code block is wrapped in an explicit LTR Directionality',
      (tester) async {
    await pumpMarkdown(
        tester, 'نص عربي قبله\n```dart\nint x = 1; // code\n```');

    // The paragraph stays RTL-inherited.
    final paraRich = tester.widgetList<RichText>(find.byType(RichText)).first;
    expect((paraRich.text as TextSpan).toPlainText(), contains('نص عربي'));

    // The code block sits inside an explicit LTR Directionality.
    final codeText = find.textContaining('int x = 1;');
    expect(codeText, findsOneWidget);
    final dirs = tester.widgetList<Directionality>(
      find.ancestor(of: codeText, matching: find.byType(Directionality)),
    );
    expect(
      dirs.any((d) => d.textDirection == TextDirection.ltr),
      isTrue,
      reason: 'كتلة الكود يجب أن تكون داخل Directionality(ltr)',
    );
  });
}
