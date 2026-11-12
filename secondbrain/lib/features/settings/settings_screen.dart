import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../data/repositories/settings_repository.dart';
import '../../platform/desktop/x11_tools.dart';
import '../../sync/connection.dart';
import '../backup/backup_screen.dart';
import '../capture/capture_window.dart';
import '../common/dialogs.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/connection_status_badge.dart';
import '../importers/keep_import_screen.dart';
import '../shell/app_shell.dart';

/// Settings (UI_SPEC §5, UI-15).
///
/// Language and appearance, dashboard customisation, tags and content types,
/// task settings, the quick-capture shortcut, paired devices, the server
/// address and the connection state, backup/restore, export and the app
/// information.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  String _themeMode = 'system';
  String _shortcut = 'Ctrl + Alt + Shift + C';
  String? _hotkeyStatus;
  Map<String, String> _x11 = const {};
  String _serverAddress = '';
  String? _activeCaptureProject;
  Map<String, String> _projectNames = const {};
  final List<String> _hiddenSections = [];

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final theme =
        await scope.settings.get(SettingsRepository.keyThemeMode) ?? 'system';
    final shortcut = await scope.settings
            .get(SettingsRepository.keyCaptureShortcut) ??
        'Ctrl + Alt + Shift + C';
    final address =
        await scope.settings.get(SettingsRepository.keyServerAddress) ?? '';
    final captureProject = await scope.settings
        .get(SettingsRepository.keyActiveCaptureProject);
    final projects = await scope.projects.all();
    final x11 = X11Tools().diagnostics();
    if (!mounted) return;
    setState(() {
      _x11 = x11;
      _themeMode = theme;
      _shortcut = shortcut;
      _serverAddress = address;
      _activeCaptureProject =
          captureProject == null || captureProject.isEmpty ? null : captureProject;
      _projectNames = {for (final p in projects) p.id: p.name};
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return ListView(
      padding: const EdgeInsets.only(bottom: 96),
      children: [
        _SectionHeader(title: l.languageAndAppearance),
        ListTile(
          leading: const Icon(Icons.language_outlined),
          title: Text(l.language),
          subtitle: Text(l.arabicOnly),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _showLanguageInfo(context),
        ),
        ListTile(
          leading: const Icon(Icons.brightness_6_outlined),
          title: Text(l.theme),
          subtitle: Text(_themeLabel(context, _themeMode)),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _pickTheme(context),
        ),
        const Divider(),
        _SectionHeader(title: l.dashboardCustomization),
        _DashboardSections(
          hidden: _hiddenSections,
          onToggle: (key, visible) async {
            setState(() {
              if (visible) {
                _hiddenSections.remove(key);
              } else {
                _hiddenSections.add(key);
              }
            });
            await scope.settings.set(
              SettingsRepository.keyDashboardOrder,
              _hiddenSections.join(','),
            );
          },
        ),
        const Divider(),
        _SectionHeader(title: l.tagsAndTypes),
        ListTile(
          leading: const Icon(Icons.sell_outlined),
          title: Text(l.manageTags),
          subtitle: Text(l.manageTagsHint),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _showTags(context),
        ),
        ListTile(
          leading: const Icon(Icons.category_outlined),
          title: Text(l.manageTypes),
          subtitle: Text(l.manageTypesHint),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _showTypes(context),
        ),
        const Divider(),
        _SectionHeader(title: l.taskSettings),
        ListTile(
          leading: const Icon(Icons.event_repeat_outlined),
          title: Text(l.weekStart),
          subtitle: Text(l.weekStartsSaturday),
        ),
        ListTile(
          leading: const Icon(Icons.notifications_outlined),
          title: Text(l.reminders),
          subtitle: Text(l.remindersComingSoon),
        ),
        const Divider(),
        _SectionHeader(title: l.quickCapture),
        ListTile(
          leading: const Icon(Icons.bolt_outlined),
          title: Text(l.captureShortcut),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_shortcut),
              if (_hotkeyStatus != null)
                Text(
                  _hotkeyStatus!,
                  style: Theme.of(context).textTheme.labelSmall,
                ),
            ],
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _pickShortcut(context),
        ),
        ListTile(
          leading: const Icon(Icons.terminal),
          title: Text(l.desktopEnvironment),
          subtitle: Text(
            _x11.isEmpty
                ? l.desktopEnvironmentUnknown
                : '${l.session}: ${_x11['session']} • '
                    '${l.display}: ${_x11['display']} • '
                    'xclip: ${_x11['xclip']} • '
                    'xinput: ${_x11['xinput']}',
          ),
        ),
        ListTile(
          leading: const Icon(Icons.center_focus_strong_outlined),
          title: Text(l.activeCaptureProject),
          subtitle: Text(
            _activeCaptureProject == null
                ? l.inboxIsDefaultDestination
                : (_projectNames[_activeCaptureProject] ?? '—'),
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _pickCaptureProject(context),
        ),
        ListTile(
          leading: const Icon(Icons.open_in_new),
          title: Text(l.openCaptureWindow),
          subtitle: Text(l.captureWindowHint),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute<void>(builder: (_) => const CaptureWindow()),
          ),
        ),
        const Divider(),
        _SectionHeader(title: l.devicesAndConnection),
        ListTile(
          leading: const Icon(Icons.devices_outlined),
          title: Text(l.pairedDevices),
          subtitle: Text(l.noPairedDevices),
        ),
        ListTile(
          leading: const Icon(Icons.dns_outlined),
          title: Text(l.serverAddress),
          subtitle: Text(
            _serverAddress.isEmpty ? l.notSet : _serverAddress,
          ),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _editServerAddress(context),
        ),
        ListTile(
          leading: const Icon(Icons.network_check),
          title: Text(l.connectionStatus),
          subtitle: Text(l.syncNotEnabledYet),
        ),
        ListTile(
          leading: const Icon(Icons.wifi_tethering),
          title: Text(l.testConnection),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => _testConnection(context),
        ),
        const Divider(),
        _SectionHeader(title: l.backupAndData),
        ListTile(
          leading: const Icon(Icons.backup_outlined),
          title: Text(l.backupTitle),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => openDetail(
            context,
            title: l.backupTitle,
            builder: (_) => const BackupScreen(),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.download_outlined),
          title: Text(l.exportMd),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => openDetail(
            context,
            title: l.exportMd,
            builder: (_) => const BackupScreen(),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.book_outlined),
          title: Text(l.keepImport),
          subtitle: Text(l.keepImportDeferred),
          trailing: const Icon(Icons.chevron_left),
          onTap: () => openDetail(
            context,
            title: l.keepImport,
            builder: (_) => const KeepImportScreen(),
          ),
        ),
        const Divider(),
        _SectionHeader(title: l.about),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: Text(l.appTitle),
          subtitle: Text(l.versionInfo),
        ),
      ],
    );
  }

  String _themeLabel(BuildContext context, String mode) {
    final l = AppLocalizations.of(context)!;
    return switch (mode) {
      'light' => l.themeLight,
      'dark' => l.themeDark,
      _ => l.themeSystem,
    };
  }

  Future<void> _pickTheme(BuildContext context) async {
    final scope = AppScope.of(context);
    final mode = await showOptionSheet<String>(
      context,
      options: [
        for (final m in const ['system', 'light', 'dark'])
          SheetOption(m, _themeLabel(context, m)),
      ],
    );
    if (mode == null) return;
    await scope.settings.set(SettingsRepository.keyThemeMode, mode);
    if (!mounted) return;
    setState(() => _themeMode = mode);
  }

  void _showLanguageInfo(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.language),
        content: Text(l.englishComingSoon),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.close),
          ),
        ],
      ),
    );
  }

  Future<void> _pickShortcut(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final result = await showTextPrompt(
      context,
      title: l.captureShortcut,
      label: l.captureShortcutHint,
      initialValue: _shortcut,
    );
    if (result == null) return;
    final shortcut = result.trim();
    await scope.settings
        .set(SettingsRepository.keyCaptureShortcut, shortcut);
    if (!mounted) return;
    setState(() => _shortcut = shortcut);
    // Verify the shortcut for real: the app starts listening for it and
    // reports whether the registration worked (UI_SPEC UI-13).
    final capture = scope.capture;
    if (capture == null) {
      setState(() => _hotkeyStatus = l.captureNotAvailable);
    } else {
      final ok = await capture.start(shortcut);
      if (!mounted) return;
      setState(() => _hotkeyStatus = capture.status.value);
      if (!context.mounted) return;
      showToast(
        context,
        ok ? l.shortcutRegistered : l.shortcutFailed,
      );
    }
  }

  Future<void> _pickCaptureProject(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final projects = await scope.projects.all();
    if (!context.mounted) return;
    final picked = await showOptionSheet<String>(
      context,
      options: [
        SheetOption('', l.inboxIsDefaultDestination,
            icon: Icons.inbox_outlined),
        for (final p in projects)
          SheetOption(p.id, p.name, icon: Icons.folder_outlined),
      ],
    );
    if (picked == null) return;
    await scope.settings.set(
        SettingsRepository.keyActiveCaptureProject, picked);
    if (!mounted) return;
    setState(() {
      _activeCaptureProject = picked.isEmpty ? null : picked;
      _projectNames = {
        for (final p in projects) p.id: p.name,
      };
    });
  }

  Future<void> _editServerAddress(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final result = await showTextPrompt(
      context,
      title: l.serverAddress,
      hint: '192.168.1.10:8443',
      initialValue: _serverAddress,
    );
    if (result == null) return;
    await scope.settings
        .set(SettingsRepository.keyServerAddress, result.trim());
    if (!mounted) return;
    setState(() => _serverAddress = result.trim());
  }

  Future<void> _testConnection(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final result = await scope.connection.test(serverAddress: _serverAddress);
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.connectionTestResult),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ConnectionStatusBadge(state: result.state),
            const SizedBox(height: 8),
            Text(result.message ?? result.state.label),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.close),
          ),
        ],
      ),
    );
  }

  Future<void> _showTags(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final tags = await scope.tags.all();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.manageTags),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              if (tags.isEmpty)
                Text(l.noTagsYet)
              else
                for (final t in tags)
                  ListTile(
                    dense: true,
                    leading: const Icon(Icons.sell_outlined),
                    title: Text(t.name),
                  ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.close),
          ),
        ],
      ),
    );
  }

  Future<void> _showTypes(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final types = await (scope.db.select(scope.db.itemTypes)
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
    if (!context.mounted) return;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l.manageTypes),
        content: SizedBox(
          width: 320,
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final t in types)
                ListTile(
                  dense: true,
                  leading: const Icon(Icons.category_outlined),
                  title: Text(t.name),
                  subtitle: t.isBuiltin ? Text(l.builtinType) : null,
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l.close),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
      child: Text(
        title,
        style: theme.textTheme.titleSmall?.copyWith(
          color: theme.colorScheme.primary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
}

/// Dashboard section visibility (UI_SPEC §10, phase 3).
class _DashboardSections extends StatelessWidget {
  const _DashboardSections({required this.hidden, required this.onToggle});

  final List<String> hidden;
  final void Function(String key, bool visible) onToggle;

  static const _keys = [
    'summary',
    'tasks',
    'timeline',
    'projects',
    'course',
    'knowledge',
    'inbox',
  ];

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final labels = <String, String>{
      'summary': l.todaySummary,
      'tasks': l.topTasksToday,
      'timeline': l.dayTimeline,
      'projects': l.activeProjects,
      'course': l.currentCourse,
      'knowledge': l.recentKnowledge,
      'inbox': l.inboxNeedsOrganizing,
    };
    return Column(
      children: [
        for (final key in _keys)
          SwitchListTile(
            dense: true,
            title: Text(labels[key] ?? key),
            value: !hidden.contains(key),
            onChanged: (v) => onToggle(key, v),
          ),
      ],
    );
  }
}
