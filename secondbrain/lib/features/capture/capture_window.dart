import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../app/app_scope.dart';
import '../../data/database.dart';
import '../../data/repositories/settings_repository.dart';
import '../../platform/desktop/desktop_capture.dart';
import '../common/widgets/common_widgets.dart';
import '../common/widgets/content_width.dart';
import '../common/widgets/db_stream_builder.dart';
import '../common/widgets/project_dropdown.dart';

/// Quick capture window (UI_SPEC §5, UI-13).
///
/// The content is always shown for review before saving — the window never
/// saves on its own. With no active project the item goes to the inbox, and
/// the clipboard is never modified.
class CaptureWindow extends StatefulWidget {
  const CaptureWindow({
    super.key,
    this.platform = const UnsupportedDesktopCapturePlatform(),
    this.sharedText,
    this.sharedUrl,
    this.sourceTitle,
    this.sourceApp,
    this.sourceLabel,
  });

  final DesktopCapturePlatform platform;
  final String? sharedText;
  final String? sharedUrl;

  /// The title of the window the content came from (desktop hot key).
  final String? sourceTitle;

  /// The application the content came from (desktop hot key).
  final String? sourceApp;

  /// Where the content came from: «نص محدد» / «الحافظة» / «مشاركة».
  final String? sourceLabel;

  @override
  State<CaptureWindow> createState() => _CaptureWindowState();
}

enum CaptureState { idle, saving, saved, failed }

class _CaptureWindowState extends State<CaptureWindow> {
  final _title = TextEditingController();
  final _content = TextEditingController();
  final _comment = TextEditingController();
  final _sourceUrl = TextEditingController();
  final _sourceTitle = TextEditingController();
  final _sourceApp = TextEditingController();

