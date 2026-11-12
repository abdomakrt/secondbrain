import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../data/database.dart';
import '../../data/search_service.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/db_stream_builder.dart';
import '../common/widgets/knowledge_card.dart';
import '../common/widgets/knowledge_filter_bar.dart';
import '../shell/app_shell.dart';
import 'item_detail_screen.dart';

/// Knowledge browser (UI_SPEC §5, UI-07).
///
/// Everything the user saved: notes, ideas, links, decisions, summaries…
/// Types are flexible labels — there is no separate screen per type.
/// Filters: type, project, tag; plus a free text search.
class KnowledgeHomeScreen extends StatefulWidget {
  const KnowledgeHomeScreen({super.key});

  @override
  State<KnowledgeHomeScreen> createState() => _KnowledgeHomeScreenState();
}

class _KnowledgeHomeScreenState extends State<KnowledgeHomeScreen> {
  String _query = '';
  String? _typeId;
  String? _projectId;
  String? _tagId;
  Map<String, String> _projectNames = const {};

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _loadProjects();
  }

  Future<void> _loadProjects() async {
    final scope = AppScope.of(context);
    final projects = await scope.projects.all();
    if (!mounted) return;
    setState(() {
      _projectNames = {for (final p in projects) p.id: p.name};
    });
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim()),
            decoration: InputDecoration(
              hintText: l.searchKnowledgeHint,
              prefixIcon: const Icon(Icons.search),
              border: const OutlineInputBorder(),
              isDense: true,
            ),
          ),
        ),
        KnowledgeFilterBar(
          typeId: _typeId,
          projectId: _projectId,
          tagId: _tagId,
          onType: (v) => setState(() => _typeId = v),
          onProject: (v) => setState(() => _projectId = v),
          onTag: (v) => setState(() => _tagId = v),
          onClear: () => setState(() {
            _typeId = null;
            _projectId = null;
            _tagId = null;
          }),
        ),        Expanded(
          child: _query.isEmpty
              ? _itemList(context, scope)
              : _searchResults(context, scope),
        ),
      ],
    );
  }

  Widget _itemList(BuildContext context, AppScope scope) {
    final l = AppLocalizations.of(context)!;
    return StreamBuilder<List<Item>>(
      stream: scope.items.watchList(
        onlyInbox: false,
        onlyArchived: false,
        typeId: _typeId,
        tagId: _tagId,
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const LoadingView();
        }
        var items = snap.data!;
        if (_projectId != null) {
          items = items.where((i) => i.projectId == _projectId).toList();
        }
        if (items.isEmpty) {
          return EmptyState(
            icon: Icons.lightbulb_outline,
            title: l.emptyKnowledge,
            message: l.emptyKnowledgeHint,
          );
        }
        return _Cards(
          items: items,
          projectNames: _projectNames,
        );
      },
    );
  }

  Widget _searchResults(BuildContext context, AppScope scope) {
    final l = AppLocalizations.of(context)!;
    return FutureBuilder<List<SearchHit>>(
      future: scope.search.search(
        _query,
        filters: SearchFilters(
          typeId: _typeId,
          projectId: _projectId,
          tagId: _tagId,
        ),
      ),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const LoadingView();
        }
        final hits = snap.data!;
        if (hits.isEmpty) {
          return EmptyState(
            icon: Icons.search_off_outlined,
            title: l.noResults,
            message: l.noResultsHint,
          );
        }
        return _Cards(
          items: hits.map((h) => h.item).toList(),
          projectNames: _projectNames,
          snippets: {
            for (final h in hits) h.item.id: h.snippet(_query),
          },
        );
      },
    );
  }
}

class _Cards extends StatelessWidget {
  const _Cards({
    required this.items,
    required this.projectNames,
    this.snippets = const {},
  });

  final List<Item> items;
  final Map<String, String> projectNames;
  final Map<String, String> snippets;

  @override
  Widget build(BuildContext context) {
    final scope = AppScope.of(context);
    return DbStreamBuilder<List<ItemType>>(
      streamFactory: () => scope.itemTypes.watchBuiltin(),
      builder: (context, typeSnap) {
        final types = typeSnap.data ?? const <ItemType>[];
        final names = {for (final t in types) t.id: t.name};
        return ListView.builder(
          padding: const EdgeInsets.only(top: 8, bottom: 96),
          itemCount: items.length,
          itemBuilder: (context, i) {
            final item = items[i];
            return KnowledgeCard(
              item: item,
              typeName: names[item.typeId],
              projectName:
                  item.projectId == null ? null : projectNames[item.projectId],
              onTap: () => openDetail(
                context,
                title: item.title.isEmpty ? item.bodyMd : item.title,
                builder: (_) => ItemDetailScreen(itemId: item.id),
              ),
            );
          },
        );
      },
    );
  }
}

