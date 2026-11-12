import 'dart:async';

import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../core/text_normalizer.dart';
import '../../data/search_service.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/knowledge_filter_bar.dart';
import '../courses/course_detail_screen.dart';
import '../knowledge/item_detail_screen.dart';
import '../knowledge/widgets/type_icons.dart';
import '../projects/project_detail_screen.dart';
import '../shell/app_shell.dart';
import '../tasks/task_detail_screen.dart';

/// One result of the unified search, whatever its kind.
class UnifiedHit {
  const UnifiedHit({
    required this.kind,
    required this.id,
    required this.title,
    required this.snippet,
    required this.updatedAt,
    this.subtitle,
    this.rank = 0,
  });

  /// 'knowledge' | 'project' | 'task' | 'course'
  final String kind;
  final String id;
  final String title;
  final String snippet;
  final int updatedAt;
  final String? subtitle;
  final num rank;
}

/// Unified search (UI_SPEC §5, UI-09).
///
/// One box searches the knowledge base (FTS with bm25 ranking), the
/// projects, the tasks and the courses. Filters: type, project, tag, date.
/// Results are sorted by relevance, with an option to sort by newest.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key, this.initialQuery});

  final String? initialQuery;

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  late final TextEditingController _query =
      TextEditingController(text: widget.initialQuery ?? '');
  Timer? _debounce;

  String? _typeId;
  String? _projectId;
  String? _tagId;
  bool _newestFirst = false;

  List<UnifiedHit>? _hits;
  bool _loading = false;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    if ((widget.initialQuery ?? '').trim().isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _run());
    }
  }

  @override
  void dispose() {
    _query.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _schedule() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), _run);
  }

  Future<void> _run() async {
    final q = _query.text.trim();
    if (q.isEmpty) {
      setState(() {
        _hits = const [];
        _loading = false;
        _failed = false;
      });
      return;
    }
    setState(() {
      _loading = true;
      _failed = false;
    });
    try {
      final hits = await _search(q);
      if (!mounted) return;
      setState(() {
        _hits = hits;
        _loading = false;
      });
    } on Object catch (e) {
      debugPrint('search failed: $e');
      if (!mounted) return;
      setState(() {
        _loading = false;
        _failed = true;
      });
    }
  }

  Future<List<UnifiedHit>> _search(String q) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final hits = <UnifiedHit>[];

    // 1. Knowledge — full-text with bm25 ranking.
    final knowledge = await scope.search.search(
      q,
      filters: SearchFilters(
        typeId: _typeId,
        projectId: _projectId,
        tagId: _tagId,
      ),
    );
    for (final hit in knowledge) {
      hits.add(UnifiedHit(
        kind: 'knowledge',
        id: hit.item.id,
        title: hit.item.title.isEmpty ? hit.item.bodyMd : hit.item.title,
        snippet: hit.snippet(q),
        updatedAt: hit.item.updatedAt,
        rank: hit.rank,
      ));
    }

    final normalized = normalizeForSearch(q);
    bool matches(String? text) =>
        text != null && normalizeForSearch(text).contains(normalized);

    // 2. Projects.
    if (_projectId == null) {
      final projects = await scope.projects.all();
      for (final p in projects) {
        if (!matches(p.name) && !matches(p.goal) && !matches(p.description)) {
          continue;
        }
        hits.add(UnifiedHit(
          kind: 'project',
          id: p.id,
          title: p.name,
          snippet: p.goal.isEmpty ? p.description : p.goal,
          updatedAt: p.updatedAt,
        ));
      }
    }

    // 3. Tasks.
    final tasks = await (scope.db.select(scope.db.tasks)
          ..where((t) => t.deletedAt.isNull()))
        .get();
    for (final t in tasks) {
      if (_projectId != null && t.projectId != _projectId) continue;
      if (!matches(t.title) && !matches(t.notesMd)) continue;
      hits.add(UnifiedHit(
        kind: 'task',
        id: t.id,
        title: t.title,
        snippet: t.notesMd ?? '',
        updatedAt: t.updatedAt,
      ));
    }

    // 4. Courses and lessons.
    final courses = await scope.courses.all();
    for (final c in courses) {
      final lessons = await scope.courses.lessonsOf(c.id);
      final lessonHit = lessons.where((x) => matches(x.title)).toList();
      if (!matches(c.title) &&
          !matches(c.description) &&
          lessonHit.isEmpty) {
        continue;
      }
      hits.add(UnifiedHit(
        kind: 'course',
        id: c.id,
        title: c.title,
        snippet: lessonHit.isEmpty
            ? c.description
            : '${l.lessonsLabel}: ${lessonHit.map((x) => x.title).join('، ')}',
        updatedAt: c.updatedAt,
      ));
    }

    if (_newestFirst) {
      hits.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    } else {
      hits.sort((a, b) {
        final ra = a.rank;
        final rb = b.rank;
        if (a.kind == 'knowledge' && b.kind == 'knowledge') {
          return ra.compareTo(rb);
        }
        if (a.kind == 'knowledge') return -1;
        if (b.kind == 'knowledge') return 1;
        return b.updatedAt.compareTo(a.updatedAt);
      });
    }
    return hits;
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: TextField(
            controller: _query,
            autofocus: (widget.initialQuery ?? '').isEmpty,
            onChanged: (_) => _schedule(),
            onSubmitted: (_) => _run(),
            textInputAction: TextInputAction.search,
            decoration: InputDecoration(
              hintText: l.searchHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
            ),
          ),
        ),
        KnowledgeFilterBar(
          typeId: _typeId,
          projectId: _projectId,
          tagId: _tagId,
          newestFirst: _newestFirst,
          onType: (v) {
            setState(() => _typeId = v);
            _run();
          },
          onProject: (v) {
            setState(() => _projectId = v);
            _run();
          },
          onTag: (v) {
            setState(() => _tagId = v);
            _run();
          },
          onNewest: (v) {
            setState(() => _newestFirst = v);
            _run();
          },
          onClear: () {
            setState(() {
              _typeId = null;
              _projectId = null;
              _tagId = null;
            });
            _run();
          },
        ),
        Expanded(
          child: _body(context, scope),
        ),
      ],
    );
  }

  Widget _body(BuildContext context, AppScope scope) {
    final l = AppLocalizations.of(context)!;
    if (_failed) {
      return EmptyState(
        icon: Icons.error_outline,
        title: l.searchFailed,
        message: l.searchFailedHint,
        actionLabel: l.retry,
        onAction: _run,
      );
    }
    if (_loading) {
      return const LoadingView();
    }
    final hits = _hits;
    if (hits == null || hits.isEmpty) {
      if (_query.text.trim().isEmpty) {
        return EmptyState(
          icon: Icons.search,
          title: l.searchStartTitle,
          message: l.searchStartHint,
        );
      }
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: l.noResults,
        message: l.noResultsHint,
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.only(bottom: 96),
      itemCount: hits.length,
      itemBuilder: (context, i) => _HitTile(hit: hits[i]),
    );
  }
}