  String? _typeId;
  String? _projectId;
  String _sourceLabel = '';
  CaptureState _state = CaptureState.idle;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _bootstrap());
  }

  @override
  void dispose() {
    _title.dispose();
    _content.dispose();
    _comment.dispose();
    _sourceUrl.dispose();
    _sourceTitle.dispose();
    _sourceApp.dispose();
    super.dispose();
  }

  Future<void> _bootstrap() async {
    final scope = AppScope.of(context);
    final types = await scope.itemTypes.builtin();
    final activeProject = await scope.settings.get(
      SettingsRepository.keyActiveCaptureProject,
    );
    if (!mounted) return;

    // 1. The selection, 2. the clipboard, 3. the shared text (Android).
    String? content;
    String sourceLabel = '';
    if (widget.sharedText != null && widget.sharedText!.trim().isNotEmpty) {
      content = widget.sharedText;
      sourceLabel = widget.sourceLabel ?? 'مشاركة';
    } else if (widget.platform.isSupported) {
      final selection = await widget.platform.readSelection();
      if (selection != null && selection.text.trim().isNotEmpty) {
        content = selection.text;
        sourceLabel = 'نص محدد';
      } else {
        final clipboard = await widget.platform.readClipboard();
        if (clipboard != null && clipboard.text.trim().isNotEmpty) {
          content = clipboard.text;
          sourceLabel = 'الحافظة';
        }
      }
      final windowTitle = await widget.platform.activeWindowTitle();
      final app = await widget.platform.activeApplication();
      if (windowTitle != null && windowTitle.isNotEmpty) {
        _sourceTitle.text = windowTitle;
      }
      if (app != null && app.isNotEmpty) {
        _sourceApp.text = app;
      }
    }

    if (widget.sharedUrl != null && widget.sharedUrl!.isNotEmpty) {
      _sourceUrl.text = widget.sharedUrl!;
    }
    if ((widget.sourceTitle ?? '').isNotEmpty) {
      _sourceTitle.text = widget.sourceTitle!;
    }
    if ((widget.sourceApp ?? '').isNotEmpty) {
      _sourceApp.text = widget.sourceApp!;
    }

    // The type defaults to «رابط» when the content is only a link.
    final isLink =
        content != null &&
        content.trim().startsWith('http') &&
        !content.trim().contains(' ');
    final wantedType = isLink ? 'رابط' : 'ملاحظة';
    final type =
        types.where((t) => t.name == wantedType).firstOrNull ??
        (types.isEmpty ? null : types.first);

    if (!mounted) return;
    setState(() {
      _content.text = content ?? '';
      _sourceLabel = sourceLabel;
      _typeId = type?.id;
      _projectId = (activeProject == null || activeProject.isEmpty)
          ? null
          : activeProject;
      _loading = false;
    });
  }

  Future<void> _save() async {
    final l = AppLocalizations.of(context)!;
    if (_state == CaptureState.saving) return;
    final content = _content.text.trim();
    if (content.isEmpty) {
      showToast(context, l.captureContentRequired);
      return;
    }
    setState(() => _state = CaptureState.saving);
    final scope = AppScope.of(context);
    try {
      await scope.items.create(
        typeId: _typeId ?? '',
        title: _title.text.trim(),
        bodyMd: content,
        commentMd: _comment.text.trim().isEmpty ? null : _comment.text.trim(),
        projectId: _projectId,
        isInbox: _projectId == null,
        sourceUrl: _sourceUrl.text.trim().isEmpty
            ? null
            : _sourceUrl.text.trim(),
        sourceTitle: _sourceTitle.text.trim().isEmpty
            ? null
            : _sourceTitle.text.trim(),
        sourceApp: _sourceApp.text.trim().isEmpty
            ? null
            : _sourceApp.text.trim(),
        sourceKind: 'capture',
        capturedAt: DateTime.now().millisecondsSinceEpoch,
      );
      if (!mounted) return;
      setState(() => _state = CaptureState.saved);
      showToast(context, l.captureSaved);
      Navigator.of(context).pop();
    } on Object catch (e) {
      debugPrint('capture save failed: $e');
      if (!mounted) return;
      setState(() => _state = CaptureState.failed);
      showErrorWithRetry(context, message: l.captureFailed, onRetry: _save);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);

    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: Text(l.captureTitle)),
        body: const LoadingView(),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(l.captureTitle)),
      body: ContentWidth(
        maxWidth: ContentWidths.capture,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (!widget.platform.isSupported)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(l.captureUnavailable),
                  subtitle: Text(
                    widget.platform.unavailableReason ??
                        l.captureUnavailableHint,
                  ),
                ),
              ),
            if (_sourceLabel.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Chip(
                  avatar: const Icon(Icons.my_location, size: 16),
                  label: Text(_sourceLabel),
                ),
              ),
            DbStreamBuilder<List<ItemType>>(
              streamFactory: () => scope.itemTypes.watchBuiltin(),
              builder: (context, snap) {
                final types = snap.data ?? const <ItemType>[];
                final items = types
                    .map(
                      (t) => DropdownMenuItem<String>(
                        value: t.id,
                        child: Text(t.name),
                      ),
                    )
                    .toList();
                final selected = _typeId;
                if (selected != null && !types.any((t) => t.id == selected)) {
                  items.add(
                    DropdownMenuItem<String>(value: selected, child: Text('…')),
                  );
                }
                return DropdownButtonFormField<String>(
                  initialValue: selected,
                  isExpanded: true,
                  decoration: InputDecoration(
                    labelText: l.typeLabel,
                    prefixIcon: const Icon(Icons.category_outlined),
                    border: const OutlineInputBorder(),
                  ),
                  items: items,
                  onChanged: (v) => setState(() => _typeId = v),
                );
              },
            ),
            const SizedBox(height: 12),
            ProjectDropdown(
              label: l.captureProject,
              noneLabel: l.inboxDestination,
              value: _projectId,
              onChanged: (v) => setState(() => _projectId = v),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _title,
              decoration: InputDecoration(
                labelText: l.titleLabelOptional,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _content,
              minLines: 4,
              maxLines: 10,
              decoration: InputDecoration(
                labelText: l.contentLabel,
                alignLabelWithHint: true,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _comment,
              maxLines: 2,
              decoration: InputDecoration(
                labelText: l.commentLabel,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            ExpansionTile(
              title: Text(l.sourceDetails),
              children: [
                TextField(
                  controller: _sourceTitle,
                  decoration: InputDecoration(
                    labelText: l.sourceTitleLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sourceUrl,
                  textDirection: TextDirection.ltr,
                  decoration: InputDecoration(
                    labelText: l.sourceUrlLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sourceApp,
                  decoration: InputDecoration(
                    labelText: l.sourceAppLabel,
                    border: const OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: TextButton.icon(
                    onPressed: () {
                      _sourceUrl.clear();
                      _sourceTitle.clear();
                      _sourceApp.clear();
                    },
                    icon: const Icon(Icons.delete_outline),
                    label: Text(l.clearSource),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    key: const Key('capture-save'),
                    onPressed: _state == CaptureState.saving ? null : _save,
                    icon: _state == CaptureState.saving
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.save_outlined),
                    label: Text(l.save),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(l.cancel),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
