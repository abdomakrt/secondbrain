import 'package:flutter_test/flutter_test.dart';
import 'package:secondbrain/platform/desktop/x11_capture.dart';
import 'package:secondbrain/platform/desktop/x11_hotkey.dart';

/// Parsing of the X11 tools output (spike S1 findings).
void main() {
  group('hot key specification', () {
    test('parses the proposed shortcut', () {
      final spec = HotkeySpec.parse('Ctrl + Alt + Shift + C')!;
      expect(spec.ctrl, isTrue);
      expect(spec.alt, isTrue);
      expect(spec.shift, isTrue);
      expect(spec.key, 'C');
      expect(spec.label, 'Ctrl + Alt + Shift + C');
    });

    test('accepts different orders and separators', () {
      final spec = HotkeySpec.parse('shift+ctrl+alt+k')!;
      expect(spec.key, 'K');
      expect(spec.ctrl, isTrue);
    });

    test('rejects a text without a key', () {
      expect(HotkeySpec.parse('Ctrl + Alt'), isNull);
      expect(HotkeySpec.parse(''), isNull);
    });

    test('the state mask matches the X11 modifier bits', () {
      final spec = HotkeySpec.parse('Ctrl + Alt + Shift + C')!;
      // shift (0x01) | control (0x04) | mod1/alt (0x08)
      expect(spec.stateMask, 0x0d);
    });
  });

  group('xmodmap parsing', () {
    test('classic format', () {
      const dump = '''
keycode  46 = C c
keycode  54 = Shift_L Shift_R
''';
      expect(X11HotkeyListener.parseKeycode(dump, 'C'), 46);
    });

    test('extended format (this distribution)', () {
      const dump = '''
     46    	0x006c (l)	0x004c (L)	0x05e5 (Arabic_meem)
     54    	0x0063 (c)	0x0043 (C)	0x05c4 (Arabic_hamzaonwaw)
''';
      expect(X11HotkeyListener.parseKeycode(dump, 'C'), 54);
      expect(X11HotkeyListener.parseKeycode(dump, 'L'), 46);
    });

    test('an unknown key returns null', () {
      expect(X11HotkeyListener.parseKeycode('    54  0x0063 (c)', 'Q'), isNull);
    });
  });

  group('xinput event matching', () {
    final spec = HotkeySpec.parse('Ctrl + Alt + Shift + C')!;

    test('the state mask of the specification', () {
      // shift (0x01) | control (0x04) | mod1/alt (0x08)
      expect(spec.stateMask, 0x0d);
    });
  });

  group('WM_CLASS parsing', () {
    test('reads the application name', () {
      expect(
        X11CapturePlatform.parseWmClass(
          'WM_CLASS(STRING) = "firefox", "Firefox"',
        ),
        'Firefox',
      );
    });

    test('handles a missing value', () {
      expect(X11CapturePlatform.parseWmClass(null), isNull);
      expect(X11CapturePlatform.parseWmClass('WM_CLASS(STRING) = '), isNull);
    });
  });
}
