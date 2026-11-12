import 'package:flutter/material.dart';
import 'package:secondbrain/l10n/app_localizations.dart';

import '../../../domain/progress.dart';

/// Progress indicator (UI_SPEC §7: `ProgressBar`).
///
/// Never shows a percentage that was not computed from real data: when the
/// project has no tasks the widget explains that instead of rendering 0%.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.progress,
    this.showLabel = true,
    this.height = 8,
  });

  final Progress progress;
  final bool showLabel;
  final double height;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final percent = progress.percent;
    final noData = !progress.manualMode && !progress.hasTasks;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: noData ? 0 : percent / 100,
            minHeight: height,
            backgroundColor: theme.colorScheme.surfaceContainerHighest,
          ),
        ),
        if (showLabel) ...[
          const SizedBox(height: 4),
          Text(
            noData
                ? l.noTasksYet
                : progress.manualMode
                    ? '$percent%'
                    : '${l.percentOfProgress(percent)} • ${progress.countLabel}',
            style: theme.textTheme.labelSmall,
          ),
        ],
      ],
    );
  }
}
