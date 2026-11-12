import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/common/widgets/filter_chip_menu.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(
        locale: const Locale('ar'),
        home: Scaffold(body: child),
      );

  testWidgets('shows the placeholder until a value is picked', (tester) async {
    await tester.pumpWidget(wrap(FilterChipMenu<String>(
      tooltip: 'النوع',
      icon: Icons.category_outlined,
      placeholder: 'النوع',
      allLabel: 'الكل',
      selected: null,
      onSelected: (_) {},
      options: const [FilterOption('a', 'ملاحظة')],
    )));

    expect(find.text('النوع'), findsOneWidget);
    expect(find.text('ملاحظة'), findsNothing);
  });

  testWidgets('picking an option reports it', (tester) async {
    String? picked;
    await tester.pumpWidget(wrap(FilterChipMenu<String>(
      tooltip: 'النوع',
      icon: Icons.category_outlined,
      placeholder: 'النوع',
      allLabel: 'الكل',
      selected: null,
      onSelected: (v) => picked = v,
      options: const [FilterOption('a', 'ملاحظة')],
    )));

    await tester.tap(find.byType(InputChip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ملاحظة').last);
    await tester.pumpAndSettle();

    expect(picked, 'a');
  });

  testWidgets('the "all" entry clears the filter', (tester) async {
    String? picked = 'keep';
    await tester.pumpWidget(wrap(FilterChipMenu<String>(
      tooltip: 'النوع',
      icon: Icons.category_outlined,
      placeholder: 'النوع',
      allLabel: 'الكل',
      selected: 'a',
      onSelected: (v) => picked = v,
      options: const [FilterOption('a', 'ملاحظة')],
    )));

    await tester.tap(find.byType(InputChip));
    await tester.pumpAndSettle();
    await tester.tap(find.text('الكل').last);
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });

  testWidgets('deleting the chip clears the filter', (tester) async {
    String? picked = 'keep';
    await tester.pumpWidget(wrap(FilterChipMenu<String>(
      tooltip: 'النوع',
      icon: Icons.category_outlined,
      placeholder: 'النوع',
      allLabel: 'الكل',
      selected: 'a',
      onSelected: (v) => picked = v,
      options: const [FilterOption('a', 'ملاحظة')],
    )));

    await tester.tap(find.byIcon(Icons.clear));
    await tester.pumpAndSettle();

    expect(picked, isNull);
  });
}
