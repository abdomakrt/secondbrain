import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../platform/desktop/capture_service.dart';
import '../common/widgets/common_widgets.dart';
import '../capture/capture_window.dart';
import '../courses/course_edit_screen.dart';
import '../courses/courses_screen.dart';
import '../dashboard/dashboard_screen.dart';
import '../inbox/inbox_screen.dart';
import '../knowledge/daily_note.dart';
import '../knowledge/item_edit_screen.dart';
import '../knowledge/knowledge_home_screen.dart';
import '../knowledge/trash_screen.dart';
import '../projects/project_edit_screen.dart';
import '../projects/projects_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';
import '../tasks/task_edit_screen.dart';
import '../tasks/tasks_screen.dart';
import 'widgets/bottom_navigation.dart';
import 'widgets/global_search.dart';
import 'widgets/quick_add_menu.dart';
import 'widgets/sidebar.dart';

/// The main sections of the app (UI_SPEC §3).
enum AppSection {
  dashboard,
  tasks,
  projects,
  knowledge,
  courses,
  inbox,
  search,
  settings,
  trash,
}

/// App shell (UI_SPEC §7).
///
/// - Desktop: a fixed sidebar, a top bar (search, quick add, connection) and
///   an optional side details panel when the window is wide enough.
/// - Android: a bottom navigation bar with «المزيد» opening a sheet with the
///   remaining sections.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => AppShellState();
}

class AppShellState extends State<AppShell> {
  /// Width from which the desktop layout (sidebar) is used.
  static const double desktopBreakpoint = 900;

  /// Width from which a side details panel is shown next to the list.
  static const double detailPaneBreakpoint = 1100;

  AppSection _section = AppSection.dashboard;
  DesktopCaptureService? _capture;

  /// The text of the global search box (used by the quick-add button).
  final TextEditingController _searchController = TextEditingController();
  bool _searchHasText = false;
  Widget? _detail;
  String? _detailTitle;
  String? _searchQuery;

