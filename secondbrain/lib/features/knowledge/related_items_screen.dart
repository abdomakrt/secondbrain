import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../data/database.dart';
import '../common/widgets/common_widgets.dart';

/// All items linked to the given item (both directions), with linking and
/// unlinking through a simple item picker.
class RelatedItemsScreen extends StatefulWidget {
  const RelatedItemsScreen({super.key, required this.itemId});

  final String itemId;

  @override
  State<RelatedItemsScreen> createState() => _RelatedItemsScreenState();
}

class _RelatedItemsScreenState extends State<RelatedItemsScreen> {
  List<Item>? _related;
  List<Item>? _pickerList;
  String _pickerQuery = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reload();
  }

  Future<void> _reload() async {
    final scope = AppScope.of(context);
    final related = await scope.links.related(widget.itemId);
    if (mounted) setState(() => _related = related);
  }

  Future<void> _pick() async {
    final scope = AppScope.of(context);
    final picked = await showDialog<Item>(
      context: context,
      builder: (_) => StatefulBuilder(
        builder: (context, setDialogState) {
          Future<List<Item>> candidates() async {
            final q = _pickerQuery.trim();
            final query = scope.db.select(scope.db.items)
              ..where((i) => i.deletedAt.isNull() & i.id.isNotIn([widget.itemId]));
            if (q.isNotEmpty) {
              query.where((i) => i.title.like('%$q%'));
            }
            final list = await (query..limit(20)).get();
            return list;
          }

          return AlertDialog(
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    autofocus: true,
                    onChanged: (v) =>
                        setDialogState(() => _pickerQuery = v),
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 8),
                  FutureBuilder<List<Item>>(
                    future: candidates(),
                    builder: (context, snap) {
                      final list = snap.data ?? _pickerList ?? const <Item>[];
                      _pickerList = list;
                      return Flexible(
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: list.length,
                          itemBuilder: (context, i) => ListTile(
                            title: Text(list[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            onTap: () =>
                                Navigator.of(context).pop(list[i]),
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    if (picked == null) return;
    await scope.links.link(
      fromType: 'item',
      fromId: widget.itemId,
      toType: 'item',
      toId: picked.id,
    );
    if (mounted) await _reload();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return Scaffold(
      appBar: AppBar(
        title: Text(l.relatedItems),
        actions: [
          IconButton(
            tooltip: l.linkExisting,
            icon: const Icon(Icons.add_link),
            onPressed: _pick,
          ),
        ],
      ),
      body: _related == null
          ? const SizedBox.shrink()
          : _related!.isEmpty
              ? EmptyState(
                  icon: Icons.link_off,
                  title: l.noRelated,
                )
              : ListView(
                  children: _related!
                      .map((item) => ListTile(
                            leading: const Icon(Icons.link),
                            title: Text(item.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                            trailing: IconButton(
                              tooltip: l.unlink,
                              icon: const Icon(Icons.link_off),
                              onPressed: () async {
                                final scope = AppScope.of(context);
                                await scope.links.unlink(
                                  fromType: 'item',
                                  fromId: widget.itemId,
                                  toType: 'item',
                                  toId: item.id,
                                );
                                await scope.links.unlink(
                                  fromType: 'item',
                                  fromId: item.id,
                                  toType: 'item',
                                  toId: widget.itemId,
                                );
                                await _reload();
                              },
                            ),
                          ))
                      .toList(),
                ),
    );
  }
}
