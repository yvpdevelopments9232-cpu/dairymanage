import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/sync_service.dart';

class SyncStatusBadge extends StatelessWidget {
  const SyncStatusBadge({super.key});

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<SyncState>(
      valueListenable: SyncService.instance.state,
      builder: (context, state, _) {
        Color bgColor;
        Color textColor;
        IconData iconData;
        String label;

        if (state.status == SyncStatus.syncing) {
          bgColor = Colors.blue.shade100;
          textColor = Colors.blue.shade900;
          iconData = Icons.sync;
          label = 'Syncing...';
        } else if (!state.isOnline || state.status == SyncStatus.offline) {
          bgColor = Colors.amber.shade100;
          textColor = Colors.amber.shade900;
          iconData = Icons.cloud_off;
          label = state.pendingCount > 0 ? '${state.pendingCount} Pending' : 'Offline';
        } else if (state.pendingCount > 0) {
          bgColor = Colors.orange.shade100;
          textColor = Colors.orange.shade900;
          iconData = Icons.sync_problem;
          label = '${state.pendingCount} Pending';
        } else {
          bgColor = Colors.green.shade100;
          textColor = Colors.green.shade900;
          iconData = Icons.cloud_done;
          label = 'Synced';
        }

        final isMobile = MediaQuery.of(context).size.width < 600;

        if (isMobile) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => _showSyncDetailsDialog(context, state),
              child: Tooltip(
                message: 'Cloud Sync: $label',
                child: Container(
                  padding: const EdgeInsets.all(7),
                  decoration: BoxDecoration(
                    color: bgColor,
                    shape: BoxShape.circle,
                    border: Border.all(color: textColor.withOpacity(0.3)),
                  ),
                  child: state.status == SyncStatus.syncing
                      ? SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: textColor,
                          ),
                        )
                      : Icon(iconData, size: 16, color: textColor),
                ),
              ),
            ),
          );
        }

        return InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => _showSyncDetailsDialog(context, state),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: bgColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: textColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                state.status == SyncStatus.syncing
                    ? SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: textColor,
                        ),
                      )
                    : Icon(iconData, size: 16, color: textColor),
                const SizedBox(width: 6),
                Text(
                  label,
                  style: TextStyle(
                    color: textColor,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSyncDetailsDialog(BuildContext context, SyncState state) {
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: Row(
            children: [
              Icon(
                state.isOnline ? Icons.cloud_done : Icons.cloud_off,
                color: state.isOnline ? Colors.green : Colors.amber.shade800,
              ),
              const SizedBox(width: 10),
              const Text('Cloud Sync Status'),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _infoRow('Connection', state.isOnline ? '🟢 Online' : '🟡 Offline (Working locally)'),
              const SizedBox(height: 8),
              _infoRow('Pending Uploads', '${state.pendingCount} records'),
              const SizedBox(height: 8),
              _infoRow(
                'Last Synced',
                state.lastSyncTime != null
                    ? DateFormat('dd MMM yyyy, hh:mm:ss a').format(state.lastSyncTime!)
                    : 'Not synced yet',
              ),
              if (state.message != null && state.message!.isNotEmpty) ...[
                const SizedBox(height: 8),
                _infoRow('Details', state.message!),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            ElevatedButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                SyncService.instance.syncAll();
              },
              icon: const Icon(Icons.sync, size: 18),
              label: const Text('Sync Now'),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.blue.shade800,
                foregroundColor: Colors.white,
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _infoRow(String title, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
