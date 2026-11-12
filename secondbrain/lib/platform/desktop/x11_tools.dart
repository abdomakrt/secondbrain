/// Thin wrapper around the X11 command line tools the capture feature needs
/// (`xclip`, `xdotool`, `xprop`, `xmodmap`, `xinput`).
///
/// Everything is read-only with respect to the user's session: the clipboard
/// and the PRIMARY selection are only *read*, never written or replaced
/// (spec §9.2 / UI_SPEC UI-13).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

class X11Tools {
  X11Tools();

  /// Whether an X11 display is reachable.
  bool get hasDisplay {
    final display = Platform.environment['DISPLAY'];
    return display != null && display.isNotEmpty;
  }

  /// Whether the session is X11 (Wayland needs a different backend).
  bool get isX11Session {
    final type = Platform.environment['XDG_SESSION_TYPE'];
    return type == null || type == 'x11';
  }

  /// Whether [executable] exists on PATH.
  bool hasBinary(String executable) {
    final path = Platform.environment['PATH'] ?? '';
    for (final dir in path.split(':')) {
      if (dir.isEmpty) continue;
      if (File('$dir/$executable').existsSync()) return true;
    }
    return false;
  }

  /// Runs [executable] and returns its stdout (trimmed), or null on failure.
  ///
  /// [timeout] is important for the capture path: a hanging `xclip` must
  /// never block the hot key handler (spec §9.2 — 300 ms budget).
  Future<String?> output(
    String executable,
    List<String> arguments, {
    Duration timeout = const Duration(milliseconds: 800),
  }) async {
    try {
      final process = await Process.start(
        executable,
        arguments,
        environment: Platform.environment,
      );
      // Drain stderr so the child never blocks on a full pipe.
      unawaited(process.stderr.drain<void>());
      // Read the whole stream *before* looking at the exit code: the process
      // can exit while its output is still buffered (cancelling the
      // subscription early truncates the result).
      final output = process.stdout.transform(utf8.decoder).join();
      final code = await process.exitCode.timeout(
        timeout,
        onTimeout: () {
          process.kill(ProcessSignal.sigkill);
          return -1;
        },
      );
      final text = await output.timeout(
        const Duration(milliseconds: 500),
        onTimeout: () => '',
      );
      final trimmed = text.trim();
      if (code != 0) return null;
      return trimmed.isEmpty ? null : trimmed;
    } on Object {
      return null;
    }
  }

  /// Starts a long running process and streams its stdout lines.
  ///
  /// Used for `xinput test-xi2 --root`, the only key-event source that
  /// actually delivers events on the X11/Cinnamon setups we tested (S1).
  Stream<String> startLines(
    String executable,
    List<String> arguments, {
    Duration? timeout,
  }) async* {
    final process = await Process.start(
      executable,
      arguments,
      environment: Platform.environment,
    );
    _processes.add(process);
    final lines = process.stdout
        .transform(utf8.decoder)
        .transform(const LineSplitter());
    try {
      await for (final line in lines) {
        yield line;
      }
    } finally {
      _processes.remove(process);
    }
  }

  /// A short description of the X11 environment (shown in the settings).
  Map<String, String> diagnostics() {
    final session = Platform.environment['XDG_SESSION_TYPE'] ?? 'غير معروف';
    return {
      'session': session,
      'display': Platform.environment['DISPLAY'] ?? '—',
      'xclip': hasBinary('xclip') ? 'متاح' : 'غير مثبّت',
      'xdotool': hasBinary('xdotool') ? 'متاح' : 'غير مثبّت',
      'xinput': hasBinary('xinput') ? 'متاح' : 'غير مثبّت',
      'xprop': hasBinary('xprop') ? 'متاح' : 'غير مثبّت',
    };
  }

  final Set<Process> _processes = {};

  /// Kills every process started by this tool.
  void dispose() {
    for (final process in _processes.toList()) {
      process.kill(ProcessSignal.sigkill);
    }
    _processes.clear();
  }
}
