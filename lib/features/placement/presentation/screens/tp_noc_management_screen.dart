import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../data/models/placement_models.dart';
import '../../data/services/placement_repository_provider.dart';

class TpNocManagementScreen extends StatefulWidget {
  final String initialStatusFilter;

  const TpNocManagementScreen({super.key, this.initialStatusFilter = 'pending'});

  @override
  State<TpNocManagementScreen> createState() => _TpNocManagementScreenState();
}

class _TpNocManagementScreenState extends State<TpNocManagementScreen> {
  final _repo = PlacementRepositoryProvider.instance;
  final _searchCtrl = TextEditingController();

  List<NocRequest> _requests = [];
  bool _loading = true;
  String? _error;
  late String _statusFilter;

  @override
  void initState() {
    super.initState();
    _statusFilter = widget.initialStatusFilter;
    _searchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await _repo.getNocRequests(tpView: true);
      if (!mounted) return;
      setState(() {
        _requests = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load NOC requests: $e';
        _loading = false;
      });
    }
  }

  List<NocRequest> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    return _requests.where((r) {
      if (_statusFilter != 'all' && r.status != _statusFilter) return false;
      if (q.isNotEmpty) {
        final match = r.companyName.toLowerCase().contains(q) ||
            (r.studentName?.toLowerCase().contains(q) ?? false) ||
            (r.rollNumber?.toLowerCase().contains(q) ?? false) ||
            (r.studentBranch?.toLowerCase().contains(q) ?? false) ||
            (r.opportunityTitle?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _openDocument(NocRequest r) async {
    if (r.documentPath == null || r.documentPath!.isEmpty) return;
    try {
      final url = await _repo.getAttachmentUrl(
        r.documentPath!,
        bucket: r.storageBucket,
      );
      if (url == null || url.isEmpty) {
        if (mounted) showSnack(context, 'Document link unavailable.', error: true);
        return;
      }
      final uri = Uri.tryParse(url);
      if (uri != null) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Could not open document: $e', error: true);
    }
  }

  Future<void> _showReviewDialog(NocRequest request, {required bool approve}) async {
    final remarksCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    bool busy = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(approve ? 'Approve NOC Request' : 'Reject NOC Request'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${request.studentName ?? 'Student'} · ${request.companyName}',
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              if (!approve) ...[
                TextField(
                  controller: reasonCtrl,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: 'Rejection Reason *',
                    hintText: 'Specify why the NOC was rejected',
                  ),
                ),
                const SizedBox(height: 12),
              ],
              TextField(
                controller: remarksCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'T&P Remarks (optional)',
                  hintText: 'Add instructions or remarks for the student',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: busy ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(
                minimumSize: const Size(110, 44),
                backgroundColor: approve ? const Color(0xFF15803D) : Colors.red,
              ),
              onPressed: busy
                  ? null
                  : () async {
                      if (!approve && reasonCtrl.text.trim().isEmpty) {
                        showSnack(
                          context,
                          'Please provide a rejection reason.',
                          error: true,
                        );
                        return;
                      }
                      setDialogState(() => busy = true);
                      try {
                        await _repo.reviewNocRequest(
                          request: request,
                          status: approve ? 'approved' : 'rejected',
                          tpRemarks: remarksCtrl.text.trim(),
                          rejectionReason: reasonCtrl.text.trim(),
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          showSnack(
                            this.context,
                            'NOC request ${approve ? 'approved' : 'rejected'}. Student notified.',
                          );
                        }
                        _load();
                      } catch (e) {
                        if (context.mounted) {
                          setDialogState(() => busy = false);
                          showSnack(context, 'Failed: $e', error: true);
                        }
                      }
                    },
              child: Text(busy
                  ? 'Saving...'
                  : (approve ? 'Approve NOC' : 'Reject NOC')),
            ),
          ],
        ),
      ),
    );

    remarksCtrl.dispose();
    reasonCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;
    int count(String st) => _requests.where((r) => r.status == st).length;

    return Scaffold(
      appBar: AppBar(
        title: const Text('NOC Management'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
            child: Column(
              children: [
                TextField(
                  controller: _searchCtrl,
                  decoration: InputDecoration(
                    hintText: 'Search by student, roll no, branch, or company...',
                    prefixIcon: const Icon(Icons.search),
                    isDense: true,
                    suffixIcon: _searchCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, size: 18),
                            onPressed: _searchCtrl.clear,
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: {
                      'pending': 'Pending (${count('pending')})',
                      'approved': 'Approved (${count('approved')})',
                      'rejected': 'Rejected (${count('rejected')})',
                      'all': 'All (${_requests.length})',
                    }.entries.map((e) {
                      final sel = _statusFilter == e.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(e.value),
                          selected: sel,
                          selectedColor: AppTheme.ink,
                          labelStyle: TextStyle(
                            color: sel ? Colors.white : AppTheme.ink,
                            fontSize: 12,
                            fontWeight: sel ? FontWeight.w700 : FontWeight.w500,
                          ),
                          onSelected: (_) => setState(() => _statusFilter = e.key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                    ? EmptyStateWidget(
                        icon: Icons.error_outline,
                        title: 'Could not load NOC requests',
                        message: _error!,
                        onRetry: _load,
                      )
                    : items.isEmpty
                        ? const EmptyStateWidget(
                            icon: Icons.assignment_turned_in_outlined,
                            title: 'No NOC requests',
                            message:
                                'Student NOC submissions for internships and placements will appear here.',
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.all(16),
                              itemCount: items.length,
                              itemBuilder: (context, idx) {
                                final r = items[idx];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    r.studentName ?? 'Student',
                                                    style: const TextStyle(
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.w700,
                                                    ),
                                                  ),
                                                  Text(
                                                    [
                                                      if (r.rollNumber != null &&
                                                          r.rollNumber!.isNotEmpty)
                                                        r.rollNumber!,
                                                      if (r.studentBranch != null &&
                                                          r.studentBranch!.isNotEmpty)
                                                        r.studentBranch!,
                                                    ].join(' · '),
                                                    style: const TextStyle(
                                                      fontSize: 12,
                                                      color: AppTheme.slateMuted,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            StatusChip(status: r.status),
                                          ],
                                        ),
                                        const SizedBox(height: 10),
                                        Text(
                                          r.companyName,
                                          style: const TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w700,
                                            color: AppTheme.ink,
                                          ),
                                        ),
                                        if (r.opportunityTitle != null &&
                                            r.opportunityTitle!.isNotEmpty)
                                          Text(
                                            r.opportunityTitle!,
                                            style: const TextStyle(
                                              fontSize: 13,
                                              color: AppTheme.slateMuted,
                                            ),
                                          ),
                                        if (r.studentRemarks != null &&
                                            r.studentRemarks!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Student Remarks: ${r.studentRemarks!}',
                                            style: const TextStyle(fontSize: 13),
                                          ),
                                        ],
                                        if (r.documentPath != null &&
                                            r.documentPath!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              minimumSize: const Size(0, 38),
                                            ),
                                            onPressed: () => _openDocument(r),
                                            icon: const Icon(Icons.attach_file, size: 16),
                                            label: Text(
                                              r.documentName ?? 'View Submitted Document',
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                        ],
                                        if (r.rejectionReason != null &&
                                            r.rejectionReason!.isNotEmpty) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            'Rejection Reason: ${r.rejectionReason!}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: Colors.red,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                        if (r.tpRemarks != null &&
                                            r.tpRemarks!.isNotEmpty) ...[
                                          const SizedBox(height: 4),
                                          Text(
                                            'T&P Remarks: ${r.tpRemarks!}',
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.slateMuted,
                                            ),
                                          ),
                                        ],
                                        const SizedBox(height: 8),
                                        Text(
                                          'Submitted ${fmtDate(r.createdAt)}',
                                          style: const TextStyle(
                                            fontSize: 11,
                                            color: AppTheme.slateMuted,
                                          ),
                                        ),
                                        if (r.status == 'pending') ...[
                                          const SizedBox(height: 12),
                                          const Divider(height: 1),
                                          const SizedBox(height: 10),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.end,
                                            children: [
                                              OutlinedButton.icon(
                                                style: OutlinedButton.styleFrom(
                                                  minimumSize: const Size(96, 38),
                                                  foregroundColor: Colors.red,
                                                ),
                                                onPressed: () => _showReviewDialog(
                                                  r,
                                                  approve: false,
                                                ),
                                                icon: const Icon(Icons.close, size: 16),
                                                label: const Text('Reject'),
                                              ),
                                              const SizedBox(width: 10),
                                              FilledButton.icon(
                                                style: FilledButton.styleFrom(
                                                  minimumSize: const Size(110, 38),
                                                  backgroundColor:
                                                      const Color(0xFF15803D),
                                                ),
                                                onPressed: () => _showReviewDialog(
                                                  r,
                                                  approve: true,
                                                ),
                                                icon: const Icon(Icons.check, size: 16),
                                                label: const Text('Approve'),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
          ),
        ],
      ),
    );
  }
}
