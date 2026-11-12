import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../../app/app_scope.dart';
import 'common_widgets.dart';

/// The source link of a project or a course.
///
/// The link is always written from left to right (it is not Arabic text) and
/// can be opened with the system browser.
class SourceLinkTile extends StatelessWidget {
  const SourceLinkTile({super.key, required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final value = (url ?? '').trim();

    if (value.isEmpty) {
      return Row(
        children: [
          Icon(Icons.link, size: 16, color: theme.colorScheme.outline),
          const SizedBox(width: 6),
          Text(l.noSourceUrl, style: theme.textTheme.bodySmall),
        ],
      );
    }

    return InkWell(
      onTap: () => _open(context),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            Icon(Icons.link, size: 16, color: theme.colorScheme.primary),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textDirection: TextDirection.ltr,
                style: theme.textTheme.bodySmall
                    ?.copyWith(color: theme.colorScheme.primary),
              ),
            ),
            Icon(Icons.open_in_new, size: 14, color: theme.colorScheme.outline),
          ],
        ),
      ),
    );
  }

  Future<void> _open(BuildContext context) async {
    final l = AppLocalizations.of(context)!;
    final scope = AppScope.of(context);
    final ok = await scope.opener.openUrl((url ?? '').trim());
    if (!context.mounted || ok) return;
    showToast(context, l.linkOpenFailed);
  }
}
