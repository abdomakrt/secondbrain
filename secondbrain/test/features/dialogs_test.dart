import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/features/common/dialogs.dart';

void main() {
  group('splitTagNames', () {
    test('splits on the arabic and the latin comma', () {
      expect(splitTagNames('عمل، برمجة'), ['عمل', 'برمجة']);
      expect(splitTagNames('work, code'), ['work', 'code']);
    });

    test('trims and drops the empty names', () {
      expect(splitTagNames('  عمل , , برمجة  '), ['عمل', 'برمجة']);
      expect(splitTagNames(''), isEmpty);
      expect(splitTagNames(' , '), isEmpty);
    });

    test('keeps the names that contain a space', () {
      expect(splitTagNames('مشروع جديد'), ['مشروع جديد']);
    });
  });
}
