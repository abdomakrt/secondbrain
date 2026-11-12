import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

/// Unified search entry (UI_SPEC §7: `GlobalSearch`).
///
/// A prominent search box in the desktop top bar; on Android the same search
/// is reachable from the app bar and from every list screen.
class GlobalSearch extends StatefulWidget {
  const GlobalSearch({
    super.key,
    this.onSubmitted,
    this.hint,
    this.controller,
  });

  final void Function([String?])? onSubmitted;
  final String? hint;

  /// An external controller (owned by the shell) so the quick-add button can
  /// read what the user typed.
  final TextEditingController? controller;

  @override
  State<GlobalSearch> createState() => _GlobalSearchState();
}

class _GlobalSearchState extends State<GlobalSearch> {
  late final TextEditingController _controller =
      widget.controller ?? TextEditingController();
  final _focus = FocusNode();
  bool _ownsController = false;

  @override
  void initState() {
    super.initState();
    _ownsController = widget.controller == null;
  }

  @override
  void dispose() {
    if (_ownsController) _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final query = _controller.text.trim();
    widget.onSubmitted?.call(query.isEmpty ? null : query);
    _focus.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 620),
      child: TextField(
        controller: _controller,
        focusNode: _focus,
        textInputAction: TextInputAction.search,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: widget.hint ?? l.searchHint,
          prefixIcon: const Icon(Icons.search),
          border: const OutlineInputBorder(),
          isDense: true,
          contentPadding:
              const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        ),
      ),
    );
  }
}
