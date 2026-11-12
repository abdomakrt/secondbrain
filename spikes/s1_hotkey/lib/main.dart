import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:tray_manager/legacy.dart' as tray;

/// Spike S1 (Phase 0): global hotkey + tray + PRIMARY selection + window
/// title on Mint/X11. Registers Ctrl+Alt+Space system-wide; on each trigger
/// logs the press timestamp, the PRIMARY selection content (via xclip) and
/// the active window title (via xdotool). Latency (hotkey→logged) is parsed
/// offline by the driver script; the spec target is <500ms ×20.
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await hotKeyManager.unregisterAll();

  final hotKey = HotKey(
    key: PhysicalKeyboardKey.keyJ,
    modifiers: [HotKeyModifier.control, HotKeyModifier.alt],
    scope: HotKeyScope.system,
  );

  await hotKeyManager.register(
    hotKey,
    keyDownHandler: (hotKey) async {
      final t0 = DateTime.now().millisecondsSinceEpoch;
      final primary = await Process.run('xclip', const [
        '-selection',
        'primary',
        '-o',
      ]);
      final title = await Process.run('xdotool', const [
        'getactivewindow',
        'getwindowname',
      ]);
      final t1 = DateTime.now().millisecondsSinceEpoch;
      // ignore: avoid_print
      print('S1HIT t0=$t0 t1=$t1 latency=${t1 - t0}ms '
          'primary="${primary.stdout.toString().trim()}" '
          'title="${title.stdout.toString().trim()}"');
    },
  );

  // Tray icon (spec §9.1) — setup must succeed on Mint/X11.
  try {
    await tray.TrayManager.instance.setToolTip('S1 spike');
    await tray.TrayManager.instance.setIcon('/tmp/opencode/s1_icon.png');
    // ignore: avoid_print
    print('S1TRAY ok');
  } on Object catch (e) {
    // ignore: avoid_print
    print('S1TRAY failed: $e');
  }
  // ignore: avoid_print
  print('S1READY hotkey=Ctrl+Alt+J registered');
  runApp(const _SpikeApp());
}

class _SpikeApp extends StatelessWidget {
  const _SpikeApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(body: Center(child: Text('S1 spike — Ctrl+Alt+Space'))),
    );
  }
}
