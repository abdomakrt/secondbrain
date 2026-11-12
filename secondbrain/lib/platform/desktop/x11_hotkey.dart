/// Global hot key on X11 (spec §9.5, UI_SPEC UI-13).
///
/// `hotkey_manager` relies on `XGrabKey`, which on the X11/Cinnamon setups we
/// tested never delivered the key events (spike S1). `xinput test-xi2 --root`
/// *does* deliver them, so the shortcut is implemented by listening to the raw
/// X input events.
///
/// The XI2 stream reports the key code (`detail: 54`) but not the modifier
/// state, so the modifiers are tracked from the raw press/release events of
/// the modifier keys themselves.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../core/app_logger.dart';
import 'x11_tools.dart';

/// A parsed shortcut such as `Ctrl + Alt + Shift + C`.
class HotkeySpec {
  const HotkeySpec({
    required this.ctrl,
    required this.alt,
    required this.shift,
    required this.superKey,
    required this.key,
  });

  final bool ctrl;
  final bool alt;
  final bool shift;
  final bool superKey;

  /// The key itself, e.g. `C` (a single character) or `F5`.
  final String key;

  /// Parses `Ctrl + Alt + Shift + C` (case insensitive, any order).
  ///
  /// Returns null when the text does not describe a shortcut.
  static HotkeySpec? parse(String text) {
    final parts = text
        .split(RegExp(r'[+,]|\s+'))
        .map((p) => p.trim().toLowerCase())
        .where((p) => p.isNotEmpty)
        .toList();
    if (parts.isEmpty) return null;

    var ctrl = false;
    var alt = false;
    var shift = false;
    var superKey = false;
    String? key;

    for (final part in parts) {
      switch (part) {
        case 'ctrl':
        case 'control':
          ctrl = true;
        case 'alt':
        case 'option':
          alt = true;
        case 'shift':
          shift = true;
        case 'super':
        case 'meta':
        case 'cmd':
          superKey = true;
        default:
          if (part.length == 1 || (part.startsWith('f') && part.length > 1)) {
            key = part.toUpperCase();
          }
      }
    }
    if (key == null) return null;
    return HotkeySpec(
      ctrl: ctrl,
      alt: alt,
      shift: shift,
      superKey: superKey,
      key: key,
    );
  }

  /// The modifier bit mask (the same bits the X11 `state` field uses).
  int get stateMask {
    var mask = 0;
    if (shift) mask |= 0x01; // Shift
    if (ctrl) mask |= 0x04; // Control
    if (alt) mask |= 0x08; // Mod1 (Alt)
    if (superKey) mask |= 0x40; // Mod4 (Super)
    return mask;
  }

  /// A human readable form, e.g. `Ctrl + Alt + Shift + C`.
  String get label {
    final parts = <String>[
      if (ctrl) 'Ctrl',
      if (alt) 'Alt',
      if (shift) 'Shift',
      if (superKey) 'Super',
      key,
    ];
    return parts.join(' + ');
  }
}

/// The state of the hot key listener, shown in the settings screen.
enum HotkeyStatus {
  /// Not started yet.
  idle,

  /// Listening for the shortcut.
  listening,

  /// The shortcut could not be registered (already taken, no permission…).
  failed,

  /// The shortcut was taken by another application.
  conflict,
}

/// Listens for a global shortcut through `xinput test-xi2 --root`.
class X11HotkeyListener {
  X11HotkeyListener({X11Tools? tools})
      : _tools = tools ?? X11Tools();

  final X11Tools _tools;

  StreamSubscription<String>? _subscription;
  int? _keycode;
  HotkeyStatus _status = HotkeyStatus.idle;
  String? _message;

  /// The modifier key codes, resolved from the keyboard layout.
  final Map<String, List<int>> _modifierKeycodes = {};

  /// The modifiers that are currently held down.
  int _activeModifiers = 0;

  HotkeyStatus get status => _status;
  String? get message => _message;

  /// Starts listening for [spec].
  ///
  /// Returns true when the listener is running.
  Future<bool> start(HotkeySpec spec, {void Function()? onTrigger}) async {
    await stop();
    if (!_tools.hasDisplay) {
      _status = HotkeyStatus.failed;
      _message = 'لا يوجد عرض X11 (DISPLAY غير معيّن).';
      return false;
    }
    if (!_tools.hasBinary('xinput')) {
      _status = HotkeyStatus.failed;
      _message = 'الأداة xinput غير مثبّتة (حزمة xorg-x11-input-utils).';
      return false;
    }

    // A previous instance may still hold the XInput grab — that would make
    // the listener fail with BadAccess.
    await _killStaleListeners();

    final dump = await _tools.output('xmodmap', ['-pk']);
    final keycode = dump == null ? null : parseKeycode(dump, spec.key);
    if (keycode == null) {
      _status = HotkeyStatus.failed;
      _message = 'تعذّر تحديد زر «${spec.key}» في تخطيط لوحة المفاتيح.';
      AppLogger.log('hotkey: key not found: ${spec.key}');
      return false;
    }
    _keycode = keycode;
    _modifierKeycodes.clear();
    if (dump != null) {
      for (final entry in {
        'shift': ['Shift_L', 'Shift_R'],
        'ctrl': ['Control_L', 'Control_R'],
        'alt': ['Alt_L', 'Alt_R'],
        'super': ['Super_L', 'Super_R'],
      }.entries) {
        final codes = <int>[];
        for (final name in entry.value) {
          final code = parseKeycode(dump, name);
          if (code != null) codes.add(code);
        }
        _modifierKeycodes[entry.key] = codes;
      }
    }
    _activeModifiers = 0;

    try {
      final lines = _tools.startLines('xinput', ['test-xi2', '--root']);
      _subscription = lines.listen(
        (line) => _handleLine(line, spec, onTrigger),
        onError: (Object e) {
          _status = HotkeyStatus.failed;
          _message = 'انقطع مستمع لوحة المفاتيح: $e';
          AppLogger.log('hotkey: listener error: $e');
        },
        onDone: () {
          if (_status != HotkeyStatus.listening) return;
          _status = HotkeyStatus.failed;
          _message = 'توقف مستمع لوحة المفاتيح — سيُعاد تشغيله.';
          // The helper can die (for example when another client grabs the
          // XInput extension) — bring it back automatically.
          _restart(spec, onTrigger);
        },
      );
      _status = HotkeyStatus.listening;
      _message = 'يتم الآن الاستماع إلى ${spec.label}.';
      AppLogger.log(
        'hotkey: listening for ${spec.label} (keycode $keycode, '
        'modifiers $_modifierKeycodes)',
      );
      return true;
    } on Object catch (e) {
      _status = HotkeyStatus.failed;
      _message = 'تعذّر تشغيل مستمع لوحة المفاتيح: $e';
      AppLogger.log('hotkey: cannot start the listener: $e');
      return false;
    }
  }

