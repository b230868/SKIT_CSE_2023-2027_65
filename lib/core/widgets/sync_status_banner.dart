import 'package:flutter/material.dart';

import 'package:prashikshan/services/sync_coordinator.dart';

/// Thin banner that appears only when something needs attention:
/// syncing, offline, or offline changes waiting to be sent. Tap to retry.
class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: SyncCoordinator.instance.state,
      builder: (context, s, _) {
        if (s.phase == SyncPhase.idle && s.pending == 0) {
          return const SizedBox.shrink();
        }

        final scheme = Theme.of(context).colorScheme;
        final String text;
        final IconData icon;

        if (s.phase == SyncPhase.syncing) {
          text = 'Syncing...';
          icon = Icons.sync;
        } else if (s.phase == SyncPhase.offline) {
          text = s.pending > 0
              ? 'Offline: ${s.pending} change(s) will sync when you are back online'
              : 'Offline: showing saved data';
          icon = Icons.cloud_off;
        } else {
          text = '${s.pending} change(s) waiting to sync';
          icon = Icons.schedule;
        }

        return Material(
          color: s.phase == SyncPhase.offline
              ? scheme.errorContainer
              : scheme.secondaryContainer,
          child: InkWell(
            onTap: s.phase == SyncPhase.syncing
                ? null
                : () => SyncCoordinator.instance.syncNow(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(text, style: Theme.of(context).textTheme.bodySmall),
                  ),
                  if (s.phase != SyncPhase.syncing)
                    Text('Retry', style: Theme.of(context).textTheme.labelMedium),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
