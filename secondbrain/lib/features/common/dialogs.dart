import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

/// One entry of a picker sheet (projects, types, …).
class SheetOption<T> {
  const SheetOption(this.value, this.label, {this.icon});

  final T value;
  final String label;
  final IconData? icon;
}

/// Bottom sheet that lets the user pick one entry.
///
/// Returns null when the sheet is dismissed without a choice.
Future<T?> showOptionSheet<T>(
  BuildContext context, {
  required List<SheetOption<T>> options,
}) {
  return showModalBottomSheet<T>(
    context: context,
    showDragHandle: true,
    builder: (sheetContext) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          for (final o in options)
            ListTile(
              leading: o.icon == null ? null : Icon(o.icon),
              title: Text(o.label),
              onTap: () => Navigator.of(sheetContext).pop(o.value),
            ),
        ],
      ),
    ),
  );
}

/// Asks the user for a list of tag names (separated by `,` or `،`).
///
/// Returns null when the dialog is cancelled.
Future<List<String>?> askForTags(BuildContext context) async {
  final l = AppLocalizations.of(context)!;
  final controller = TextEditingController();
  final result = await showDialog<List<String>>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l.addTag),
      content: TextField(
        controller: controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l.tagsLabel,
          hintText: l.tagsHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(dialogContext).pop(
            splitTagNames(controller.text),
          ),
          child: Text(l.save),
        ),
      ],
    ),
  );
  controller.dispose();
  return result;
}

/// Splits a tag input into trimmed, non-empty names.
List<String> splitTagNames(String text) => text
    .split(RegExp(r'[,،]'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();
