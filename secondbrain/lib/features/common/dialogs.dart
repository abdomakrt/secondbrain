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

/// Asks the user for a one-line text.
///
/// The dialog owns its controller, so it is disposed together with the
/// dialog — never used after being disposed (a classic Flutter trap when the
/// controller is disposed right after `showDialog` returns, while the exit
/// animation is still running).
Future<String?> showTextPrompt(
  BuildContext context, {
  required String title,
  String? label,
  String? hint,
  String initialValue = '',
  String? confirmLabel,
}) {
  return showDialog<String>(
    context: context,
    builder: (_) => TextPromptDialog(
      title: title,
      label: label,
      hint: hint,
      initialValue: initialValue,
      confirmLabel: confirmLabel,
    ),
  );
}

/// The dialog behind [showTextPrompt].
class TextPromptDialog extends StatefulWidget {
  const TextPromptDialog({
    super.key,
    required this.title,
    this.label,
    this.hint,
    this.initialValue = '',
    this.confirmLabel,
  });

  final String title;
  final String? label;
  final String? hint;
  final String initialValue;
  final String? confirmLabel;

  @override
  State<TextPromptDialog> createState() => _TextPromptDialogState();
}

class _TextPromptDialogState extends State<TextPromptDialog> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.initialValue);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        decoration: InputDecoration(
          labelText: widget.label,
          hintText: widget.hint,
        ),
        onSubmitted: (v) => Navigator.of(context).pop(v.trim()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_controller.text.trim()),
          child: Text(widget.confirmLabel ?? l.save),
        ),
      ],
    );
  }
}

/// Asks the user for a list of tag names (separated by `,` or `،`).
///
/// Returns null when the dialog is cancelled.
Future<List<String>?> askForTags(BuildContext context) {
  return showDialog<List<String>>(
    context: context,
    builder: (_) => const _TagsDialog(),
  );
}

/// The dialog behind [askForTags] — it owns its controller.
class _TagsDialog extends StatefulWidget {
  const _TagsDialog();

  @override
  State<_TagsDialog> createState() => _TagsDialogState();
}

class _TagsDialogState extends State<_TagsDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l.addTag),
      content: TextField(
        controller: _controller,
        autofocus: true,
        decoration: InputDecoration(
          labelText: l.tagsLabel,
          hintText: l.tagsHint,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(
            splitTagNames(_controller.text),
          ),
          child: Text(l.save),
        ),
      ],
    );
  }
}

/// Splits a tag input into trimmed, non-empty names.
List<String> splitTagNames(String text) => text
    .split(RegExp(r'[,،]'))
    .map((s) => s.trim())
    .where((s) => s.isNotEmpty)
    .toList();
