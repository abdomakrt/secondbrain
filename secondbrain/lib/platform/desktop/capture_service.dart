/// The desktop capture service (spec §9, UI_SPEC UI-13).
///
/// Watches the global shortcut, reads the selection / clipboard / active
/// window and hands the result to the UI, which shows the capture window for
/// review. Nothing is saved before the user presses «حفظ».
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../core/app_logger.dart';
import 'desktop_capture.dart';

/// A capture request waiting to be shown to the user.
class CaptureRequest {
  const CaptureRequest({
    required this.text,
    this.sourceLabel = '',
    this.title,
    this.app,
    this.url,
  });

  final String text;
  final String sourceLabel;

  /// The title of the window the text came from.
  final String? title;

  /// The application the text came from.
  final String? app;

  /// The URL, when the captured text is a link.
  final String? url;
}

/// Watches the shortcut and produces [CaptureRequest]s.
class DesktopCaptureService {
  DesktopCaptureService({required this.platform});

  final DesktopCapturePlatform platform;

  /// The pending request; the shell listens to it.
  final ValueNotifier<CaptureRequest?> request = ValueNotifier(null);

  /// A human readable status shown in the settings screen.
  final ValueNotifier<String?> status = ValueNotifier(null);

  /// Whether the shortcut is currently being watched.
  final ValueNotifier<bool> listening = ValueNotifier(false);

  bool _started = false;
  String? _shortcut;

  /// Starts watching [shortcut]. Returns false when it could not be set up.
  ///
  /// Calling it again with the same shortcut is a no-op; with a different one
  /// the previous registration is replaced.
  Future<bool> start(String shortcut) async {
    final spec = shortcut.trim();
    if (_started && _shortcut == spec) return listening.value;
    if (_started) await stop();
    _started = true;
    _shortcut = spec;

    if (spec.isEmpty) {
      status.value = 'لم يُحدَّد اختصار للالتقاط.';
      return false;
    }

    final ok = await platform.listen(spec, onTrigger: _onTrigger);
    listening.value = ok;
    status.value = ok
        ? 'يتم الآن الاستماع إلى $spec. اضغطه في أي تطبيق لالتقاط المحتوى.'
        : 'تعذّر تسجيل الاختصار $spec — جرّب اختصارًا آخر.';
    AppLogger.log('capture hotkey: $spec → ${ok ? 'ok' : 'failed'}');
    return ok;
  }

  /// Stops watching.
  Future<void> stop() async {
    _started = false;
    _shortcut = null;
    listening.value = false;
    status.value = null;
    await platform.stopListening();
  }

  /// Reads the context and publishes a capture request.
  Future<void> _onTrigger() async {
    // 1. The selected text, 2. the clipboard.
    var payload = await platform.readSelection();
    payload ??= await platform.readClipboard();

    final title = await platform.activeWindowTitle();
    final app = await platform.activeApplication();

    final text = payload?.text ?? '';
    final url = _asUrl(text);

    AppLogger.log(
      'capture triggered: ${sourceLabelOf(payload)} '
      '(${text.length} chars) from ${app ?? '?'}',
    );
    request.value = CaptureRequest(
      text: text,
      sourceLabel: payload?.sourceLabel ?? '',
      title: title,
      app: app,
      url: url,
    );

    // Bring the app forward so the capture window is visible.
    await platform.activateAppWindow();
  }

  /// Clears the pending request.
  void consume() => request.value = null;

  /// A readable label of where the content came from.
  static String sourceLabelOf(CapturePayload? payload) =>
      payload?.sourceLabel ?? 'فارغ';

  /// Returns the URL when [text] is only a link.
  static String? _asUrl(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      return null;
    }
    if (trimmed.contains(' ')) return null;
    return trimmed;
  }

  void dispose() {
    request.dispose();
    status.dispose();
    listening.dispose();
  }
}
