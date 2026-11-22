import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../core/widgets/status_chip.dart';
import '../../../models/student_models.dart';
import '../../../services/document_progress_service.dart';
import '../../../shared/widgets/empty_state_view.dart';
import '../../../shared/widgets/stepper_timeline.dart';

class StudentApplicationDetailScreen extends StatefulWidget {
  final Application application;
  final DocumentProgressDataSource? service;
  final int initialTabIndex;

  const StudentApplicationDetailScreen({
    super.key,
    required this.application,
    this.service,
    this.initialTabIndex = 0,
  });

  @override
  State<StudentApplicationDetailScreen> createState() => _StudentApplicationDetailScreenState();
}

class _StudentApplicationDetailScreenState extends State<StudentApplicationDetailScreen>
    with SingleTickerProviderStateMixin {
  late final DocumentProgressDataSource _svc;
  late final TabController _tabController;
  late Future<List<DocumentItem>> _docsFuture;
  late Future<List<ProgressLog>> _progressFuture;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? DocumentProgressService();
    _tabController = TabController(length: 3, vsync: this, initialIndex: widget.initialTabIndex);
    _reload();
  }

  void _reload() {
    setState(() {
      _docsFuture = _svc.documents(widget.application.id);
      _progressFuture = _svc.progress(widget.application.id);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final job = widget.application.internship;

    return Scaffold(
      appBar: AppBar(
        title: Text(job.title),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _reload,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.info_outline), text: 'Overview'),
            Tab(icon: Icon(Icons.file_present_outlined), text: 'Documents'),
            Tab(icon: Icon(Icons.timeline), text: 'Progress'),
          ],
        ),
      ),
      body: FutureBuilder<List<dynamic>>(
        future: Future.wait([_docsFuture, _progressFuture]),
        builder: (context, snapshot) {
          final docs = (snapshot.data?[0] as List<DocumentItem>?) ?? [];
          final logs = (snapshot.data?[1] as List<ProgressLog>?) ?? [];
          final currentProgress = logs.isEmpty
              ? job.progress
              : logs.map((l) => l.progress).reduce((a, b) => a > b ? a : b);

          return Column(
            children: [
              // Stepper / Lifecycle Timeline Header
              Hero(
                tag: 'app-card-${widget.application.id}',
                child: Material(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  elevation: 1,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: StepperTimeline.fromApplicationState(
                      status: widget.application.status,
                      documentCount: docs.length,
                      progressPercentage: currentProgress,
                      onStepTap: (index) {
                        // Switch tabs based on step tapped
                        if (index == 2) {
                          _tabController.animateTo(1); // Documents
                        } else if (index == 3) {
                          _tabController.animateTo(2); // Progress
                        } else {
                          _tabController.animateTo(0); // Overview
                        }
                      },
                    ),
                  ),
                ),
              ),
              const Divider(height: 1),

              // Tab Views
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _OverviewTab(
                      application: widget.application,
                      documentCount: docs.length,
                      progressPercentage: currentProgress,
                      onOpenDocuments: () => _tabController.animateTo(1),
                      onOpenProgress: () => _tabController.animateTo(2),
                    ),
                    _DocumentsTab(
                      applicationId: widget.application.id,
                      service: _svc,
                      docsFuture: _docsFuture,
                      onUploaded: _reload,
                    ),
                    _ProgressTab(
                      application: widget.application,
                      service: _svc,
                      progressFuture: _progressFuture,
                      onLogged: _reload,
                    ),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final Application application;
  final int documentCount;
  final int progressPercentage;
  final VoidCallback onOpenDocuments;
  final VoidCallback onOpenProgress;

  const _OverviewTab({
    required this.application,
    required this.documentCount,
    required this.progressPercentage,
    required this.onOpenDocuments,
    required this.onOpenProgress,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final job = application.internship;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // Company & Status Card
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
          ),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        job.companyName,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                      ),
                    ),
                    StatusChip(status: application.status),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  job.title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppTheme.saffron : AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 12,
                  runSpacing: 8,
                  children: [
                    _Badge(Icons.calendar_today, 'Applied: ${fmtDate(application.appliedAt)}'),
                    _Badge(Icons.date_range, '${fmtDate(job.startDate)} - ${fmtDate(job.endDate)}'),
                    _Badge(Icons.location_on_outlined, job.mode.toUpperCase()),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),

        // Quick Stats Row
        Row(
          children: [
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onOpenDocuments,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.file_present_outlined, color: AppTheme.ink),
                        const SizedBox(height: 8),
                        Text(
                          '$documentCount',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Documents',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: onOpenProgress,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.trending_up, color: AppTheme.saffron),
                        const SizedBox(height: 8),
                        Text(
                          '$progressPercentage%',
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
                        ),
                        Text(
                          'Progress Logged',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        if (job.description != null && job.description!.trim().isNotEmpty) ...[
          const Text(
            'Internship Description',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1F2937) : Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
            ),
            child: Text(
              job.description!,
              style: TextStyle(
                fontSize: 13,
                height: 1.5,
                color: isDark ? Colors.grey.shade300 : Colors.grey.shade800,
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _Badge extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Badge(this.icon, this.text);

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: isDark ? Colors.grey.shade400 : Colors.grey.shade600),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
          ),
        ),
      ],
    );
  }
}

