import 'dart:io';

import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../../app/app_scope.dart';
import '../../../data/database.dart';
import 'type_icons.dart';

/// One row of the knowledge list: type icon (or first-image thumbnail),
/// title, body preview, stamp.
class ItemTile extends StatelessWidget {
  const ItemTile({super.key, required this.item, this.onTap});

  final Item item;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ListTile(
      onTap: onTap,
      leading: _Leading(itemId: item.id, typeId: item.typeId),
      title: Text(
        item.title.isEmpty ? l.bodyLabel : item.title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        item.bodyMd.trim().isEmpty ? '' : item.bodyMd.trim(),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        formatStamp(item.updatedAt),
        style: Theme.of(context).textTheme.labelSmall,
      ),
    );
  }
}

/// Resolves the item type icon and, lazily, a small image thumbnail.
class _Leading extends StatefulWidget {
  const _Leading({required this.itemId, required this.typeId});

  final String itemId;
  final String typeId;

  @override
  State<_Leading> createState() => _LeadingState();
}

class _LeadingState extends State<_Leading> {
  File? _thumb;
  String _typeName = '';

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(covariant _Leading old) {
    super.didUpdateWidget(old);
    if (old.itemId != widget.itemId || old.typeId != widget.typeId) _load();
  }

  Future<void> _load() async {
    final scope = AppScope.of(context);
    final type = await (scope.db.select(scope.db.itemTypes)
          ..where((t) => t.id.equals(widget.typeId)))
        .getSingleOrNull();
    final rows = await scope.attachments.listFor('item', widget.itemId);
    Attachment? image;
    for (final a in rows) {
      if (a.kind == 'image') {
        image = a;
        break;
      }
    }
    if (mounted) {
      setState(() {
        _typeName = type?.name ?? '';
        _thumb = image == null ? null : scope.attachments.fileFor(image);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_thumb != null && _thumb!.existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.file(
          _thumb!,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
          cacheWidth: 96, // low-memory thumbnail
          errorBuilder: (_, _, _) => _icon(context),
        ),
      );
    }
    return _icon(context);
  }

  Widget _icon(BuildContext context) => SizedBox(
        width: 44,
        height: 44,
        child: Icon(
          iconForType(_typeName),
          color: Theme.of(context).colorScheme.primary,
        ),
      );
}
