import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/status_chip.dart';
import '../../../auth/models/app_user.dart';
import '../../data/models/placement_models.dart';
import '../../data/services/placement_repository_provider.dart';
import '../widgets/placement_ui_widgets.dart';
import 'placement_notice_detail_screen.dart';

class StudentPlacementsHubScreen extends StatefulWidget {
  final AppUser? user;
  final int initialTabIndex;
  final PlacementNotice? initialQueryNotice;
  final PlacementNotice? initialNocNotice;

  const StudentPlacementsHubScreen({
    super.key,
    this.user,
    this.initialTabIndex = 0,
    this.initialQueryNotice,
    this.initialNocNotice,
  });

  @override
  State<StudentPlacementsHubScreen> createState() =>
      _StudentPlacementsHubScreenState();
}

class _StudentPlacementsHubScreenState extends State<StudentPlacementsHubScreen>
    with SingleTickerProviderStateMixin {
  final _repo = PlacementRepositoryProvider.instance;
  late final TabController _tabController;

  List<PlacementNotice> _notices = [];
  List<StudentQuery> _queries = [];
  List<TpFaq> _faqs = [];
  List<NocRequest> _nocs = [];
  bool _loading = true;
  String? _error;

  // Notice filters
  final _noticeSearchCtrl = TextEditingController();
  String _typeFilter = 'all';
  String _statusFilter = 'all';
  String _sortBy = 'newest';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _noticeSearchCtrl.addListener(() => setState(() {}));
    _loadAll();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.initialQueryNotice != null) {
        _openAskQuerySheet(prefillNotice: widget.initialQueryNotice);
      } else if (widget.initialNocNotice != null) {
        _openRequestNocDialog(prefillNotice: widget.initialNocNotice);
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _noticeSearchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _repo.getNotices(
          studentView: true,
          studentBranch: widget.user?.branch,
        ),
        _repo.getQueries(tpView: false),
        _repo.getFaqs(includeInactive: false),
        _repo.getNocRequests(tpView: false),
      ]);
      if (!mounted) return;
      setState(() {
        _notices = results[0] as List<PlacementNotice>;
        _queries = results[1] as List<StudentQuery>;
        _faqs = results[2] as List<TpFaq>;
        _nocs = results[3] as List<NocRequest>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load placement feed: $e';
        _loading = false;
      });
    }
  }

  List<PlacementNotice> get _filteredNotices {
    final q = _noticeSearchCtrl.text.trim().toLowerCase();
    final list = _notices.where((n) {
      if (q.isNotEmpty) {
        final match = n.companyName.toLowerCase().contains(q) ||
            n.title.toLowerCase().contains(q) ||
            (n.description?.toLowerCase().contains(q) ?? false) ||
            (n.eligibility?.toLowerCase().contains(q) ?? false);
        if (!match) return false;
      }
      if (_typeFilter != 'all' && n.opportunityType.value != _typeFilter) {
        return false;
      }
      if (_statusFilter == 'unread') {
        if (n.isRead || n.isClosed) return false;
      } else if (_statusFilter == 'closing_soon') {
        if (!n.isClosingSoon) return false;
      } else if (_statusFilter == 'open') {
        if (n.isClosed || n.status == NoticeStatus.upcoming) return false;
      } else if (_statusFilter == 'upcoming') {
        if (n.status != NoticeStatus.upcoming) return false;
      } else if (_statusFilter == 'closed') {
        if (!n.isClosed) return false;
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

  int get _unreadNoticesCount =>
      _notices.where((n) => !n.isRead && !n.isClosed).length;

  int get _unreadQueryRepliesCount =>
      _queries.where((q) => q.hasUnreadReply).length;

  Future<void> _openNoticeDetail(PlacementNotice notice) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PlacementNoticeDetailScreen(
          noticeId: notice.id,
          initialNotice: notice,
          isTpView: false,
          onAskQuery: (n) {
            Navigator.pop(context);
            _tabController.animateTo(1);
            _openAskQuerySheet(prefillNotice: n);
          },
          onRequestNoc: (n) {
            Navigator.pop(context);
            _tabController.animateTo(2);
            _openRequestNocDialog(prefillNotice: n);
          },
        ),
      ),
    );
    _loadAll();
  }

  Future<void> _openAskQuerySheet({PlacementNotice? prefillNotice}) async {
    final questionCtrl = TextEditingController();
    String category = prefillNotice != null ? 'Placement Notice' : 'General';
    String? selectedNoticeId = prefillNotice?.id;
    String? selectedCompany = prefillNotice?.companyName;
    bool submitting = false;
    List<TpFaq> suggestions = [];

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          void updateSuggestions(String text) {
            suggestions = FaqMatcher.suggest(
              text,
              _faqs,
              category: category,
              branch: widget.user?.branch,
              limit: 4,
            );
          }

          return Padding(
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              MediaQuery.of(context).viewInsets.bottom + 16,
            ),
            child: SizedBox(
              height: MediaQuery.of(context).size.height * 0.84,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Ask T&P Cell',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
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
                        DropdownButtonFormField<String>(
                          initialValue: category,
                          decoration: const InputDecoration(
                            labelText: 'Category',
                            prefixIcon: Icon(Icons.category_outlined),
                          ),
                          items: QueryCategories.all
                              .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                              .toList(),
                          onChanged: (v) {
                            if (v == null) return;
                            setModalState(() {
                              category = v;
                              updateSuggestions(questionCtrl.text);
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String?>(
                          initialValue: selectedNoticeId,
                          isExpanded: true,
                          decoration: const InputDecoration(
                            labelText: 'Related Placement Notice (optional)',
                            prefixIcon: Icon(Icons.business_outlined),
                          ),
                          items: [
                            const DropdownMenuItem<String?>(
                              value: null,
                              child: Text('General / Not tied to a specific notice'),
                            ),
                            ..._notices.map(
                              (n) => DropdownMenuItem<String?>(
                                value: n.id,
                                child: Text(
                                  '${n.companyName} · ${n.title}',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            setModalState(() {
                              selectedNoticeId = v;
                              selectedCompany = v == null
                                  ? null
                                  : _notices
                                      .where((n) => n.id == v)
                                      .firstOrNull
                                      ?.companyName;
                            });
                          },
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: questionCtrl,
                          maxLines: 4,
                          decoration: const InputDecoration(
                            labelText: 'Your Question *',
                            hintText:
                                'Type your question (e.g. NOC approval process, eligibility, deadline)...',
                            alignLabelWithHint: true,
                          ),
                          onChanged: (val) {
                            setModalState(() => updateSuggestions(val));
                          },
                        ),
                        const SizedBox(height: 14),
                        if (suggestions.isNotEmpty) ...[
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFFFEF3C7).withValues(alpha: 0.45),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppTheme.saffron),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(
                                      Icons.lightbulb_outline,
                                      size: 18,
                                      color: Color(0xFFB45309),
                                    ),
                                    SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Instant FAQ Answers Found',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 13,
                                          color: Color(0xFFB45309),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                ...suggestions.map(
                                  (faq) => Card(
                                    margin: const EdgeInsets.only(bottom: 8),
                                    child: Padding(
                                      padding: const EdgeInsets.all(12),
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            faq.question,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.w700,
                                              fontSize: 13,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            faq.answer,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              color: AppTheme.slateMuted,
                                            ),
                                          ),
                                          const SizedBox(height: 6),
                                          Align(
                                            alignment: Alignment.centerRight,
                                            child: TextButton.icon(
                                              onPressed: () async {
                                                await _repo.markFaqHelpful(faq.id);
                                                if (!ctx.mounted) return;
                                                Navigator.pop(ctx);
                                                if (mounted) {
                                                  showSnack(
                                                    this.context,
                                                    'Glad that answered your question!',
                                                  );
                                                }
                                              },
                                              icon: const Icon(
                                                Icons.thumb_up_outlined,
                                                size: 14,
                                              ),
                                              label: const Text(
                                                'This answered my question',
                                                style: TextStyle(fontSize: 12),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                const Text(
                                  "Didn't find an answer? Submit your query to T&P Cell below.",
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: AppTheme.slateMuted,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ] else if (questionCtrl.text.trim().length >= 4) ...[
                          const Text(
                            "Didn't find a matching FAQ? Submit your query to T&P Cell.",
                            style: TextStyle(
                              fontSize: 12,
                              color: AppTheme.slateMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  FilledButton.icon(
                    onPressed: submitting
                        ? null
                        : () async {
                            final q = questionCtrl.text.trim();
                            if (q.length < 3) {
                              showSnack(
                                context,
                                'Please enter your question.',
                                error: true,
                              );
                              return;
                            }
                            setModalState(() => submitting = true);
                            try {
                              await _repo.createQuery(
                                noticeId: selectedNoticeId,
                                companyName: selectedCompany,
                                category: category,
                                question: q,
                              );
                              if (ctx.mounted) Navigator.pop(ctx);
                              if (mounted) {
                                showSnack(
                                  this.context,
                                  'Query submitted to T&P Cell.',
                                );
                              }
                              _loadAll();
                            } catch (e) {
                              if (context.mounted) {
                                setModalState(() => submitting = false);
                                showSnack(
                                  context,
                                  'Could not submit query: $e',
                                  error: true,
                                );
                              }
                            }
                          },
                    icon: const Icon(Icons.send),
                    label: Text(
                      submitting ? 'Submitting...' : 'Submit Query to T&P Cell',
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
    questionCtrl.dispose();
  }

  Future<void> _openQueryThread(StudentQuery query) async {
    if (query.hasUnreadReply) {
      await _repo.markQueryRead(queryId: query.id, isTp: false);
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
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.fromLTRB(
            16,
            16,
            16,
            MediaQuery.of(context).viewInsets.bottom + 16,
          ),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.72,
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
                            current.companyName ?? current.category,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          Text(
                            '${current.category} · ${current.status.label}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: AppTheme.slateMuted,
                            ),
                          ),
                        ],
                      ),
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
                        child: Text(
                          current.question,
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ),
                      if (current.replies.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'Waiting for T&P Cell response.',
                              style: TextStyle(color: AppTheme.slateMuted),
                            ),
                          ),
                        )
                      else
                        ...current.replies.map((r) {
                          final isStaff = r.isFromStaff;
                          return Align(
                            alignment: isStaff
                                ? Alignment.centerLeft
                                : Alignment.centerRight,
                            child: Container(
                              constraints: const BoxConstraints(maxWidth: 340),
                              margin: const EdgeInsets.only(bottom: 10),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isStaff
                                    ? const Color(0xFFEFF6FF)
                                    : AppTheme.ink,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    isStaff ? (r.senderName ?? 'T&P Cell') : 'You',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: isStaff
                                          ? const Color(0xFF1D4ED8)
                                          : AppTheme.saffron,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    r.message,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: isStaff ? AppTheme.ink : Colors.white,
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
                if (current.status != QueryStatus.closed) ...[
                  const Divider(),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: replyCtrl,
                          decoration: const InputDecoration(
                            hintText: 'Add follow-up message...',
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(80, 48),
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
                                    senderRole: 'student',
                                  );
                                  replyCtrl.clear();
                                  setModalState(() {
                                    current = StudentQuery(
                                      id: current.id,
                                      studentId: current.studentId,
                                      category: current.category,
                                      question: current.question,
                                      status: current.status,
                                      companyName: current.companyName,
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
                                      'Failed to send: $e',
                                      error: true,
                                    );
                                  }
                                }
                              },
                        child: const Text('Send'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
    replyCtrl.dispose();
    _loadAll();
  }

  Future<void> _openRequestNocDialog({PlacementNotice? prefillNotice}) async {
    final companyCtrl = TextEditingController(
      text: prefillNotice?.companyName ?? '',
    );
    final titleCtrl = TextEditingController(
      text: prefillNotice?.title ?? '',
    );
    final remarksCtrl = TextEditingController();
    PlatformFile? pickedFile;
    bool submitting = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Request NOC from T&P Cell'),
          content: SizedBox(
            width: 440,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: companyCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Company Name *',
                      prefixIcon: Icon(Icons.business_outlined),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Role / Opportunity Title (optional)',
                      prefixIcon: Icon(Icons.work_outline),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: remarksCtrl,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Remarks / Duration / Details (optional)',
                      hintText: 'e.g. Selected for 6-month internship starting Jan',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () async {
                      final res = await FilePicker.pickFiles(
                        type: FileType.custom,
                        allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
                      );
                      if (res.isNotEmpty) {
                        setDialogState(() => pickedFile = res.single);
                      }
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text(
                      pickedFile?.name ?? 'Attach Offer / Proof (optional)',
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: submitting ? null : () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            FilledButton(
              style: FilledButton.styleFrom(minimumSize: const Size(120, 44)),
              onPressed: submitting
                  ? null
                  : () async {
                      if (companyCtrl.text.trim().isEmpty) {
                        showSnack(
                          context,
                          'Please enter the company name.',
                          error: true,
                        );
                        return;
                      }
                      setDialogState(() => submitting = true);
                      try {
                        await _repo.submitNocRequest(
                          noticeId: prefillNotice?.id,
                          companyName: companyCtrl.text.trim(),
                          opportunityTitle: titleCtrl.text.trim(),
                          studentRemarks: remarksCtrl.text.trim(),
                          attachment: pickedFile,
                        );
                        if (ctx.mounted) Navigator.pop(ctx);
                        if (mounted) {
                          showSnack(
                            this.context,
                            'NOC request submitted to T&P Cell.',
                          );
                        }
                        _loadAll();
                      } catch (e) {
                        if (context.mounted) {
                          setDialogState(() => submitting = false);
                          showSnack(
                            context,
                            'Could not submit NOC request: $e',
                            error: true,
                          );
                        }
                      }
                    },
              child: Text(submitting ? 'Submitting...' : 'Submit NOC'),
            ),
          ],
        ),
      ),
    );
    companyCtrl.dispose();
    titleCtrl.dispose();
    remarksCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final branchLabel = widget.user?.branch?.trim();

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('T&P Placements'),
            if (branchLabel != null && branchLabel.isNotEmpty)
              Text(
                'Filtered for $branchLabel branch',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppTheme.slateMuted,
                ),
              ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _loadAll,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: [
            Tab(
              text: _unreadNoticesCount > 0
                  ? 'Notices ($_unreadNoticesCount new)'
                  : 'Notices',
            ),
            Tab(
              text: _unreadQueryRepliesCount > 0
                  ? 'Queries & FAQ ($_unreadQueryRepliesCount)'
                  : 'Queries & FAQ',
            ),
            const Tab(text: 'NOC Requests'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? EmptyStateWidget(
                  icon: Icons.error_outline,
                  title: 'Could not load placements',
                  message: _error!,
                  onRetry: _loadAll,
                )
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildNoticesTab(),
                    _buildQueriesAndFaqsTab(),
                    _buildNocTab(),
                  ],
                ),
    );
  }

  Widget _buildNoticesTab() {
    final items = _filteredNotices;
    return Column(
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _noticeSearchCtrl,
                      decoration: InputDecoration(
                        hintText: 'Search company, role, eligibility...',
                        prefixIcon: const Icon(Icons.search),
                        isDense: true,
                        suffixIcon: _noticeSearchCtrl.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: _noticeSearchCtrl.clear,
                              )
                            : null,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
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
                ],
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    ...{
                      'all': 'All (${_notices.length})',
                      'unread': 'New ($_unreadNoticesCount)',
                      'open': 'Open',
                      'closing_soon': 'Closing Soon',
                      'upcoming': 'Upcoming',
                      'closed': 'Closed',
                    }.entries.map((e) {
                      final sel = _statusFilter == e.key;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
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
                              setState(() => _statusFilter = e.key),
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
                    ChoiceChip(
                      label: const Text('All Types'),
                      selected: _typeFilter == 'all',
                      onSelected: (_) => setState(() => _typeFilter = 'all'),
                    ),
                    const SizedBox(width: 6),
                    ...OpportunityType.values.map(
                      (t) => Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text(t.label),
                          selected: _typeFilter == t.value,
                          onSelected: (_) =>
                              setState(() => _typeFilter = t.value),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: items.isEmpty
              ? const EmptyStateWidget(
                  icon: Icons.campaign_outlined,
                  title: 'No placement notices',
                  message:
                      'Relevant placement and internship opportunities for your branch will appear here.',
                )
              : RefreshIndicator(
                  onRefresh: _loadAll,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: items.length,
                    itemBuilder: (context, idx) {
                      final n = items[idx];
                      return PlacementNoticeCard(
                        notice: n,
                        showUnreadIndicator: true,
                        onTap: () => _openNoticeDetail(n),
                      );
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildQueriesAndFaqsTab() {
    return RefreshIndicator(
      onRefresh: _loadAll,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            color: AppTheme.ink,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Have a question for T&P Cell?',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Instant FAQs are checked first; otherwise your query goes straight to T&P.',
                          style: TextStyle(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppTheme.saffron,
                      foregroundColor: AppTheme.ink,
                      minimumSize: const Size(120, 44),
                    ),
                    onPressed: () => _openAskQuerySheet(),
                    icon: const Icon(Icons.add_comment_outlined, size: 18),
                    label: const Text('Ask Query'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 18),
          const Text(
            'Frequently Asked Questions',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_faqs.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'No FAQs published by T&P Cell yet.',
                  style: TextStyle(color: AppTheme.slateMuted),
                ),
              ),
            )
          else
            ..._faqs.map(
              (faq) => Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ExpansionTile(
                  title: Text(
                    faq.question,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                    ),
                  ),
                  subtitle: Text(
                    faq.category,
                    style: const TextStyle(
                      fontSize: 11,
                      color: AppTheme.slateMuted,
                    ),
                  ),
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          faq.answer,
                          style: const TextStyle(fontSize: 13, height: 1.4),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 20),
          const Text(
            'My Queries',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          if (_queries.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'You have not submitted any queries yet.',
                  style: TextStyle(color: AppTheme.slateMuted),
                ),
              ),
            )
          else
            ..._queries.map((q) {
              return Card(
                margin: const EdgeInsets.only(bottom: 10),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(
                    color: q.hasUnreadReply
                        ? AppTheme.saffron
                        : AppTheme.slateBorder,
                    width: q.hasUnreadReply ? 1.5 : 1,
                  ),
                ),
                child: ListTile(
                  title: Row(
                    children: [
                      Expanded(
                        child: Text(
                          q.companyName ?? q.category,
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ),
                      StatusChip(status: q.status.value),
                    ],
                  ),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 4),
                      Text(
                        q.question,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${fmtDate(q.createdAt)} · ${q.replies.length} repl${q.replies.length == 1 ? 'y' : 'ies'}${q.hasUnreadReply ? ' · New reply' : ''}',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: q.hasUnreadReply
                              ? FontWeight.w700
                              : FontWeight.normal,
                          color: q.hasUnreadReply
                              ? const Color(0xFFB45309)
                              : AppTheme.slateMuted,
                        ),
                      ),
                    ],
                  ),
                  onTap: () => _openQueryThread(q),
                ),
              );
            }),
        ],
      ),
    );
  }

  Widget _buildNocTab() {
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openRequestNocDialog(),
        icon: const Icon(Icons.add),
        label: const Text('Request NOC'),
      ),
      body: _nocs.isEmpty
          ? EmptyStateWidget(
              icon: Icons.assignment_turned_in_outlined,
              title: 'No NOC requests yet',
              message:
                  'Request an NOC for a placement offer or internship directly from the T&P Cell.',
              action: FilledButton.icon(
                onPressed: () => _openRequestNocDialog(),
                icon: const Icon(Icons.add),
                label: const Text('Request NOC'),
              ),
            )
          : RefreshIndicator(
              onRefresh: _loadAll,
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 88),
                itemCount: _nocs.length,
                itemBuilder: (context, idx) {
                  final r = _nocs[idx];
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
                                child: Text(
                                  r.companyName,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              StatusChip(status: r.status),
                            ],
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
                            const SizedBox(height: 6),
                            Text(
                              'Your Remarks: ${r.studentRemarks!}',
                              style: const TextStyle(fontSize: 12),
                            ),
                          ],
                          if (r.rejectionReason != null &&
                              r.rejectionReason!.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Rejection Reason: ${r.rejectionReason!}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.red,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (r.tpRemarks != null && r.tpRemarks!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'T&P Remarks: ${r.tpRemarks!}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: AppTheme.ink,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          if (r.documentPath != null &&
                              r.documentPath!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            TextButton.icon(
                              onPressed: () async {
                                final url = await _repo.getAttachmentUrl(
                                  r.documentPath!,
                                  bucket: r.storageBucket,
                                );
                                if (url != null) {
                                  final uri = Uri.tryParse(url);
                                  if (uri != null) {
                                    await launchUrl(
                                      uri,
                                      mode: LaunchMode.externalApplication,
                                    );
                                  }
                                }
                              },
                              icon: const Icon(Icons.attach_file, size: 16),
                              label: Text(r.documentName ?? 'Attached Document'),
                            ),
                          ],
                          const SizedBox(height: 4),
                          Text(
                            'Requested ${fmtDate(r.createdAt)}',
                            style: const TextStyle(
                              fontSize: 11,
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
    );
  }
}
