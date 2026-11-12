import 'package:flutter/material.dart';
import '../../../sync/connection.dart';

/// Connection status (UI_SPEC §7: `ConnectionStatus`).
///
/// The state is always written as text next to the icon — never colour only.
class ConnectionStatusBadge extends StatelessWidget {
  const ConnectionStatusBadge({
    super.key,
    required this.state,
    this.onTap,
    this.compact = false,
  });

  final SyncConnectionState state;
  final VoidCallback? onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (IconData icon, Color color) = switch (state) {
      SyncConnectionState.connected => (
          Icons.cloud_done_outlined,
          theme.colorScheme.primary
        ),
      SyncConnectionState.connecting => (
          Icons.cloud_sync_outlined,
          theme.colorScheme.tertiary
        ),
      SyncConnectionState.failed => (
          Icons.cloud_off_outlined,
          theme.colorScheme.error
        ),
      SyncConnectionState.serverUnavailable => (
          Icons.cloud_queue_outlined,
          theme.colorScheme.outline
        ),
      SyncConnectionState.notConfigured => (
          Icons.cloud_off_outlined,
          theme.colorScheme.outline
        ),
    };

    final label = state.label;

    final child = compact
        ? Tooltip(
            message: label,
            child: Icon(icon, size: 20, color: color),
          )
        : Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: color),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 16, color: color),
                const SizedBox(width: 6),
                Text(label, style: theme.textTheme.labelMedium),
              ],
            ),
          );

    if (onTap == null) return child;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: child,
    );
  }
}
