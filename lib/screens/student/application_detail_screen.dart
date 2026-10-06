import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../models/student_models.dart';
import '../../services/document_progress_service.dart';
import 'student_ui.dart';

class ApplicationDetailScreen extends StatelessWidget {
  final Application application;
  final DocumentProgressDataSource? service;
  const ApplicationDetailScreen({
    super.key,
    required this.application,
    this.service,
  });

  @override
  Widget build(BuildContext context) {
    final job = application.internship;
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: Text(job.title),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Documents'),
              Tab(text: 'Progress'),
            ],
          ),
        ),
        body: Column(
          children: [
            ListTile(
              title: Text(job.companyName),
              subtitle: Text('Applied ${formatDate(application.appliedAt)}'),
              trailing: statusChip(application.status),
            ),
            const Divider(height: 1),
            Expanded(
              child: TabBarView(
                children: [
                  _DocumentsTab(
                    applicationId: application.id,
                    service: service,
                  ),
                  _ProgressTab(application: application, service: service),
                ],
              ),
            ),
          ],
        ),
      ),
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
  final DocumentProgressDataSource? service;
  const _DocumentsTab({required this.applicationId, this.service});

  @override
  State<_DocumentsTab> createState() => _DocumentsTabState();
}

class _DocumentsTabState extends State<_DocumentsTab> {
  late final DocumentProgressDataSource _svc;
  late Future<List<DocumentItem>> _future;
  String _type = 'resume';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? DocumentProgressService();
    _future = _svc.documents(widget.applicationId);
  }

  Future<void> _upload() async {
    final files = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'png', 'jpg', 'jpeg', 'doc', 'docx'],
    );
    if (files.isEmpty) return;
    final f = files.single;
    final size = await f.length();
    if (!mounted) return;
    if (size == null) {
      toast(context, 'Could not read that file.', error: true);
      return;
    }
    if (size > 5 * 1024 * 1024) {
      toast(context, 'File must be under 5 MB.', error: true);
      return;
    }
    setState(() => _busy = true);
    try {
      await _svc.upload(widget.applicationId, _type, f);
      if (!mounted) return;
      setState(() {
        _future = _svc.documents(widget.applicationId);
      });
      toast(context, 'Document uploaded');
    } catch (_) {
      if (mounted) toast(context, 'Upload failed. Try again.', error: true);
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
                  decoration: const InputDecoration(labelText: 'Document type'),
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
                label: Text(_busy ? 'Uploading' : 'Upload'),
              ),
            ],
          ),
        ),
        Expanded(
          child: FutureBuilder<List<DocumentItem>>(
            future: _future,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.hasError) {
                return const Center(child: Text('Could not load documents.'));
              }
              final docs = s.data!;
              if (docs.isEmpty) {
                return const Center(
                  child: Text(
                    'No documents yet. Choose a type and upload a file (max 5 MB).',
                  ),
                );
              }
              return ListView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (final d in docs)
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.description_outlined),
                        title: Text(d.fileName),
                        subtitle: Text(
                          '${_docTypes[d.docType] ?? d.docType} · ${formatDate(d.uploadedAt)}',
                        ),
                      ),
                    ),
                ],
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
  final DocumentProgressDataSource? service;
  const _ProgressTab({required this.application, this.service});

  @override
  State<_ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<_ProgressTab> {
  late final DocumentProgressDataSource _svc;
  final _summary = TextEditingController();
  late Future<List<ProgressLog>> _future;
  double _value = 0;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? DocumentProgressService();
    _future = _svc.progress(widget.application.id);
  }

  @override
  void dispose() {
    _summary.dispose();
    super.dispose();
  }

  int _overall(List<ProgressLog> logs) => logs.isEmpty
      ? 0
      : logs.map((l) => l.progress).reduce((a, b) => a > b ? a : b);

  int _nextWeek(List<ProgressLog> logs) => logs.isEmpty
      ? 1
      : logs.map((l) => l.weekNo).reduce((a, b) => a > b ? a : b) + 1;

  Future<void> _save(List<ProgressLog> logs) async {
    if (_summary.text.trim().isEmpty) {
      toast(context, 'Write a short summary of this week.');
      return;
    }
    if (_value.round() < _overall(logs)) {
      toast(context, 'Progress cannot go below ${_overall(logs)}%.');
      return;
    }
    setState(() => _busy = true);
    try {
      await _svc.addProgress(
        widget.application.id,
        _nextWeek(logs),
        _value.round(),
        _summary.text.trim(),
      );
      if (!mounted) return;
      _summary.clear();
      setState(() {
        _future = _svc.progress(widget.application.id);
      });
      toast(context, 'Progress saved');
    } catch (_) {
      if (mounted) {
        toast(context, 'Could not save progress. Try again.', error: true);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<ProgressLog>>(
      future: _future,
      builder: (context, s) {
        if (s.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (s.hasError) {
          return const Center(child: Text('Could not load progress.'));
        }
        final logs = s.data!;
        final overall = _overall(logs);
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Overall progress: $overall%',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: overall / 100, minHeight: 10),
            const SizedBox(height: 16),
            if (widget.application.status == 'approved')
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Week ${_nextWeek(logs)} update',
                        style: theme.textTheme.titleSmall,
                      ),
                      Slider(
                        value: _value,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label: '${_value.round()}%',
                        onChanged: (v) => setState(() => _value = v),
                      ),
                      TextField(
                        controller: _summary,
                        maxLines: 3,
                        decoration: const InputDecoration(
                          labelText: 'What did you work on this week?',
                        ),
                      ),
                      const SizedBox(height: 12),
                      FilledButton(
                        onPressed: _busy ? null : () => _save(logs),
                        child: const Text('Save update'),
                      ),
                    ],
                  ),
                ),
              )
            else
              const Card(
                child: ListTile(
                  leading: Icon(Icons.info_outline),
                  title: Text(
                    'Progress updates open once your internship is approved.',
                  ),
                ),
              ),
            for (final l in logs)
              Card(
                child: ListTile(
                  title: Text('Week ${l.weekNo} · ${l.progress}%'),
                  subtitle: Text(l.summary),
                ),
              ),
          ],
        );
      },
    );
  }
}