  static AppShellState? maybeOf(BuildContext context) =>
      context.findAncestorStateOfType<AppShellState>();

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_onSearchChanged);
  }

  void _onSearchChanged() {
    final hasText = _searchController.text.trim().isNotEmpty;
    if (hasText == _searchHasText) return;
    setState(() => _searchHasText = hasText);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final capture = AppScope.of(context).capture;
    if (identical(capture, _capture)) return;
    _capture?.request.removeListener(_onCaptureRequest);
    _capture = capture;
    _capture?.request.addListener(_onCaptureRequest);
  }

  @override
  void dispose() {
    _capture?.request.removeListener(_onCaptureRequest);
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  /// Opens the capture window when the global hot key fires.
  void _onCaptureRequest() {
    final capture = _capture;
    final request = capture?.request.value;
    if (capture == null || request == null) return;
    capture.consume();
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => CaptureWindow(
          platform: capture.platform,
          sharedText: request.text,
          sharedUrl: request.url,
          sourceTitle: request.title,
          sourceApp: request.app,
          sourceLabel: request.sourceLabel,
        ),
      ),
    );
  }

  /// Switches to another section (closes the details panel).
  void select(AppSection section) => setState(() {
        _section = section;
        _detail = null;
        _detailTitle = null;
      });

  /// Shows a details panel next to the list (desktop only).
  void showDetail({required String title, required Widget child}) =>
      setState(() {
        _detail = child;
        _detailTitle = title;
      });

  void closeDetail() => setState(() {
        _detail = null;
        _detailTitle = null;
      });

  /// Opens the unified search with a query.
  void openSearch([String? query]) => setState(() {
        _section = AppSection.search;
        _searchQuery = query;
        _detail = null;
        _detailTitle = null;
      });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.sizeOf(context).width;
    if (width >= AppShellState.desktopBreakpoint) {
      return _buildDesktop(context, width);
    }
    return _buildMobile(context);
  }

  // ---------------------------------------------------------------- desktop

  Widget _buildDesktop(BuildContext context, double width) {
    return Scaffold(
      body: SafeArea(
        child: Row(
          children: [
            Sidebar(
              current: _section,
              onSelect: select,
              onOpenSearch: openSearch,
            ),
            const VerticalDivider(width: 1),
            Expanded(
              child: Column(
                children: [
                  _DesktopTopBar(
                    title: _titleOf(context, _section),
                    onSearch: openSearch,
                    onAdd: () => _addForSection(context, _section),
                    onQuickAddFromSearch: () => _quickAddFromSearch(context),
                    sectionAddLabel: _addLabelFor(context, _section),
                    hasSearchText: _searchHasText,
                    searchController: _searchController,
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _sectionBody(context)),
                        if (_detail != null && width >= AppShellState.detailPaneBreakpoint) ...[
                          const VerticalDivider(width: 1),
                          SizedBox(
                            width: 420,
                            child: _DetailPane(
                              title: _detailTitle ?? '',
                              onClose: closeDetail,
                              child: _detail!,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ----------------------------------------------------------------- mobile

  Widget _buildMobile(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(_titleOf(context, _section)),
        actions: [
          IconButton(
            tooltip: l.search,
            icon: const Icon(Icons.search),
            onPressed: () => openSearch(),
          ),
          IconButton(
            tooltip: _addLabelFor(context, _section),
            icon: const Icon(Icons.add),
            onPressed: () => _addForSection(context, _section),
          ),
        ],
      ),
      body: _sectionBody(context),
      bottomNavigationBar: BottomNavigation(
        current: _section,
        onSelect: select,
        onMore: () => showMoreSheet(context),
      ),
    );
  }

  /// The «المزيد» sheet on Android: learning, inbox, settings and the trash.
  void showMoreSheet(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _MoreTile(
              icon: Icons.school_outlined,
              label: l.courses,
              onTap: () {
                Navigator.of(sheetContext).pop();
                select(AppSection.courses);
              },
            ),
            _MoreTile(
              icon: Icons.inbox_outlined,
              label: l.inbox,
              onTap: () {
                Navigator.of(sheetContext).pop();
                select(AppSection.inbox);
              },
            ),
            _MoreTile(
              icon: Icons.delete_outline,
              label: l.trash,
              onTap: () {
                Navigator.of(sheetContext).pop();
                select(AppSection.trash);
              },
            ),
            _MoreTile(
              icon: Icons.settings_outlined,
              label: l.settings,
              onTap: () {
                Navigator.of(sheetContext).pop();
                select(AppSection.settings);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // --------------------------------------------------------------- content

  Widget _sectionBody(BuildContext context) {
    return switch (_section) {
      AppSection.dashboard => DashboardScreen(onSelectSection: select),
      AppSection.tasks => const TasksScreen(),
      AppSection.projects => const ProjectsScreen(),
      AppSection.knowledge => const KnowledgeHomeScreen(),
      AppSection.courses => const CoursesScreen(),
      AppSection.inbox => const InboxScreen(),
      AppSection.search => SearchScreen(initialQuery: _searchQuery),
      AppSection.settings => const SettingsScreen(),
      AppSection.trash => const TrashScreen(),
    };
  }

  /// The quick-add button next to the search box.
  ///
  /// With text in the search box it saves that text as a note of the day;
  /// without text it opens the quick-add menu.
  Future<void> _quickAddFromSearch(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final text = _searchController.text.trim();
    if (text.isEmpty) {
      showQuickAddMenu(context);
      return;
    }
    try {
      await DailyNote.create(context, text);
    } on Object catch (e) {
      debugPrint('daily note failed: $e');
      if (!context.mounted) return;
      showErrorWithRetry(context, message: l.saveFailed);
      return;
    }
    if (!context.mounted) return;
    _searchController.clear();
    showToast(context, l.addedToTodayNotes);
  }

  /// The add action of the current section: every tab creates its own kind
  /// of item (UI_SPEC §3 — «زر خاص به للاضافة»).
  Future<void> _addForSection(BuildContext context, AppSection section) async {
    switch (section) {
      case AppSection.tasks:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const TaskEditScreen()),
        );
      case AppSection.projects:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ProjectEditScreen()),
        );
      case AppSection.knowledge:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const ItemEditScreen()),
        );
      case AppSection.courses:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CourseEditScreen()),
        );
      case AppSection.inbox:
        await Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => const CaptureWindow()),
        );
      default:
        showQuickAddMenu(context);
    }
  }

  /// The label of the section-specific add button.
  String _addLabelFor(BuildContext context, AppSection section) {
    final l = AppLocalizations.of(context)!;
    return switch (section) {
      AppSection.tasks => l.newTask,
      AppSection.projects => l.newProject,
      AppSection.knowledge => l.newItem,
      AppSection.courses => l.newCourse,
      AppSection.inbox => l.newCapture,
      _ => l.quickAdd,
    };
  }

  String _titleOf(BuildContext context, AppSection section) {
    final l = AppLocalizations.of(context)!;
    return switch (section) {
      AppSection.dashboard => l.dashboardTitle,
      AppSection.tasks => l.tasksTitle,
      AppSection.projects => l.projectsTitle,
      AppSection.knowledge => l.knowledgeTitle,
      AppSection.courses => l.coursesTitle,
      AppSection.inbox => l.inboxTitle,
      AppSection.search => l.searchTitle,
      AppSection.settings => l.settingsTitle,
      AppSection.trash => l.trashTitle,
    };
  }

}

class _MoreTile extends StatelessWidget {
  const _MoreTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}

/// The desktop top bar: unified search, quick add and connection status.
class _DesktopTopBar extends StatelessWidget {
  const _DesktopTopBar({
    required this.title,
    required this.onSearch,
    required this.onAdd,
    required this.onQuickAddFromSearch,
    required this.sectionAddLabel,
    required this.hasSearchText,
    required this.searchController,
  });

  final String title;
  final void Function([String?]) onSearch;
  final VoidCallback onAdd;
  final VoidCallback onQuickAddFromSearch;

  /// The label of the section-specific add button.
  final String sectionAddLabel;

  /// Whether the search box holds text.
  final bool hasSearchText;
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 220,
            child: Text(
              title,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: GlobalSearch(
              controller: searchController,
              onSubmitted: onSearch,
            ),
          ),
          const SizedBox(width: 8),
          // Next to the search: saves what the user typed as a note of the
          // day, or opens the quick-add menu when the box is empty.
          IconButton.filledTonal(
            tooltip: hasSearchText
                ? l.addSearchTextAsTodayNote
                : l.quickAdd,
            onPressed: onQuickAddFromSearch,
            icon: Icon(
              hasSearchText ? Icons.note_add_outlined : Icons.add,
            ),
          ),
          const SizedBox(width: 12),
          // The add button of the current section.
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: Text(sectionAddLabel),
          ),
        ],
      ),
    );
  }
}

/// The optional side details panel (desktop).
class _DetailPane extends StatelessWidget {
  const _DetailPane({
    required this.title,
    required this.onClose,
    required this.child,
  });

  final String title;
  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                tooltip: l.close,
                icon: const Icon(Icons.close),
                onPressed: onClose,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(child: child),
      ],
    );
  }
}

/// Opens a details screen: side pane on wide windows, a pushed route
/// otherwise (UI_SPEC §6).
Future<void> openDetail(
  BuildContext context, {
  required String title,
  required WidgetBuilder builder,
}) async {
  final shell = AppShellState.maybeOf(context);
  final width = MediaQuery.sizeOf(context).width;
  if (shell != null && width >= AppShellState.detailPaneBreakpoint) {
    shell.showDetail(title: title, child: builder(context));
    return;
  }
  await Navigator.of(context).push(
    MaterialPageRoute<void>(builder: builder),
  );
}
