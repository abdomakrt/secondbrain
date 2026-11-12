import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';


import '../data/repositories/settings_repository.dart';
import '../features/setup/setup_screen.dart';
import '../features/shell/app_shell.dart';
import 'app_deps.dart';
import 'app_scope.dart';

/// The navigator of the app — used to show the global error dialog.
final GlobalKey<NavigatorState> appNavigatorKey = GlobalKey<NavigatorState>();

/// Shows a friendly error dialog instead of leaving a broken screen.
void showGlobalErrorDialog(String message) {
  final navigator = appNavigatorKey.currentState;
  if (navigator == null) return;
  final l = AppLocalizations.of(navigator.context);
  if (l == null) return;
  navigator.push(
    MaterialPageRoute<void>(
      builder: (context) => Scaffold(
        appBar: AppBar(title: Text(l.errorTitle)),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.error_outline, size: 48),
                const SizedBox(height: 12),
                Text(l.errorBody, textAlign: TextAlign.center),
                const SizedBox(height: 8),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: themeOf(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: Text(l.close),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

ThemeData themeOf(BuildContext context) => Theme.of(context);

/// Root widget: RTL Arabic Material app wired to the local database.
///
/// The first run shows the setup wizard (UI-01); afterwards the app shell
/// (UI_SPEC §3) hosts every section.
class SecondBrainApp extends StatefulWidget {
  const SecondBrainApp({super.key, required this.deps});

  final AppDeps deps;

  @override
  State<SecondBrainApp> createState() => _SecondBrainAppState();
}

class _SecondBrainAppState extends State<SecondBrainApp> {
  bool _setupChecked = false;
  bool _setupDone = false;

  @override
  void initState() {
    super.initState();
    _checkSetup();
  }

  @override
  void didUpdateWidget(covariant SecondBrainApp old) {
    super.didUpdateWidget(old);
    if (old.deps.db != widget.deps.db) _checkSetup();
  }

  Future<void> _checkSetup() async {
    final done = await widget.deps.settings
        .getBool(SettingsRepository.keySetupDone);
    if (!mounted) return;
    setState(() {
      _setupChecked = true;
      _setupDone = done;
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<String?>(
      stream: widget.deps.settings.watch(SettingsRepository.keyThemeMode),
      builder: (context, snap) {
        final themeMode = switch (snap.data) {
          'light' => ThemeMode.light,
          'dark' => ThemeMode.dark,
          _ => ThemeMode.system,
        };
        return MaterialApp(
          navigatorKey: appNavigatorKey,
          onGenerateTitle: (context) => AppLocalizations.of(context)!.appTitle,
          theme: _theme(Brightness.light),
          darkTheme: _theme(Brightness.dark),
          themeMode: themeMode,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          builder: (context, child) => AppScope(
            deps: widget.deps,
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: child!,
            ),
          ),
          home: !_setupChecked
              ? const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                )
              : _setupDone
                  ? const AppShell()
                  : SetupScreen(
                      onFinished: () => setState(() => _setupDone = true),
                    ),
        );
      },
    );
  }

  ThemeData _theme(Brightness brightness) {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF3F51B5),
      brightness: brightness,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: 'NotoSansArabic',
      appBarTheme: AppBarTheme(
        backgroundColor: scheme.surface,
        foregroundColor: scheme.onSurface,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: const InputDecorationTheme(
        border: OutlineInputBorder(),
      ),
    );
  }
}
