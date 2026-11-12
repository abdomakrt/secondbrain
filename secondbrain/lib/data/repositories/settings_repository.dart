import 'package:drift/drift.dart';

import '../database.dart';
import '../write_gate.dart';

/// Local (never synced) key/value settings.
///
/// Writes still go through [WriteGate] so every mutation happens inside a
/// transaction; settings rows are not stamped into the oplog because they are
/// device-local by design (spec §5.3).
class SettingsRepository {
  SettingsRepository({required this.db, required this.gate});

  final AppDatabase db;
  final WriteGate gate;

  /// Known setting keys.
  static const keyThemeMode = 'theme_mode';
  static const keyLocale = 'locale';
  static const keySetupDone = 'setup_completed';
  static const keyActiveCaptureProject = 'active_capture_project_id';
  static const keyCaptureShortcut = 'capture_shortcut';
  static const keyDashboardOrder = 'dashboard_order';
  static const keyServerAddress = 'server_address';
  static const keyPairingCode = 'pairing_code';
  static const keyWeekStart = 'week_start';

  Future<String?> get(String key) async {
    final row = await (db.select(db.settings)..where((s) => s.key.equals(key)))
        .getSingleOrNull();
    return row?.value;
  }

  Future<bool> getBool(String key, {bool fallback = false}) async {
    final value = await get(key);
    if (value == null) return fallback;
    return value == '1' || value == 'true';
  }

  Future<void> set(String key, String value) => gate.write((tx) async {
        final existing = await (tx.db.select(tx.db.settings)
              ..where((s) => s.key.equals(key)))
            .getSingleOrNull();
        if (existing != null) {
          await (tx.db.update(tx.db.settings)..where((s) => s.key.equals(key)))
              .write(SettingsCompanion(value: Value(value)));
        } else {
          await tx.db.into(tx.db.settings)
              .insert(SettingsCompanion.insert(key: key, value: value));
        }
      });

  Future<void> setBool(String key, bool value) =>
      set(key, value ? '1' : '0');

  /// Live value of a setting (null when unset).
  Stream<String?> watch(String key) =>
      (db.select(db.settings)..where((s) => s.key.equals(key)))
          .watchSingleOrNull()
          .map((row) => row?.value);
}
