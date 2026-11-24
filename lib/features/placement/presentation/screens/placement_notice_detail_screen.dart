import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../data/models/placement_models.dart';
import '../../data/services/placement_repository_provider.dart';
import '../widgets/placement_ui_widgets.dart';
import 'tp_notice_editor_screen.dart';

class PlacementNoticeDetailScreen extends StatefulWidget {
  final String noticeId;
  final PlacementNotice? initialNotice;
  final bool isTpView;
  final void Function(PlacementNotice notice)? onAskQuery;
  final void Function(PlacementNotice notice)? onRequestNoc;

  const PlacementNoticeDetailScreen({
    super.key,
    required this.noticeId,
    this.initialNotice,
    this.isTpView = false,
    this.onAskQuery,
    this.onRequestNoc,
  });

  @override
  State<PlacementNoticeDetailScreen> createState() =>
      _PlacementNoticeDetailScreenState();
}

class _PlacementNoticeDetailScreenState
    extends State<PlacementNoticeDetailScreen> {
  final _repo = PlacementRepositoryProvider.instance;
  PlacementNotice? _notice;
  bool _loading = true;
  String? _error;
  bool _changed = false;

  @override
  void initState() {
    super.initState();
    _notice = widget.initialNotice;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = _notice == null;
      _error = null;
    });
    try {
      final fetched = await _repo.getNoticeById(widget.noticeId);
      if (!mounted) return;
      if (fetched == null) {
        setState(() {
          _loading = false;
          _error = 'Placement notice not found or no longer visible.';
        });
        return;
      }
      if (!widget.isTpView && !fetched.isRead) {
        await _repo.markNoticeRead(fetched.id);
      }
      if (!mounted) return;
      setState(() {
        _notice = widget.isTpView ? fetched : fetched.copyWith(isRead: true);
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = 'Unable to load notice: $e';
      });
    }
  }

  Future<void> _launchApplicationLink(String rawUrl) async {
    var trimmed = rawUrl.trim();
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null) {
      showSnack(context, 'Invalid application link.', error: true);
      return;
    }
    try {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Could not open external link.', error: true);
      }
    }
  }

  Future<void> _toggleCloseStatus() async {
    final notice = _notice;
    if (notice == null) return;
    final nextStatus =
        notice.status == NoticeStatus.closed ? NoticeStatus.open : NoticeStatus.closed;
    try {
      await _repo.updateNoticeStatus(notice.id, nextStatus);
      _changed = true;
      await _load();
      if (mounted) {
        showSnack(context, 'Notice marked as ${nextStatus.label}.');
      }
    } catch (e) {
      if (mounted) showSnack(context, 'Failed to update status: $e', error: true);
    }
  }

  Future<void> _editNotice() async {
    final notice = _notice;
    if (notice == null) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TpNoticeEditorScreen(existing: notice)),
    );
    if (updated == true) {
      _changed = true;
      await _load();
    }
  }

  Future<void> _deleteNotice() async {
    final notice = _notice;
    if (notice == null) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Placement Notice?'),
        content: Text(
          'This will permanently remove "${notice.companyName} · ${notice.title}" and its attachments.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _repo.deleteNotice(notice.id);
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) showSnack(context, 'Delete failed: $e', error: true);
    }
  }

  Widget _sectionCard(String title, String content, IconData icon) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: AppTheme.ink),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.ink,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SelectableText(
              content,
              style: const TextStyle(fontSize: 14, height: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final notice = _notice;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_changed);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(notice?.companyName ?? 'Placement Notice'),
          actions: [
            if (widget.isTpView && notice != null) ...[
              IconButton(
                tooltip: 'Edit Notice',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _editNotice,
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'toggle') _toggleCloseStatus();
                  if (v == 'delete') _deleteNotice();
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                    value: 'toggle',
                    child: Text(
                      notice.status == NoticeStatus.closed
                          ? 'Reopen Notice'
                          : 'Close Notice',
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Text('Delete Notice', style: TextStyle(color: Colors.red)),
                  ),
                ],
              ),
            ],
          ],
        ),
        body: _loading
            ? const Center(child: CircularProgressIndicator())
            : _error != null || notice == null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error ?? 'Notice unavailable', textAlign: TextAlign.center),
                          const SizedBox(height: 12),
                          FilledButton(onPressed: _load, child: const Text('Retry')),
                        ],
                      ),
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(18),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            notice.companyName,
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.w800,
                                              color: AppTheme.ink,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            notice.title,
                                            style: const TextStyle(
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    NoticeStatusBadge(notice: notice),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 6,
                                  children: [
                                    OpportunityTypeChip(type: notice.opportunityType),
                                    BranchChipsWrap(
                                      isAllBranches: notice.isAllBranches,
                                      branches: notice.targetBranches,
                                    ),
                                  ],
                                ),
                                if (notice.applicationDeadline != null ||
                                    notice.recruitmentDate != null) ...[
                                  const SizedBox(height: 14),
                                  const Divider(height: 1),
                                  const SizedBox(height: 12),
                                  if (notice.applicationDeadline != null)
                                    Container(
                                      width: double.infinity,
                                      padding: const EdgeInsets.all(12),
                                      margin: const EdgeInsets.only(bottom: 8),
                                      decoration: BoxDecoration(
                                        color: notice.isClosingSoon
                                            ? Colors.red.shade50
                                            : Colors.amber.shade50,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: notice.isClosingSoon
                                              ? Colors.red.shade300
                                              : Colors.amber.shade300,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.event_available,
                                            color: notice.isClosingSoon
                                                ? Colors.red.shade800
                                                : Colors.amber.shade900,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                const Text(
                                                  'Application Deadline',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                                Text(
                                                  DateFormat('dd MMM yyyy, hh:mm a')
                                                      .format(notice.applicationDeadline!),
                                                  style: TextStyle(
                                                    fontSize: 14,
                                                    fontWeight: FontWeight.w800,
                                                    color: notice.isClosingSoon
                                                        ? Colors.red.shade900
                                                        : Colors.amber.shade900,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  if (notice.recruitmentDate != null)
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.calendar_month_outlined,
                                          size: 16,
                                          color: AppTheme.slateMuted,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Drive / Recruitment Date: ${fmtDate(notice.recruitmentDate!)}',
                                          style: const TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        if (notice.applicationLink != null &&
                            notice.applicationLink!.trim().isNotEmpty) ...[
                          FilledButton.icon(
                            onPressed: notice.isClosed && !widget.isTpView
                                ? null
                                : () => _launchApplicationLink(notice.applicationLink!),
                            icon: const Icon(Icons.open_in_new),
                            label: Text(
                              notice.isClosed && !widget.isTpView
                                  ? 'Applications Closed'
                                  : 'Open Official Application Link',
                            ),
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (notice.description != null &&
                            notice.description!.trim().isNotEmpty)
                          _sectionCard(
                            'Company Notice / Details',
                            notice.description!,
                            Icons.campaign_outlined,
                          ),
                        if (notice.eligibility != null &&
                            notice.eligibility!.trim().isNotEmpty)
                          _sectionCard(
                            'Eligibility Criteria',
                            notice.eligibility!,
                            Icons.verified_user_outlined,
                          ),
                        if (notice.recruitmentProcess != null &&
                            notice.recruitmentProcess!.trim().isNotEmpty)
                          _sectionCard(
                            'Recruitment Process',
                            notice.recruitmentProcess!,
                            Icons.route_outlined,
                          ),
                        if (notice.additionalNotes != null &&
                            notice.additionalNotes!.trim().isNotEmpty)
                          _sectionCard(
                            'Additional Notes from T&P',
                            notice.additionalNotes!,
                            Icons.notes_outlined,
                          ),
                        if (notice.attachments.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          const Text(
                            'Company Documents & Attachments',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: AppTheme.ink,
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...notice.attachments.map(
                            (a) => NoticeAttachmentTile(attachment: a),
                          ),
                          const SizedBox(height: 8),
                        ],
                        if (!widget.isTpView) ...[
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              if (widget.onAskQuery != null)
                                Expanded(
                                  child: OutlinedButton.icon(
                                    onPressed: () => widget.onAskQuery!(notice),
                                    icon: const Icon(Icons.help_outline),
                                    label: const Text('Ask Query'),
                                  ),
                                ),
                              if (widget.onAskQuery != null &&
                                  widget.onRequestNoc != null)
                                const SizedBox(width: 10),
                              if (widget.onRequestNoc != null)
                                Expanded(
                                  child: FilledButton.tonalIcon(
                                    onPressed: () => widget.onRequestNoc!(notice),
                                    icon: const Icon(Icons.assignment_turned_in_outlined),
                                    label: const Text('Request NOC'),
                                  ),
                                ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 24),
                      ],
                    ),
                  ),
      ),
    );
  }
}
