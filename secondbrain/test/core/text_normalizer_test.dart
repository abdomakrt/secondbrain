import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/core/text_normalizer.dart';

void main() {
  group('normalizeForSearch (spec §6.2)', () {
    test('NFKC: presentation ligature becomes plain alef-lam', () {
      expect(normalizeForSearch('\uFEFB'), 'لا');
    });

    test('removes tashkeel and quranic marks', () {
      expect(normalizeForSearch('مُتَجَرِّب\u0670'), 'متجرب');
    });

    test('removes tatweel', () {
      expect(normalizeForSearch('مــدرسة'), 'مدرسه');
    });

    test('unifies alef forms', () {
      expect(normalizeForSearch('أ إ آ ٱ'), 'ا ا ا ا');
    });

    test('ya-alef maqsura → ya and ta-marbuta → ha', () {
      expect(normalizeForSearch('مدرسة عليى'), 'مدرسه عليي');
    });

    test('arabic-indic and persian digits → ascii', () {
      expect(normalizeForSearch('٢٠٢٥ ۴۵۶'), '2025 456');
    });

    test('latin lowercased', () {
      expect(normalizeForSearch('Flutter SDK'), 'flutter sdk');
    });

    test('removes invisible bidi/control marks', () {
      expect(normalizeForSearch('مدرس\u200Cة\u200F'), 'مدرسه');
    });

    test('squeezes whitespace', () {
      expect(normalizeForSearch('  أهلا   بكم  '), 'اهلا بكم');
    });
  });

  group('stems (spec §6.3)', () {
    test('tokens longer than 4 after dropping «ال»', () {
      // نادي (4) and كل (2) are too short; مكتبه (5) qualifies.
      expect(buildStems(['النادي', 'مكتبة', 'الكل']), 'مكتبه');
    });

    test('normalization applied before stemming', () {
      expect(buildStems(['المُدارسة']), 'مدارسه');
    });
  });

  group('ftsMatchExpression', () {
    test('plain token becomes a prefix query', () {
      expect(ftsMatchExpression('مكتبة'), 'مكتبه*');
    });

    test('token with «ال» gets the stripped alternative', () {
      expect(ftsMatchExpression('النادي'), '(النادي* OR نادي*)');
    });

    test('multiple tokens joined with AND', () {
      expect(ftsMatchExpression('مكتبة النادي'), 'مكتبه* AND (النادي* OR نادي*)');
    });
  });
}