  /// Restarts the listener after it stopped unexpectedly.
  void _restart(HotkeySpec spec, void Function()? onTrigger) {
    if (_restartTimer != null) return;
    _restartTimer = Timer(const Duration(seconds: 2), () {
      _restartTimer = null;
      if (_status == HotkeyStatus.failed) {
        start(spec, onTrigger: onTrigger);
      }
    });
  }

  Timer? _restartTimer;

  /// Stops listening.
  Future<void> stop() async {
    _restartTimer?.cancel();
    _restartTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    _keycode = null;
    _activeModifiers = 0;
    if (_status == HotkeyStatus.listening) {
      _status = HotkeyStatus.idle;
      _message = null;
    }
    await _killStaleListeners();
  }

  /// Kills the `xinput` helpers left behind by a previous run.
  Future<void> _killStaleListeners() async {
    if (!_tools.hasBinary('pkill')) return;
    try {
      await Process.run('pkill', ['-f', 'xinput test-xi2 --root']);
    } on Object {
      // best effort
    }
  }

  /// Handles one line of the XI2 stream.
  ///
  /// The relevant block looks like:
  /// ```
  /// EVENT type 13 (RawKeyPress)
  ///     device: 3 (5)
  ///     time: 7503425
  ///     detail: 54
  /// ```
  void _handleLine(String line, HotkeySpec spec, void Function()? onTrigger) {
    if (line.contains('RawKeyPress')) {
      _eventType = EventType.press;
      return;
    }
    if (line.contains('RawKeyRelease')) {
      _eventType = EventType.release;
      return;
    }
    final detail = RegExp(r'detail:\s*(\d+)').firstMatch(line);
    if (detail == null || _eventType == null) return;
    final code = int.parse(detail.group(1)!);
    final pressed = _eventType == EventType.press;

    // Track the modifier keys.
    for (final entry in _modifierKeycodes.entries) {
      if (!entry.value.contains(code)) continue;
      final bit = switch (entry.key) {
        'shift' => 0x01,
        'ctrl' => 0x04,
        'alt' => 0x08,
        _ => 0x40,
      };
      if (pressed) {
        _activeModifiers |= bit;
      } else {
        _activeModifiers &= ~bit;
      }
      return;
    }

    if (!pressed) return;
    final keycode = _keycode;
    if (keycode == null || code != keycode) return;
    if ((_activeModifiers & spec.stateMask) != spec.stateMask) return;
    // One physical press is reported twice (virtual core + the device), so the
    // repeat is filtered out.
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTrigger < _dedupeMs) return;
    _lastTrigger = now;
    AppLogger.log('hotkey: ${spec.label} pressed (modifiers $_activeModifiers)');
    onTrigger?.call();
  }

  EventType? _eventType;

  /// The time of the last trigger, used to filter the duplicate events.
  int _lastTrigger = 0;

  /// Two reports of the same press arrive within a few milliseconds.
  static const int _dedupeMs = 400;

  /// Parses an `xmodmap -pk` dump and returns the key code that produces
  /// [key] (case sensitive, e.g. `C`).
  @visibleForTesting
  static int? parseKeycode(String dump, String key) {
    final classic = RegExp(r'keycode\s*=*\s*(\d+)\s*=\s*(.*)');
    final extended = RegExp(r'^\s*(\d+)\s+(.*\(.*\).*)$');
    final keysym = RegExp(r'\(([^)]+)\)');
    for (final line in dump.split('\n')) {
      final classicMatch = classic.firstMatch(line);
      if (classicMatch != null) {
        final keysyms = classicMatch.group(2)!.split(RegExp(r'\s+'));
        if (keysyms.contains(key)) return int.parse(classicMatch.group(1)!);
        continue;
      }
      final extendedMatch = extended.firstMatch(line);
      if (extendedMatch == null) continue;
      final keysyms = keysym
          .allMatches(extendedMatch.group(2)!)
          .map((m) => m.group(1)!)
          .toList();
      if (keysyms.contains(key)) return int.parse(extendedMatch.group(1)!);
    }
    return null;
  }
}

enum EventType { press, release }
