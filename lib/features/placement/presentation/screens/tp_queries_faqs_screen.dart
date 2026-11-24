import 'package:flutter/material.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../data/models/placement_models.dart';
import '../../data/services/placement_repository_provider.dart';

class TpQueriesFaqsScreen extends StatefulWidget {
  final int initialTabIndex;

  const TpQueriesFaqsScreen({super.key, this.initialTabIndex = 0});

  @override
  State<TpQueriesFaqsScreen> createState() => _TpQueriesFaqsScreenState();
}

class _TpQueriesFaqsScreenState extends State<TpQueriesFaqsScreen>
    with SingleTickerProviderStateMixin {
  final _repo = PlacementRepositoryProvider.instance;
  late final TabController _tabController;

  List<StudentQuery> _queries = [];
  List<TpFaq> _faqs = [];
  List<String> _branches = [];
  bool _loading = true;
  String? _error;

  String _queryStatusFilter = 'all';
  String _queryCategoryFilter = 'all';
  String _queryBranchFilter = 'all';
  final _querySearchCtrl = TextEditingController();
  final _faqSearchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _querySearchCtrl.addListener(() => setState(() {}));
    _faqSearchCtrl.addListener(() => setState(() {}));
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _querySearchCtrl.dispose();
    _faqSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getQueries(tpView: true),
        _repo.getFaqs(includeInactive: true),
        _repo.getAvailableBranches(),
      ]);
      if (!mounted) return;
      setState(() {
        _queries = results[0] as List<StudentQuery>;
        _faqs = results[1] as List<TpFaq>;
        _branches = results[2] as List<String>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load queries & FAQs: $e';
        _loading = false;
      });
    }
  }

  List<StudentQuery> get _filteredQueries {
    final q = _querySearchCtrl.text.trim().toLowerCase();
    return _queries.where((item) {
      if (_queryStatusFilter != 'all' && item.status.value != _queryStatusFilter) {
        return false;
      }
      if (_queryCategoryFilter != 'all' && item.category != _queryCategoryFilter) {
        return false;
      }
      if (_queryBranchFilter != 'all' &&
          (item.studentBranch ?? '').toLowerCase() !=
              _queryBranchFilter.toLowerCase()) {
        return false;
      }
      if (q.isNotEmpty) {
        final match = item.question.toLowerCase().contains(q) ||
            (item.studentName?.toLowerCase().contains(q) ?? false) ||
            (item.companyName?.toLowerCase().contains(q) ?? false) ||
            (item.studentRollNumber?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      return true;
    }).toList();
  }

  List<TpFaq> get _filteredFaqs {
    final q = _faqSearchCtrl.text.trim().toLowerCase();
    if (q.isEmpty) return _faqs;
    return _faqs
        .where(
          (f) =>
              f.question.toLowerCase().contains(q) ||
              f.answer.toLowerCase().contains(q) ||
              f.category.toLowerCase().contains(q) ||
              f.keywords.any((k) => k.toLowerCase().contains(q)),
        )
        .toList();
  }

  int get _pendingQueryCount => _queries
      .where((q) => q.status == QueryStatus.open || (q.status != QueryStatus.closed && !q.isReadByTp))
      .length;

  Future<void> _openQueryThread(StudentQuery query) async {
    if (!query.isReadByTp) {
      await _repo.markQueryRead(queryId: query.id, isTp: true);
    }
    if (!mounted) return;

    final replyCtrl = TextEditingController();
    bool sending = false;
    StudentQuery current = query;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.78,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              current.studentName ?? 'Student',
                              style: const TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            Text(
                              [
                                if (current.studentRollNumber != null)
                                  current.studentRollNumber!,
                                if (current.studentBranch != null)
                                  current.studentBranch!,
                                current.category,
                                if (current.companyName != null)
                                  current.companyName!,
                              ].join(' · '),
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.slateMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (v) async {
                          if (v == 'answered') {
                            await _repo.updateQueryStatus(
                              current.id,
                              QueryStatus.answered,
                            );
                          } else if (v == 'closed') {
                            await _repo.updateQueryStatus(
                              current.id,
                              QueryStatus.closed,
                            );
                          } else if (v == 'open') {
                            await _repo.updateQueryStatus(
                              current.id,
                              QueryStatus.open,
                            );
                          } else if (v == 'faq') {
                            Navigator.pop(ctx);
                            final latestTpReply = current.replies
                                .where((r) => r.isFromStaff)
                                .lastOrNull
                                ?.message;
                            await _showFaqEditor(
                              prefillQuestion: current.question,
                              prefillAnswer: latestTpReply,
                              prefillCategory: current.category,
                            );
                            return;
                          }
                          await _load();
                          if (ctx.mounted) Navigator.pop(ctx);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(
                            value: 'answered',
                            child: Text('Mark as Answered'),
                          ),
                          PopupMenuItem(
                            value: 'closed',
                            child: Text('Close Query'),
                          ),
                          PopupMenuItem(
                            value: 'open',
                            child: Text('Reopen Query'),
                          ),
                          PopupMenuDivider(),
                          PopupMenuItem(
                            value: 'faq',
                            child: Text('Convert to FAQ'),
                          ),
                        ],
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.pop(ctx),
                      ),
                    ],
                  ),
                  const Divider(),
                  Expanded(
                    child: ListView(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(14),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: AppTheme.slateBorder),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Student Question',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AppTheme.slateMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                current.question,
                                style: const TextStyle(fontSize: 14, height: 1.4),
                              ),
                            ],
                          ),
                        ),
                        if (current.replies.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 16),
                            child: Center(
                              child: Text(
                                'No replies yet. Send a response below.',
                                style: TextStyle(color: AppTheme.slateMuted),
                              ),
                            ),
                          )
                        else
                          ...current.replies.map((r) {
                            final isStaff = r.isFromStaff;
                            return Align(
                              alignment: isStaff
                                  ? Alignment.centerRight
                                  : Alignment.centerLeft,
                              child: Container(
                                constraints: const BoxConstraints(maxWidth: 360),
                                margin: const EdgeInsets.only(bottom: 10),
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: isStaff
                                      ? AppTheme.ink
                                      : const Color(0xFFF1F5F9),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      isStaff
                                          ? (r.senderName ?? 'T&P Cell')
                                          : (current.studentName ?? 'Student'),
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: isStaff
                                            ? AppTheme.saffron
                                            : AppTheme.slateMuted,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      r.message,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isStaff ? Colors.white : AppTheme.ink,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: replyCtrl,
                          maxLines: 3,
                          minLines: 1,
                          decoration: const InputDecoration(
                            hintText: 'Write reply to student...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(96, 48),
                        ),
                        onPressed: sending
                            ? null
                            : () async {
                                final msg = replyCtrl.text.trim();
                                if (msg.isEmpty) return;
                                setModalState(() => sending = true);
                                try {
                                  final reply = await _repo.addQueryReply(
                                    queryId: current.id,
                                    message: msg,
                                    senderRole: 'tp_officer',
                                  );
                                  replyCtrl.clear();
                                  setModalState(() {
                                    current = StudentQuery(
                                      id: current.id,
                                      studentId: current.studentId,
                                      studentName: current.studentName,
                                      studentRollNumber: current.studentRollNumber,
                                      studentBranch: current.studentBranch,
                                      noticeId: current.noticeId,
                                      noticeTitle: current.noticeTitle,
                                      companyName: current.companyName,
                                      category: current.category,
                                      question: current.question,
                                      status: QueryStatus.answered,
                                      createdAt: current.createdAt,
                                      replies: [...current.replies, reply],
                                    );
                                    sending = false;
                                  });
                                } catch (e) {
                                  setModalState(() => sending = false);
                                  if (context.mounted) {
                                    showSnack(
                                      context,
                                      'Failed to send reply: $e',
                                      error: true,
                                    );
                                  }
                                }
                              },
                        icon: const Icon(Icons.send, size: 16),
                        label: const Text('Reply'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    replyCtrl.dispose();
    _load();
  }

  Future<void> _showFaqEditor({
    TpFaq? existing,
    String? prefillQuestion,
    String? prefillAnswer,
    String? prefillCategory,
  }) async {
    final qCtrl = TextEditingController(
      text: existing?.question ?? prefillQuestion ?? '',
    );
    final aCtrl = TextEditingController(
      text: existing?.answer ?? prefillAnswer ?? '',
    );
    final kwCtrl = TextEditingController(
      text: existing?.keywords.join(', ') ?? '',
    );
    String category = existing?.category ??
        (prefillCategory != null && QueryCategories.all.contains(prefillCategory)
            ? prefillCategory
            : QueryCategories.all.first);
    bool isAllBranches = existing?.isAllBranches ?? true;
    final selectedBranches = <String>{...?existing?.targetBranches};
    bool isActive = existing?.isActive ?? true;
    bool saving = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: Text(existing == null ? 'Add FAQ' : 'Edit FAQ'),
          content: SizedBox(
            width: 480,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: category,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: QueryCategories.all
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) setDialogState(() => category = v);
                    },
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: qCtrl,
                    maxLines: 2,
                    decoration: const InputDecoration(
                      labelText: 'Question *',
                      hintText: 'e.g. How to apply for NOC?',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: aCtrl,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Answer *',
                      hintText: 'Clear answer shown immediately to students',
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: kwCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Search Keywords (comma-separated)',
                      hintText: 'e.g. noc, approve, certificate, eligibility',
                    ),
                  ),
                  const SizedBox(height: 10),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Applies to All Branches'),
                    value: isAllBranches,
                    onChanged: (v) => setDialogState(() => isAllBranches = v),
                  ),
                  if (!isAllBranches && _branches.isNotEmpty)
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      children: _branches.map((b) {
                        final sel = selectedBranches.contains(b);
                        return FilterChip(
                          label: Text(b, style: const TextStyle(fontSize: 12)),
                          selected: sel,
                          onSelected: (on) {
                            setDialogState(() {
                              if (on) {
                                selectedBranches.add(b);
                              } else {
                                selectedBranches.remove(b);
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Active (visible to students)'),
                    value: isActive,
                    onChanged: (v) => setDialogState(() => isActive = v),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: saving ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(110, 44)),
              onPressed: saving
                  ? null
                  : () async {
                      if (qCtrl.text.trim().isEmpty || aCtrl.text.trim().isEmpty) {
                        showSnack(
                          context,
                          'Question and answer are required.',
                          error: true,
                        );
                        return;
                      }
                      setDialogState(() => saving = true);
                      try {
                        final keywords = kwCtrl.text
                            .split(',')
                            .map((s) => s.trim())
                            .where((s) => s.isNotEmpty)
                            .toList();
                        await _repo.upsertFaq(
                          id: existing?.id,
                          category: category,
                          question: qCtrl.text.trim(),
                          answer: aCtrl.text.trim(),
                          keywords: keywords,
                          targetBranches: selectedBranches.toList(),
                          isAllBranches: isAllBranches,
                          isActive: isActive,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        _load();
                      } catch (e) {
                        setDialogState(() => saving = false);
                        if (context.mounted) {
                          showSnack(context, 'Failed to save FAQ: $e', error: true);
                        }
                      }
                    },
              child: Text(saving ? 'Saving...' : 'Save FAQ'),
            ),
          ],
        ),
      ),
    );
    qCtrl.dispose();
    aCtrl.dispose();
    kwCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pendingCount = _pendingQueryCount;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Queries & FAQs'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _load,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: pendingCount > 0 ? 'Queries ($pendingCount pending)' : 'Queries',
            ),
            Tab(text: 'FAQs (${_faqs.length})'),
          ],
        ),
      ),
      floatingActionButton: ListenableBuilder(
        listenable: _tabController,
        builder: (context, _) {
          if (_tabController.index == 1) {
            return FloatingActionButton.extended(
              onPressed: () => _showFaqEditor(),
              icon: const Icon(Icons.add),
              label: const Text('Add FAQ'),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: 'Could not load data',
                  message: _error!,
                  onRetry: _load,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildQueriesTab(),
                    _buildFaqsTab(),
                  ],
                ),
    );
  }

  Widget _buildQueriesTab() {
    final list = _filteredQueries;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Column(
            children: [
              TextField(
                controller: _querySearchCtrl,
                decoration: InputDecoration(
                  hintText: 'Search queries, student, roll no, company...',
                  prefixIcon: const Icon(Icons.search),
                  isDense: true,
                  suffixIcon: _querySearchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: _querySearchCtrl.clear,
                        )
                      : null,
                ),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...{
                      'all': 'All (${_queries.length})',
                      'open':
                          'Open (${_queries.where((q) => q.status == QueryStatus.open).length})',
                      'answered':
                          'Answered (${_queries.where((q) => q.status == QueryStatus.answered).length})',
                      'closed':
                          'Closed (${_queries.where((q) => q.status == QueryStatus.closed).length})',
                    }.entries.map((e) {
                      final sel = _queryStatusFilter == e.key;
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
                          onSelected: (_) =>
                              setState(() => _queryStatusFilter = e.key),
                        ),
                      );
                    }),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    DropdownButton<String>(
                      value: _queryCategoryFilter,
                      isDense: true,
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Categories', style: TextStyle(fontSize: 12)),
                        ),
                        ...QueryCategories.all.map(
                          (c) => DropdownMenuItem(
                            value: c,
                            child: Text(c, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _queryCategoryFilter = v);
                      },
                    ),
                    const SizedBox(width: 12),
                    DropdownButton<String>(
                      value: _branches.contains(_queryBranchFilter)
                          ? _queryBranchFilter
                          : 'all',
                      isDense: true,
                      items: [
                        const DropdownMenuItem(
                          value: 'all',
                          child: Text('All Branches', style: TextStyle(fontSize: 12)),
                        ),
                        ..._branches.map(
                          (b) => DropdownMenuItem(
                            value: b,
                            child: Text(b, style: const TextStyle(fontSize: 12)),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => _queryBranchFilter = v);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: list.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.question_answer_outlined,
                  title: 'No matching queries',
                  message: 'Student questions about placements, eligibility, or NOCs will appear here.',
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: list.length,
                    itemBuilder: (context, idx) {
                      final item = list[idx];
                      final unread = !item.isReadByTp && item.status == QueryStatus.open;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: unread ? AppTheme.saffron : AppTheme.slateBorder,
                            width: unread ? 1.5 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(14),
                          title: Row(
                            children: [
                              if (unread)
                                Container(
                                  width: 8,
                                  height: 8,
                                  margin: const EdgeInsets.only(right: 6),
                                  decoration: const BoxDecoration(
                                    color: AppTheme.saffron,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              Expanded(
                                child: Text(
                                  item.studentName ?? 'Student',
                                  style: const TextStyle(fontWeight: FontWeight.w700),
                                ),
                              ),
                              _QueryStatusBadge(status: item.status),
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                [
                                  item.category,
                                  if (item.studentBranch != null) item.studentBranch!,
                                  if (item.companyName != null) item.companyName!,
                                ].join(' · '),
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: AppTheme.slateMuted,
                                ),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                item.question,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, color: AppTheme.ink),
                              ),
                              const SizedBox(height: 6),
                              Text(
                                '${fmtDate(item.createdAt)} · ${item.replies.length} repl${item.replies.length == 1 ? 'y' : 'ies'}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppTheme.slateMuted,
                                ),
                              ),
                            ],
                          ),
                          onTap: () => _openQueryThread(item),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildFaqsTab() {
    final list = _filteredFaqs;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: TextField(
            controller: _faqSearchCtrl,
            decoration: InputDecoration(
              hintText: 'Search FAQs by question, keyword, or category...',
              prefixIcon: const Icon(Icons.search),
              isDense: true,
              suffixIcon: _faqSearchCtrl.text.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, size: 18),
                      onPressed: _faqSearchCtrl.clear,
                    )
                  : null,
            ),
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: list.isEmpty
              ? EmptyStateWidget(
                  icon: Icons.quiz_outlined,
                  title: 'No FAQs yet',
                  message:
                      'Add answers to common questions (NOC, eligibility, deadlines) so students get instant answers.',
                  action: FilledButton.icon(
                    onPressed: () => _showFaqEditor(),
                    icon: const Icon(Icons.add),
                    label: const Text('Add First FAQ'),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 88),
                    itemCount: list.length,
                    itemBuilder: (context, idx) {
                      final faq = list[idx];
                      return Card(
                        margin: const EdgeInsets.only(bottom: 10),
                        child: Padding(
                          padding: const EdgeInsets.all(14),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppTheme.ink.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      faq.category,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: AppTheme.ink,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 3,
                                    ),
                                    decoration: BoxDecoration(
                                      color: faq.isActive
                                          ? const Color(0xFFDCFCE7)
                                          : Colors.grey.shade200,
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      faq.isActive ? 'Active' : 'Inactive',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                        color: faq.isActive
                                            ? const Color(0xFF15803D)
                                            : Colors.grey.shade700,
                                      ),
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.edit_outlined, size: 18),
                                    onPressed: () => _showFaqEditor(existing: faq),
                                  ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 18,
                                      color: Colors.red,
                                    ),
                                    onPressed: () async {
                                      await _repo.deleteFaq(faq.id);
                                      _load();
                                    },
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Text(
                                faq.question,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                faq.answer,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppTheme.slateMuted,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }
}

class _QueryStatusBadge extends StatelessWidget {
  final QueryStatus status;

  const _QueryStatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = switch (status) {
      QueryStatus.open => (const Color(0xFFFEF3C7), const Color(0xFFB45309)),
      QueryStatus.answered => (const Color(0xFFDCFCE7), const Color(0xFF15803D)),
      QueryStatus.closed => (Colors.grey.shade200, Colors.grey.shade700),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(12)),
      child: Text(
        status.label,
        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: fg),
      ),
    );
  }
}
