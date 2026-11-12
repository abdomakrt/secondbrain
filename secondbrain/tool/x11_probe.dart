// Standalone probe for the X11 tools (no Flutter import).
// Run: dart run tool/x11_probe.dart
import 'dart:convert';
import 'dart:io';

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
    unawaited(process.stderr.drain<void>());
    final out = process.stdout.transform(utf8.decoder).join();
    final code = await process.exitCode.timeout(timeout, onTimeout: () {
      process.kill(ProcessSignal.sigkill);
      return -1;
    });
    final text = await out.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => '',
    );
    final trimmed = text.trim();
    if (code != 0) return null;
    return trimmed.isEmpty ? null : trimmed;
  } on Object catch (e) {
    print('error: $e');
    return null;
  }
}

void unawaited(Future<void> future) {}

Future<void> main() async {
  print('DISPLAY=${Platform.environment['DISPLAY']}');
  print('LANG=${Platform.environment['LANG']}');
  final selection = await output(
    'xclip',
    ['-o', '-selection', 'primary'],
    timeout: const Duration(milliseconds: 700),
  );
  print('selection=${selection == null ? "<null>" : selection}');
  final clipboard = await output(
    'xclip',
    ['-o', '-selection', 'clipboard'],
    timeout: const Duration(milliseconds: 700),
  );
  print('clipboard=${clipboard == null ? "<null>" : clipboard}');
  final title = await output('xdotool', ['getactivewindow', 'getwindowname']);
  print('title=$title');
}