class _HitTile extends StatelessWidget {
  const _HitTile({required this.hit});

  final UnifiedHit hit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final (IconData icon, String kindLabel) = switch (hit.kind) {
      'knowledge' => (Icons.lightbulb_outline, l.knowledgeTitle),
      'project' => (Icons.folder_outlined, l.projectsTitle),
      'task' => (Icons.checklist_outlined, l.tasksTitle),
      _ => (Icons.school_outlined, l.coursesTitle),
    };

    return ListTile(
      onTap: () => _open(context),
      leading: Icon(icon, color: theme.colorScheme.primary),
      title: Text(
        hit.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hit.snippet.isEmpty ? kindLabel : hit.snippet,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 2),
          Text(
            '$kindLabel • ${formatStamp(hit.updatedAt)}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
      isThreeLine: true,
    );
  }

  void _open(BuildContext context) {
    switch (hit.kind) {
      case 'knowledge':
        openDetail(
          context,
          title: hit.title,
          builder: (_) => ItemDetailScreen(itemId: hit.id),
        );
      case 'project':
        openDetail(
          context,
          title: hit.title,
          builder: (_) => ProjectDetailScreen(projectId: hit.id),
        );
      case 'task':
        openDetail(
          context,
          title: hit.title,
          builder: (_) => TaskDetailScreen(taskId: hit.id),
        );
      default:
        openDetail(
          context,
          title: hit.title,
          builder: (_) => CourseDetailScreen(courseId: hit.id),
        );
    }
  }
}
