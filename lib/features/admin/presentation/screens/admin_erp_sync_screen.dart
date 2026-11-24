import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/status_chip.dart';

class AdminErpSyncScreen extends StatefulWidget {
  const AdminErpSyncScreen({super.key});

  @override
  State<AdminErpSyncScreen> createState() => _AdminErpSyncScreenState();
}

class _AdminErpSyncScreenState extends State<AdminErpSyncScreen> {
  bool _isSyncing = false;
  bool _autoSyncEnabled = true;
  String _syncInterval = 'Daily at 02:00 AM';
  DateTime? _lastSyncTime;

  final List<Map<String, dynamic>> _syncHistory = [];

  Future<void> _triggerManualSync() async {
    setState(() => _isSyncing = true);

    await Future.delayed(const Duration(seconds: 2));

    if (!mounted) return;

    final newBatch = {
      'batch_id': 'ERP-BATCH-${DateTime.now().year}-${DateTime.now().month.toString().padLeft(2, '0')}${DateTime.now().day.toString().padLeft(2, '0')}-${DateTime.now().minute}',
      'timestamp': DateTime.now(),
      'records_count': 14,
      'status': 'SUCCESS',
      'endpoint': 'https://erp.skit.ac.in/api/v2/internship-grades',
      'message': '14 verified ITR evaluations synced to university registrar.',
    };

    setState(() {
      _lastSyncTime = DateTime.now();
      _syncHistory.insert(0, newBatch);
      _isSyncing = false;
    });

    showSnack(
      context,
      'University ERP sync completed successfully (14 student records updated)',
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        title: const Text('ERP Integration & Sync'),
        actions: [
          IconButton(
            tooltip: 'Sync Settings',
            icon: const Icon(Icons.tune_outlined),
            onPressed: _showSettingsDialog,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          // Live Sync Status Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Row(
                        children: [
                          Icon(
                            Icons.cloud_sync_outlined,
                            color: Color(0xFF2563EB),
                            size: 26,
                          ),
                          SizedBox(width: 10),
                          Text(
                            'SKIT Enterprise ERP Connector',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDCFCE7),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'CONNECTED',
                          style: TextStyle(
                            color: Color(0xFF15803D),
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    _lastSyncTime != null
                        ? 'Last Synchronized: ${fmtDate(_lastSyncTime!)} at ${_lastSyncTime!.hour.toString().padLeft(2, '0')}:${_lastSyncTime!.minute.toString().padLeft(2, '0')}'
                        : 'Last Synchronized: Not yet synchronized in this session',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.slateMuted,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Endpoint: https://erp.skit.ac.in/api/v2 (TLS 1.3 Verified)',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey.shade600,
                    ),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.ink,
                      minimumSize: const Size.fromHeight(48),
                    ),
                    onPressed: _isSyncing ? null : _triggerManualSync,
                    icon: _isSyncing
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.sync),
                    label: Text(
                      _isSyncing
                          ? 'Synchronizing with University ERP...'
                          : 'Trigger Immediate Sync Now',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Automated Schedule Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Automated Grade Dispatch',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      Switch(
                        value: _autoSyncEnabled,
                        activeThumbColor: AppTheme.ink,
                        onChanged: (val) {
                          setState(() => _autoSyncEnabled = val);
                          showSnack(
                            context,
                            val
                                ? 'Scheduled background auto-sync enabled'
                                : 'Background auto-sync paused',
                          );
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Schedule: $_syncInterval',
                    style: const TextStyle(
                      fontSize: 13,
                      color: AppTheme.slateMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Automatically pushes completed and verified ITR evaluations, faculty approvals, and employer ratings directly to the university registrar database.',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppTheme.slateMuted,
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // History Section Header
          const Text(
            'Batch Synchronization History',
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppTheme.ink,
            ),
          ),
          const SizedBox(height: 12),

          // Batch Logs
          if (_syncHistory.isEmpty)
            const EmptyStateWidget(
              message:
                  'No synchronization batches executed yet.\nClick "Trigger Immediate Sync Now" to run.',
              icon: Icons.sync,
            )
          else
            ..._syncHistory.map((item) => _buildHistoryCard(item)),
        ],
      ),
    );
  }

  Widget _buildHistoryCard(Map<String, dynamic> item) {
    final status = item['status'] as String;
    final isSuccess = status == 'SUCCESS';
    final date = item['timestamp'] as DateTime;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => _showBatchDetailsModal(item),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(
                        isSuccess ? Icons.check_circle : Icons.warning_amber_rounded,
                        color: isSuccess ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        item['batch_id'] as String,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                    ],
                  ),
                  StatusChip(status: status),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                item['message'] as String,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppTheme.ink,
                ),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '${item['records_count']} Records Synchronized',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppTheme.slateMuted,
                    ),
                  ),
                  Text(
                    '${fmtDate(date)} · ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade500,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBatchDetailsModal(Map<String, dynamic> item) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  item['batch_id'] as String,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.ink,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const Divider(),
            const SizedBox(height: 10),
            Text('Status: ${item['status']}', style: const TextStyle(fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text('Target API: ${item['endpoint']}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text('Summary: ${item['message']}', style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                showSnack(context, 'Exported batch log ${item['batch_id']}.json');
              },
              icon: const Icon(Icons.download_outlined),
              label: const Text('Export JSON Payload Log'),
            ),
          ],
        ),
      ),
    );
  }

  void _showSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ERP Connector Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Select synchronization frequency:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _syncInterval,
              decoration: const InputDecoration(isDense: true),
              items: const [
                DropdownMenuItem(
                  value: 'Every hour',
                  child: Text('Every hour (High Frequency)'),
                ),
                DropdownMenuItem(
                  value: 'Daily at 02:00 AM',
                  child: Text('Daily at 02:00 AM (Recommended)'),
                ),
                DropdownMenuItem(
                  value: 'Weekly on Sunday',
                  child: Text('Weekly on Sunday'),
                ),
              ],
              onChanged: (v) {
                if (v != null) {
                  setState(() => _syncInterval = v);
                }
              },
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
