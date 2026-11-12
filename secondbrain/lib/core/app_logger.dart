/// Application log + global error handling.
///
/// Every uncaught error is written to `errors.log` inside the app support
/// directory so it can be inspected (or sent to the developer) instead of
/// leaving the user with a blank window (UI_SPEC §8: "خطأ مفهوم مع إمكانية
/// إعادة المحاولة").
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';

class AppLogger {
  AppLogger._();

  static File? _file;

  /// Opens the log file inside [directory].
  static Future<void> init(Directory directory) async {
    try {
      if (!directory.existsSync()) {
        await directory.create(recursive: true);
      }
      _file = File('${directory.path}/errors.log');
      if (!await _file!.exists()) {
        await _file!.create();
      }
    } on Object catch (e) {
      debugPrint('cannot open the log file: $e');
    }
  }

  /// Writes a line to the log file (and the console).
  static void log(String message, {Object? error, StackTrace? stack}) {
    final now = DateTime.now().toIso8601String();
    final buffer = StringBuffer('$now  $message');
    if (error != null) buffer.write('\n$error');
    if (stack != null) buffer.write('\n$stack');
    buffer.write('\n---\n');
    debugPrint(buffer.toString());
    final file = _file;
    if (file == null) return;
    try {
      file.writeAsStringSync(buffer.toString(), mode: FileMode.append);
    } on Object {
      // Logging must never break the app.
    }
  }

  /// Installs the global handlers.
  ///
  /// [onError] is called for every uncaught error so the UI can show a
  /// friendly message instead of a broken screen.
  static void install({required void Function(String message) onError}) {
    final previousOnError = FlutterError.onError;
    FlutterError.onError = (FlutterErrorDetails details) {
      log(
        'Flutter error: ${details.exceptionAsString()}',
        stack: details.stack,
      );
      previousOnError?.call(details);
      onError(details.exceptionAsString());
    };

    PlatformDispatcher.instance.onError = (Object error, StackTrace stack) {
      log('Uncaught error: $error', error: error, stack: stack);
      onError(error.toString());
      return true;
    };
  }
}
