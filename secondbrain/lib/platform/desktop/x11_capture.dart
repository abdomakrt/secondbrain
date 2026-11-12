/// The X11 implementation of the capture platform (spec §9.2, §9.5).
///
/// - Selection: `xclip -o -selection primary` (read only).
/// - Clipboard: `xclip -o -selection clipboard` (read only).
/// - Active window title: `xdotool getactivewindow getwindowname`.
/// - Active application: `xprop -id <window> WM_CLASS`.
///
/// Nothing here ever *writes* to the clipboard or the selection.
library;

import 'dart:io';

import 'desktop_capture.dart';
import 'x11_hotkey.dart';
import 'x11_tools.dart';

class X11CapturePlatform implements DesktopCapturePlatform {
  X11CapturePlatform({X11Tools? tools, X11HotkeyListener? hotkey})
      : _tools = tools ?? X11Tools(),
        _hotkey = hotkey ?? X11HotkeyListener(tools: tools);

  final X11Tools _tools;
  final X11HotkeyListener _hotkey;

  @override
  bool get isSupported =>
      Platform.isLinux && _tools.hasDisplay && _tools.hasBinary('xclip');

  @override
  String? get unavailableReason {
    if (!Platform.isLinux) return 'التقاط المحتوى متاح على لينكس فقط.';
    if (!_tools.hasDisplay) return 'لا يوجد عرض X11 (DISPLAY غير معيّن).';
    if (!_tools.hasBinary('xclip')) {
      return 'الأداة xclip غير مثبّتة (حزمة xclip).';
    }
    return null;
  }

  @override
  Future<CapturePayload?> readSelection() async {
    final text = await _tools.output(
      'xclip',
      ['-o', '-selection', 'primary'],
      timeout: const Duration(milliseconds: 700),
    );
    if (text == null || text.isEmpty) return null;
    return CapturePayload(text: text, sourceLabel: 'نص محدد');
  }

  @override
  Future<CapturePayload?> readClipboard() async {
    final text = await _tools.output(
      'xclip',
      ['-o', '-selection', 'clipboard'],
      timeout: const Duration(milliseconds: 700),
    );
    if (text == null || text.isEmpty) return null;
    return CapturePayload(text: text, sourceLabel: 'الحافظة');
  }

  @override
  Future<String?> activeWindowTitle() async {
    final title = await _tools.output(
      'xdotool',
      ['getactivewindow', 'getwindowname'],
      timeout: const Duration(milliseconds: 300),
    );
    return title;
  }

  @override
  Future<String?> activeApplication() async {
    final id = await _tools.output(
      'xdotool',
      ['getactivewindow'],
      timeout: const Duration(milliseconds: 300),
    );
    if (id == null) return null;
    final wmClass = await _tools.output(
      'xprop',
      ['-id', id.trim(), 'WM_CLASS'],
      timeout: const Duration(milliseconds: 300),
    );
    return parseWmClass(wmClass);
  }

  @override
  Future<bool> registerShortcut(String shortcut) async {
    final spec = HotkeySpec.parse(shortcut);
    if (spec == null) return false;
    return _hotkey.start(spec);
  }

  /// Starts listening for [shortcut]; [onTrigger] runs on every press.
  @override
  Future<bool> listen(
    String shortcut, {
    required void Function() onTrigger,
  }) async {
    final spec = HotkeySpec.parse(shortcut);
    if (spec == null) return false;
    return _hotkey.start(spec, onTrigger: onTrigger);
  }

  /// Stops listening.
  @override
  Future<void> stopListening() => _hotkey.stop();

  /// The hot key status (shown in the settings screen).
  HotkeyStatus get hotkeyStatus => _hotkey.status;

  String? get hotkeyMessage => _hotkey.message;

  /// Brings the app window to the front (the capture window is a route inside
  /// the main window, so it has to be visible).
  @override
  Future<void> activateAppWindow() async {
    // Match the WM_CLASS of the app window (the window *title* is not
    // unique enough: other apps may use the same name).
    await _tools.output(
      'xdotool',
      ['search', '--class', 'secondbrain.secondbrain', 'windowactivate'],
      timeout: const Duration(milliseconds: 500),
    );
  }

  /// Parses `WM_CLASS(STRING) = "firefox", "Firefox"` → `Firefox`.
  static String? parseWmClass(String? raw) {
    if (raw == null) return null;
    final match = RegExp(r'=\s*"(.*?)"\s*,\s*"(.*?)"').firstMatch(raw);
    if (match == null) return null;
    final name = match.group(2)!.trim();
    return name.isEmpty ? null : name;
  }
}
