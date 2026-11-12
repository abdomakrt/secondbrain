import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_deps.dart';
import '../../app/app_scope.dart';
import '../../backup/backup_service.dart';
import '../../data/repositories/settings_repository.dart';
import '../../sync/connection.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/content_width.dart';
import '../common/widgets/connection_status_badge.dart';

/// Welcome and first-run setup (UI_SPEC §5, UI-01).
///
/// Starts the app without any technical setup: language and appearance, then
/// either a fresh start or restoring a backup, then the optional pairing with
/// the computer.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key, required this.onFinished});

  final VoidCallback onFinished;

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  int _step = 0;
  String _themeMode = 'system';
  String _serverAddress = '';
  final _pairingCode = TextEditingController();
  SyncConnectionState _connection = SyncConnectionState.notConfigured;
  String? _connectionMessage;
  bool _busy = false;

  @override
  void dispose() {
    _pairingCode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ContentWidth(
                maxWidth: ContentWidths.form,
                child: Stepper(
                  currentStep: _step,
                  onStepTapped: (s) => setState(() => _step = s),
                  controlsBuilder: (context, details) =>
                      const SizedBox.shrink(),
                  steps: [
                    Step(
                      title: Text(l.setupWelcome),
                      isActive: _step >= 0,
                      state: _step > 0 ? StepState.complete : StepState.indexed,
                      content: _WelcomeStep(
                        themeMode: _themeMode,
                        onTheme: (m) => setState(() => _themeMode = m),
                      ),
                    ),
                    Step(
                      title: Text(l.setupData),
                      isActive: _step >= 1,
                      state: _step > 1 ? StepState.complete : StepState.indexed,
                      content: _DataStep(
                        busy: _busy,
                        onNewSetup: _newSetup,
                        onRestore: _restoreBackup,
                      ),
                    ),
                    Step(
                      title: Text(l.setupPairing),
                      isActive: _step >= 2,
                      state: _step > 2 ? StepState.complete : StepState.indexed,
                      content: _PairingStep(
                        serverAddress: _serverAddress,
                        pairingCode: _pairingCode,
                        state: _connection,
                        message: _connectionMessage,
                        onAddress: (v) => setState(() => _serverAddress = v),
                        onCode: (v) => _pairingCode.text = v,
                        onTest: _testConnection,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: ContentWidth(
                maxWidth: ContentWidths.form,
                child: Row(
                  children: [
                    if (_step > 0)
                      TextButton(
                        onPressed: () => setState(() => _step--),
                        child: Text(l.back),
                      ),
                    const Spacer(),
                    if (_step < 2)
                      FilledButton(
                        onPressed: () => setState(() => _step++),
                        child: Text(l.next),
                      )
                    else
                      FilledButton.icon(
                        onPressed: _finish,
                        icon: const Icon(Icons.check),
                        label: Text(l.finishSetup),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _newSetup() async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    await scope.settings.set(SettingsRepository.keyThemeMode, _themeMode);
    if (!mounted) return;
    setState(() => _step = 2);
    showToast(context, l.newSetupReady);
  }

  Future<void> _restoreBackup() async {
    final l = AppLocalizations.of(context)!;
    final picked = await openFile();
    if (picked == null || !mounted) return;
    setState(() => _busy = true);
    final restored = await _doRestore(File(picked.path));
    if (!mounted) return;
    setState(() => _busy = false);
    if (restored == null) {
      showErrorWithRetry(context, message: l.restoreFailed);
      return;
    }
    appDepsSwapRequest.value = restored;
    setState(() => _step = 2);
    showToast(context, l.restoreDone);
  }

  /// Restores a backup; returns null when it failed.
  Future<AppDeps?> _doRestore(File file) async {
    final scope = AppScope.of(context);
    try {
      final result = await BackupService(deps: scope.deps).restore(
        backupFile: file,
        supportDir: scope.deps.supportDir,
        current: scope.deps,
      );
      return result.deps;
    } on Object catch (e) {
      debugPrint('setup restore failed: $e');
      return null;
    }
  }

  Future<void> _testConnection() async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    setState(() {
      _connection = SyncConnectionState.connecting;
      _connectionMessage = null;
    });
    final result = await scope.connection.test(
      serverAddress: _serverAddress,
      pairingCode: _pairingCode.text.trim(),
    );
    if (!mounted) return;
    await scope.settings.set(
      SettingsRepository.keyServerAddress,
      _serverAddress.trim(),
    );
    if (!mounted) return;
    setState(() {
      _connection = result.state;
      _connectionMessage = result.message;
    });
    if (result.state == SyncConnectionState.connected) {
      if (mounted) showToast(context, l.connected);
    }
  }

  Future<void> _finish() async {
    final scope = AppScope.of(context);
    await scope.settings.setBool(SettingsRepository.keySetupDone, true);
    if (!mounted) return;
    widget.onFinished();
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep({required this.themeMode, required this.onTheme});

  final String themeMode;
  final ValueChanged<String> onTheme;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          l.appTitle,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(l.appTagline),
        const SizedBox(height: 16),
        Text(l.language, style: theme.textTheme.titleSmall),
        const SizedBox(height: 4),
        Text(l.arabicOnly),
        const SizedBox(height: 16),
        Text(l.theme, style: theme.textTheme.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final m in const ['system', 'light', 'dark'])
              ChoiceChip(
                selected: themeMode == m,
                label: Text(switch (m) {
                  'light' => l.themeLight,
                  'dark' => l.themeDark,
                  _ => l.themeSystem,
                }),
                onSelected: (_) => onTheme(m),
              ),
          ],
        ),
      ],
    );
  }
}

class _DataStep extends StatelessWidget {
  const _DataStep({
    required this.busy,
    required this.onNewSetup,
    required this.onRestore,
  });

  final bool busy;
  final VoidCallback onNewSetup;
  final VoidCallback onRestore;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.setupDataHint),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: busy ? null : onNewSetup,
          icon: const Icon(Icons.auto_awesome_outlined),
          label: Text(l.setupNew),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: busy ? null : onRestore,
          icon: const Icon(Icons.restore),
          label: Text(l.setupRestore),
        ),
        if (busy) ...[const SizedBox(height: 16), const LoadingView()],
      ],
    );
  }
}

class _PairingStep extends StatelessWidget {
  const _PairingStep({
    required this.serverAddress,
    required this.pairingCode,
    required this.state,
    required this.message,
    required this.onAddress,
    required this.onCode,
    required this.onTest,
  });

  final String serverAddress;
  final TextEditingController pairingCode;
  final SyncConnectionState state;
  final String? message;
  final ValueChanged<String> onAddress;
  final ValueChanged<String> onCode;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l.setupPairingHint),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l.setupServerHint, style: theme.textTheme.titleSmall),
                const SizedBox(height: 4),
                Text(
                  'secondbrain --serve',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontFamily: 'monospace',
                  ),
                  textDirection: TextDirection.ltr,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            ConnectionStatusBadge(state: state),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message ?? '', style: theme.textTheme.bodySmall),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          onChanged: onAddress,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l.serverAddress,
            hintText: '192.168.1.10:8443',
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: pairingCode,
          onChanged: onCode,
          textDirection: TextDirection.ltr,
          decoration: InputDecoration(
            labelText: l.pairingCode,
            border: const OutlineInputBorder(),
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          onPressed: onTest,
          icon: const Icon(Icons.network_check),
          label: Text(l.testConnection),
        ),
        const SizedBox(height: 8),
        Text(l.setupQrHint, style: theme.textTheme.bodySmall),
      ],
    );
  }
}