const _docTypes = {
  'resume': 'Resume',
  'offer_letter': 'Offer letter',
  'noc': 'NOC',
  'certificate': 'Certificate',
  'other': 'Other',
};

class _DocumentsTab extends StatefulWidget {
  final String applicationId;
  final DocumentProgressDataSource service;
  final Future<List<DocumentItem>> docsFuture;
  final VoidCallback onUploaded;

  const _DocumentsTab({
    required this.applicationId,
    required this.service,
    required this.docsFuture,
    required this.onUploaded,
  });

  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  String _type = 'resume';
  bool _busy = false;

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );
    if (result == null || result.files.isEmpty) return;

    final file = result.files.single;
    final size = file.size;

    if (size > 5 * 1024 * 1024) {
      if (mounted) showSnack(context, 'File must be under 5 MB.', error: true);
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.service.upload(widget.applicationId, _type, file);
      if (!mounted) return;
      showSnack(context, 'Document uploaded successfully');
      widget.onUploaded();
    } catch (_) {
      if (mounted) showSnack(context, 'Upload failed. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: 'Document Type'),
                  items: _docTypes.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _type = v ?? _type),
                ),
              ),
              const SizedBox(width: 12),
              FilledButton.icon(
                onPressed: _busy ? null : _upload,
                icon: const Icon(Icons.upload_file),
                label: Text(_busy ? 'Uploading...' : 'Upload'),
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: FutureBuilder<List<DocumentItem>>(
            future: widget.docsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data ?? [];
              if (docs.isEmpty) {
                return const EmptyStateView(
                  icon: Icons.file_present_outlined,
                  title: 'No documents uploaded yet',
                  description: 'Upload your resume, offer letter, or NOC to keep records up to date.',
                );
              }
              return ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: docs.length,
                itemBuilder: (context, i) {
                  final d = docs[i];
                  return Card(
                    elevation: 0,
                    margin: const EdgeInsets.only(bottom: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: BorderSide(color: Colors.grey.shade300),
                    ),
                    child: ListTile(
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFEFF6FF),
                        child: Icon(Icons.description, color: AppTheme.ink),
                      ),
                      title: Text(_docTypes[d.docType] ?? d.docType),
                      subtitle: Text('${d.fileName} · ${fmtDate(d.uploadedAt)}'),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

class _ProgressTab extends StatefulWidget {
  final Application application;
  final DocumentProgressDataSource service;
  final Future<List<ProgressLog>> progressFuture;
  final VoidCallback onLogged;

  const _ProgressTab({
    required this.application,
    required this.service,
    required this.progressFuture,
    required this.onLogged,
  });

  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<_ProgressTab> {
  final _summaryController = TextEditingController();
  double _sliderValue = 0;
  bool _busy = false;

  @override
  void dispose() {
    _summaryController.dispose();
    super.dispose();
  }

  int _overall(List<ProgressLog> logs) => logs.isEmpty
      ? widget.application.internship.progress
      : logs.map((l) => l.progress).reduce((a, b) => a > b ? a : b);

  int _nextWeek(List<ProgressLog> logs) => logs.isEmpty
      ? 1
      : logs.map((l) => l.weekNo).reduce((a, b) => a > b ? a : b) + 1;

  Future<void> _submitProgress(List<ProgressLog> logs) async {
    if (_summaryController.text.trim().isEmpty) {
      showSnack(context, 'Please enter a summary of tasks completed.');
      return;
    }
    final nextWeek = _nextWeek(logs);
    final target = _sliderValue.round();
    final current = _overall(logs);

    if (target < current) {
      showSnack(context, 'Progress cannot decrease below $current%.');
      return;
    }

    setState(() => _busy = true);
    try {
      await widget.service.addProgress(
        widget.application.id,
        nextWeek,
        target,
        _summaryController.text.trim(),
      );
      if (!mounted) return;
      _summaryController.clear();
      showSnack(context, 'Week $nextWeek progress logged!');
      widget.onLogged();
    } catch (_) {
      if (mounted) showSnack(context, 'Could not save progress.', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isApproved = widget.application.status == 'approved' ||
        widget.application.status == 'active' ||
        widget.application.status == 'completed';

    return FutureBuilder<List<ProgressLog>>(
      future: widget.progressFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        final logs = snapshot.data ?? [];
        final overall = _overall(logs);

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // Progress Bar Summary Card
            Card(
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
                side: BorderSide(color: Colors.grey.shade300),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Overall Completion',
                          style: TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                        ),
                        Text(
                          '$overall%',
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 18,
                            color: AppTheme.saffron,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: overall / 100.0,
                        minHeight: 10,
                        backgroundColor: Colors.grey.shade200,
                        valueColor: const AlwaysStoppedAnimation(AppTheme.ink),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Form to log new week if approved
            if (isApproved)
              Card(
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side: BorderSide(color: Colors.grey.shade300),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Log Week ${_nextWeek(logs)} Progress',
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: Slider(
                              value: _sliderValue < overall ? overall.toDouble() : _sliderValue,
                              min: 0,
                              max: 100,
                              divisions: 20,
                              label: '${_sliderValue.round()}%',
                              onChanged: (v) => setState(() => _sliderValue = v),
                            ),
                          ),
                          Text('${_sliderValue.round()}%', style: const TextStyle(fontWeight: FontWeight.w700)),
                        ],
                      ),
                      TextField(
                        controller: _summaryController,
                        decoration: const InputDecoration(
                          labelText: 'Tasks and deliverables completed this week',
                          hintText: 'e.g. Completed module API endpoints and unit tests.',
                        ),
                        maxLines: 2,
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          onPressed: _busy ? null : () => _submitProgress(logs),
                          icon: const Icon(Icons.check, size: 18),
                          label: Text(_busy ? 'Saving...' : 'Submit Week Log'),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 16),

            const Text(
              'Weekly Progress Logs',
              style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            ),
            const SizedBox(height: 10),

            if (logs.isEmpty)
              const EmptyStateView(
                icon: Icons.timeline,
                title: 'No progress logged yet',
                description: 'Once approved, log your weekly activities to build your report.',
              )
            else
              ...logs.map(
                (l) => Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.grey.shade300),
                  ),
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppTheme.ink,
                      child: Text(
                        'W${l.weekNo}',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    title: Text('${l.progress}% Complete'),
                    subtitle: Text(l.summary),
                    trailing: Text('Week ${l.weekNo}', style: const TextStyle(fontSize: 11)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
