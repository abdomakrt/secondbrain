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
  /// The controller owned by this widget (used when the shell passes none).
  TextEditingController? _internal;

  late TextEditingController _controller;

  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? (_internal = TextEditingController());
  }

  @override
  void didUpdateWidget(covariant GlobalSearch old) {
    super.didUpdateWidget(old);
    // The shell may swap the controller (or drop it) — follow it instead of
    // keeping a stale one.
    if (identical(widget.controller, _controller)) return;
    _controller = widget.controller ?? (_internal ??= TextEditingController());
  }

  @override
  void dispose() {
    _internal?.dispose();
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
