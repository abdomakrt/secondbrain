import 'dart:io';

import 'package:flutter/material.dart';

import 'app/app.dart';
import 'app/app_deps.dart';
import 'backup/backup_service.dart';
import 'core/app_logger.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  AppLogger.install(onError: showGlobalErrorDialog);
  runApp(const SecondBrainRoot());
}

/// Holds the live [AppDeps]; a successful restore replaces the bundle and
/// rebuilds the whole app on the new database connection. Restore screens
/// publish the new bundle via [appDepsSwapRequest].
class SecondBrainRoot extends StatefulWidget {
  const SecondBrainRoot({super.key});

  @override
  State<SecondBrainRoot> createState() => _SecondBrainRootState();
}

class _SecondBrainRootState extends State<SecondBrainRoot> {
  AppDeps? _deps;

  @override
  void initState() {
    super.initState();
    appDepsSwapRequest.addListener(_onSwapRequested);
    _open();
  }

  @override
  void dispose() {
    appDepsSwapRequest.removeListener(_onSwapRequested);
    super.dispose();
  }

  void _onSwapRequested() {
    final fresh = appDepsSwapRequest.value;
    if (fresh != null && mounted) setState(() => _deps = fresh);
  }

  Future<void> _open() async {
    final support = await AppDeps.defaultSupportDir();
    await AppLogger.init(support);
    final deps = await AppDeps.open(support);
    if (mounted) setState(() => _deps = deps);
    // Daily auto backup, best-effort (spec §11.1; opt-in via settings).
    try {
      await BackupService(deps: deps).maybeDailyBackup(
        destDir: Directory('${support.path}/backups'),
      );
    } on Object catch (e) {
      debugPrint('auto backup failed: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final deps = _deps;
    if (deps == null) {
      return const Directionality(
        textDirection: TextDirection.rtl,
        child: MaterialApp(home: Scaffold(body: Center(
          child: CircularProgressIndicator(),
        ))),
      );
    }
    return SecondBrainApp(deps: deps);
  }
}
