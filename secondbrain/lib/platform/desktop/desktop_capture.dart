/// Desktop capture platform interface (spec §9, UI_SPEC UI-13).
///
/// The capture window never talks to the OS directly: it asks this interface
/// for the selected text, the clipboard and the active window. That keeps the
/// UI testable and leaves the X11/Windows specifics behind one seam.
library;

class CapturePayload {
  const CapturePayload({
    required this.text,
    this.sourceLabel,
    this.url,
    this.title,
    this.app,
  });

  final String text;
  final String? sourceLabel;
  final String? url;
  final String? title;
  final String? app;
}

abstract class DesktopCapturePlatform {
  /// Whether the platform can capture at all on this device.
  bool get isSupported;

  /// The text currently selected in the focused window (PRIMARY selection).
  /// Reading only — the selection is never changed.
  Future<CapturePayload?> readSelection();

  /// The clipboard content. Reading only — the clipboard is never modified.
  Future<CapturePayload?> readClipboard();

  /// The title of the active window (usually the page title in a browser).
  Future<String?> activeWindowTitle();

  /// The name of the active application.
  Future<String?> activeApplication();

  /// Registers the global shortcut; returns false when the shortcut is
  /// already taken or cannot be registered.
  Future<bool> registerShortcut(String shortcut);

  /// Starts listening for [shortcut]; [onTrigger] runs on every press.
  ///
  /// Returns false when the shortcut could not be registered.
  Future<bool> listen(
    String shortcut, {
    required void Function() onTrigger,
  }) async =>
      false;

  /// Stops listening for the shortcut. A no-op when the platform does not
  /// support global shortcuts.
  Future<void> stopListening() async {}

  /// Brings the app window to the front (the capture window lives inside the
  /// main window). A no-op when the platform cannot do it.
  Future<void> activateAppWindow() async {}

  /// Human readable reason when the platform cannot capture.
  String? get unavailableReason;
}

/// Default implementation used until the desktop plugins are wired in.
///
/// It reports "not supported" instead of pretending to capture, so the UI can
/// show an honest state and fall back to manual paste.
class UnsupportedDesktopCapturePlatform implements DesktopCapturePlatform {
  const UnsupportedDesktopCapturePlatform();

  @override
  bool get isSupported => false;

  @override
  String? get unavailableReason =>
      'التقاط النص المحدد غير متاح في هذه النسخة — استخدم اللصق اليدوي أو '
      'مشاركة من الهاتف.';

  @override
  Future<CapturePayload?> readSelection() async => null;

  @override
  Future<CapturePayload?> readClipboard() async => null;

  @override
  Future<String?> activeWindowTitle() async => null;

  @override
  Future<String?> activeApplication() async => null;

  @override
  Future<bool> registerShortcut(String shortcut) async => false;

  @override
  Future<bool> listen(
    String shortcut, {
    required void Function() onTrigger,
  }) async =>
      false;

  @override
  Future<void> stopListening() async {}

  @override
  Future<void> activateAppWindow() async {}
}
