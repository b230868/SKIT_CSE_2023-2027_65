import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../data/models/placement_models.dart';
import '../../data/services/placement_repository_provider.dart';
import '../widgets/placement_ui_widgets.dart';
import 'placement_notice_detail_screen.dart';
import 'tp_notice_editor_screen.dart';

class TpNoticesScreen extends StatefulWidget {
  final String? initialStatusFilter;

  const TpNoticesScreen({super.key, this.initialStatusFilter});

  @override
  State<TpNoticesScreen> createState() => _TpNoticesScreenState();
}

class _TpNoticesScreenState extends State<TpNoticesScreen> {
  final _repo = PlacementRepositoryProvider.instance;
  final _searchCtrl = TextEditingController();

  List<PlacementNotice> _notices = [];
  List<String> _branches = [];
  bool _loading = true;
  String? _error;

  String _typeFilter = 'all';
  String _statusFilter = 'all';
  String _branchFilter = 'all';
  String _sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    if (widget.initialStatusFilter != null) {
      _statusFilter = widget.initialStatusFilter!;
    }
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
      final results = await Future.wait([
        _repo.getNotices(studentView: false),
        _repo.getAvailableBranches(),
      ]);
      if (!mounted) return;
      setState(() {
        _notices = results[0] as List<PlacementNotice>;
        _branches = results[1] as List<String>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load placement notices: $e';
        _loading = false;
      });
    }
  }

  List<PlacementNotice> get _filtered {
    final q = _searchCtrl.text.trim().toLowerCase();
    final list = _notices.where((n) {
      if (q.isNotEmpty) {
        final match = n.companyName.toLowerCase().contains(q) ||
            n.title.toLowerCase().contains(q) ||
            (n.description?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_typeFilter != 'all' && n.opportunityType.value != _typeFilter) {
        return false;
      }
      if (_statusFilter == 'closing_soon' && !n.isClosingSoon) {
        return false;
      } else if (_statusFilter != 'all' &&
          _statusFilter != 'closing_soon' &&
          n.status.value != _statusFilter) {
        return false;
      }
      if (_branchFilter != 'all' &&
          !BranchUtils.matches(n.targetBranches, n.isAllBranches, _branchFilter)) {
        return false;
      }
      return true;
    }).toList();

    list.sort((a, b) {
      if (_sortBy == 'deadline') {
        final ad = a.applicationDeadline ?? DateTime(2099);
        final bd = b.applicationDeadline ?? DateTime(2099);
        return ad.compareTo(bd);
      }
      return b.createdAt.compareTo(a.createdAt);
    });
    return list;
  }

  Future<void> _openEditor([PlacementNotice? existing]) async {
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => TpNoticeEditorScreen(existing: existing)),
    );
    if (saved == true) _load();
  }

  Future<void> _openDetail(PlacementNotice n) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlacementNoticeDetailScreen(
          noticeId: n.id,
          initialNotice: n,
          isTpView: true,
        ),
      ),
    );
    if (changed == true) _load();
  }

  Future<void> _toggleStatus(PlacementNotice n) async {
    final next = n.status == NoticeStatus.closed ? NoticeStatus.open : NoticeStatus.closed;
    try {
      await _repo.updateNoticeStatus(n.id, next);
      await _load();
      if (mounted) showSnack(context, '${n.companyName} marked ${next.label}.');
    } catch (e) {
      if (mounted) showSnack(context, 'Failed to update notice: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final items = _filtered;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Placement & Internship Notices'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'Sort',
            icon: const Icon(Icons.sort),
            onSelected: (v) => setState(() => _sortBy = v),
            itemBuilder: (_) => [
              CheckedPopupMenuItem(
                value: 'newest',
                checked: _sortBy == 'newest',
                child: const Text('Newest First'),
              ),
              CheckedPopupMenuItem(
                value: 'deadline',
                checked: _sortBy == 'deadline',
                child: const Text('Nearest Deadline'),
              ),
            ],
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openEditor(),
        icon: const Icon(Icons.add),
        label: const Text('Publish Notice'),
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
                    hintText: 'Search by company, title, or keywords...',
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
                    children: [
                      _dropdownChip(
                        label: 'Status',
                        value: _statusFilter,
                        items: const {
                          'all': 'All Status',
                          'open': 'Open',
                          'closing_soon': 'Closing Soon',
                          'upcoming': 'Upcoming',
                          'closed': 'Closed',
                        },
                        onChanged: (v) => setState(() => _statusFilter = v),
                      ),
                      const SizedBox(width: 8),
                      _dropdownChip(
                        label: 'Type',
                        value: _typeFilter,
                        items: {
                          'all': 'All Types',
                          for (final t in OpportunityType.values) t.value: t.label,
                        },
                        onChanged: (v) => setState(() => _typeFilter = v),
                      ),
                      const SizedBox(width: 8),
                      _dropdownChip(
                        label: 'Branch',
                        value: _branchFilter,
                        items: {
                          'all': 'All Branches',
                          for (final b in _branches) b: b,
                        },
                        onChanged: (v) => setState(() => _branchFilter = v),
                      ),
                    ],
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
                        title: 'Could not load notices',
                        message: _error!,
                        onRetry: _load,
                      )
                    : items.isEmpty
                        ? EmptyStateWidget(
                            icon: Icons.campaign_outlined,
                            title: 'No placement notices',
                            message:
                                'Forward a company recruitment notice or share a new internship opening.',
                            action: FilledButton.icon(
                              onPressed: () => _openEditor(),
                              icon: const Icon(Icons.add),
                              label: const Text('Publish Notice'),
                            ),
                          )
                        : RefreshIndicator(
                            onRefresh: _load,
                            child: ListView.builder(
                              padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                              itemCount: items.length,
                              itemBuilder: (context, idx) {
                                final n = items[idx];
                                return PlacementNoticeCard(
                                  notice: n,
                                  onTap: () => _openDetail(n),
                                  trailingMenu: PopupMenuButton<String>(
                                    onSelected: (v) {
                                      if (v == 'edit') _openEditor(n);
                                      if (v == 'toggle') _toggleStatus(n);
                                    },
                                    itemBuilder: (_) => [
                                      const PopupMenuItem(
                                        value: 'edit',
                                        child: Text('Edit'),
                                      ),
                                      PopupMenuItem(
                                        value: 'toggle',
                                        child: Text(
                                          n.status == NoticeStatus.closed
                                              ? 'Reopen'
                                              : 'Close Notice',
                                        ),
                                      ),
                                    ],
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

  Widget _dropdownChip({
    required String label,
    required String value,
    required Map<String, String> items,
    required ValueChanged<String> onChanged,
  }) {
    final active = value != 'all';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: active ? AppTheme.ink.withValues(alpha: 0.08) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: active ? AppTheme.ink : AppTheme.slateBorder,
        ),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: items.containsKey(value) ? value : 'all',
          isDense: true,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppTheme.ink,
          ),
          items: items.entries
              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
              .toList(),
          onChanged: (v) {
            if (v != null) onChanged(v);
          },
        ),
      ),
    );
  }
}
