import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme.dart';
import '../../../core/utils.dart';
import '../../../core/widgets/status_chip.dart';
import '../../geo_progress/models/geo_progress_log.dart';
import '../../geo_progress/services/geo_progress_service.dart';
import '../data/internship_service.dart';
import '../models/internship.dart';
import 'internship_form_screen.dart';

/// One internship: details, progress tracking and documents.
class InternshipDetailScreen extends StatefulWidget {
  final String internshipId;
  const InternshipDetailScreen({super.key, required this.internshipId});

  @override
  State<InternshipDetailScreen> createState() => _InternshipDetailScreenState();
}

class _InternshipDetailScreenState extends State<InternshipDetailScreen> {
  final _service = InternshipService();
  final _geoProgressService = GeoProgressService();

  Internship? _internship;
  List<GeoProgressLog> _updates = [];
  List<InternshipDocument> _docs = [];
  bool _loading = true;
  bool _uploading = false;
  bool _syncingProgress = false;
  bool _submittingProgress = false;
  String? _error;
  String? _progressError;

  int get _currentProgress => _updates.fold<int>(
    _internship?.progress ?? 0,
    (current, update) =>
        current > update.progressPercent ? current : update.progressPercent,
  );

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      Internship internship;
      try {
        internship = await _service.fetchOne(widget.internshipId);
      } catch (_) {
        if (_internship == null) rethrow;
        internship = _internship!;
      }
      List<InternshipDocument> docs;
      try {
        docs = await _service.fetchDocuments(widget.internshipId);
      } catch (_) {
        docs = _docs;
      }
      List<GeoProgressLog> updates;
      String? progressError;
      try {
        updates = await _geoProgressService.fetchHistory(widget.internshipId);
      } catch (error) {
        updates = _updates;
        progressError = error.toString();
      }
      if (!mounted) return;
      setState(() {
        _internship = internship;
        _updates = updates;
        _docs = docs;
        _loading = false;
        _error = null;
        _progressError = progressError;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        if (_internship == null) _error = 'Could not load this internship.';
      });
    }
  }

  Future<void> _syncProgress() async {
    if (_syncingProgress) return;
    setState(() => _syncingProgress = true);
    try {
      final result = await _geoProgressService.syncPendingProgress();
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final firstFailure = result.failures.isEmpty
          ? null
          : result.failures.values.first;
      setState(() {
        _progressError = result.remainingCount == 0
            ? null
            : 'Synced ${result.syncedCount} update(s); '
                  '${result.remainingCount} still waiting. '
                  '${firstFailure ?? ''}';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() => _progressError = 'Could not sync progress: $error');
    } finally {
      if (mounted) setState(() => _syncingProgress = false);
    }
  }

  Future<void> _edit() async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => InternshipFormScreen(existing: _internship),
      ),
    );
    _load();
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete this application?'),
        content: const Text(
          'Its progress updates and documents will be removed too.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _service.delete(widget.internshipId);
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Could not delete the application', error: true);
      }
    }
  }

  Future<void> _addProgress() async {
    if (_internship?.status != 'approved' || _submittingProgress) return;
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => _ProgressDialog(initial: _currentProgress),
    );
    if (!mounted || result == null) return;
    if ((result['percent'] as int) < _currentProgress) {
      showSnack(
        context,
        'Progress cannot go below $_currentProgress%.',
        error: true,
      );
      return;
    }
    setState(() => _submittingProgress = true);
    try {
      final update = await _geoProgressService.submitProgress(
        internshipId: widget.internshipId,
        taskSummary: result['note'] as String,
        progressPercent: result['percent'] as int,
      );
      await _load();
      if (mounted) {
        showSnack(
          context,
          update.isPendingSync
              ? 'Progress saved on this device and waiting to sync'
              : 'Progress updated',
        );
      }
    } catch (error) {
      if (mounted) {
        showSnack(context, 'Could not save the update: $error', error: true);
      }
    } finally {
      if (mounted) setState(() => _submittingProgress = false);
    }
  }

  Future<void> _upload() async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'doc', 'docx', 'png', 'jpg', 'jpeg'],
    );
    if (picked.isEmpty) return;
    final file = picked.single;
    final size = await file.length();
    if (size == null) {
      if (mounted) {
        showSnack(context, 'Could not read the selected file', error: true);
      }
      return;
    }
    if (size > 10 * 1024 * 1024) {
      if (mounted) {
        showSnack(context, 'Choose a file smaller than 10 MB', error: true);
      }
      return;
    }
    setState(() => _uploading = true);
    try {
      await _service.uploadDocument(widget.internshipId, file);
      if (mounted) showSnack(context, 'Document uploaded');
      _load();
    } catch (_) {
      if (mounted) showSnack(context, 'Upload failed. Try again.', error: true);
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<void> _openDoc(InternshipDocument doc) async {
    try {
      final url = await _service.signedUrl(doc.filePath);
      await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Could not open the document', error: true);
      }
    }
  }

  Future<void> _deleteDoc(InternshipDocument doc) async {
    try {
      await _service.deleteDocument(doc, internshipId: widget.internshipId);
      _load();
    } catch (_) {
      if (mounted) {
        showSnack(context, 'Could not delete the document', error: true);
      }
    }
  }

  Widget _sectionHeader(String title, {Widget? action}) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
          ),
          ?action,
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final i = _internship;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Internship'),
        actions: [
          if (i != null && i.isEditable)
            PopupMenuButton<String>(
              onSelected: (v) => v == 'edit' ? _edit() : _delete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit application')),
                PopupMenuItem(
                  value: 'delete',
                  child: Text('Delete application'),
                ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null || i == null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_error ?? 'Not found'),
                  TextButton(onPressed: _load, child: const Text('Try again')),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 40),
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          i.title,
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w800,
                            color: AppTheme.ink,
                          ),
                        ),
                      ),
                      StatusChip(status: i.status),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    i.companyName,
                    style: TextStyle(fontSize: 15, color: Colors.grey.shade700),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey.shade300),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _InfoRow(
                          'Duration',
                          '${fmtDate(i.startDate)} to ${fmtDate(i.endDate)}',
                        ),
                        _InfoRow(
                          'Work mode',
                          i.mode[0].toUpperCase() + i.mode.substring(1),
                        ),
                        if (i.description != null && i.description!.isNotEmpty)
                          _InfoRow('About', i.description!),
                      ],
                    ),
                  ),
                  _sectionHeader(
                    'Progress',
                    action: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_updates.any((update) => update.isPendingSync))
                          TextButton.icon(
                            onPressed: _syncingProgress ? null : _syncProgress,
                            icon: _syncingProgress
                                ? const SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(Icons.sync),
                            label: const Text('Sync'),
                          ),
                        TextButton.icon(
                          onPressed: _submittingProgress ? null : _addProgress,
                          icon: const Icon(Icons.add),
                          label: const Text('Add update'),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: _currentProgress / 100,
                            minHeight: 10,
                            backgroundColor: Colors.grey.shade200,
                            color: AppTheme.saffron,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$_currentProgress%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (_progressError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        _progressError!,
                        style: TextStyle(color: Colors.red.shade700),
                      ),
                    ),
                  if (_updates.isEmpty)
                    Text(
                      'No updates yet. Add one when you finish a milestone.',
                      style: TextStyle(color: Colors.grey.shade700),
                    )
                  else
                    ..._updates.map(
                      (u) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppTheme.ink,
                          child: Text(
                            '${u.progressPercent}%',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                            ),
                          ),
                        ),
                        title: Text(u.taskSummary),
                        subtitle: Text(
                          '${fmtDate(u.capturedAt)}'
                          '${u.isPendingSync ? ' • Waiting to sync' : ''}',
                        ),
                      ),
                    ),
                  _sectionHeader(
                    'Documents',
                    action: TextButton.icon(
                      onPressed: _uploading ? null : _upload,
                      icon: _uploading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.upload_file),
                      label: Text(_uploading ? 'Uploading' : 'Upload'),
                    ),
                  ),
                  if (_docs.isEmpty)
                    Text(
                      'Upload your offer letter, certificate or reports here.',
                      style: TextStyle(color: Colors.grey.shade700),
                    )
                  else
                    ..._docs.map(
                      (d) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: const Icon(Icons.insert_drive_file_outlined),
                        title: Text(
                          d.fileName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text('Added ${fmtDate(d.createdAt)}'),
                        onTap: () => _openDoc(d),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () => _deleteDoc(d),
                        ),
                      ),
                    ),
                ],
              ),
            ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 90,
            child: Text(label, style: TextStyle(color: Colors.grey.shade600)),
          ),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

class _ProgressDialog extends StatefulWidget {
  final int initial;
  const _ProgressDialog({required this.initial});

  @override
  State<_ProgressDialog> createState() => _ProgressDialogState();
}

class _ProgressDialogState extends State<_ProgressDialog> {
  final _note = TextEditingController();
  late double _percent;
  String? _error;

  @override
  void initState() {
    super.initState();
    _percent = (widget.initial / 5).round() * 5.0;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add progress update'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Overall progress: ${_percent.round()}%',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            Slider(
              value: _percent,
              min: 0,
              max: 100,
              divisions: 20,
              label: '${_percent.round()}%',
              onChanged: (v) => setState(() => _percent = v),
            ),
            TextField(
              controller: _note,
              maxLines: 3,
              maxLength: 500,
              decoration: InputDecoration(
                labelText: 'What did you complete?',
                errorText: _error,
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(minimumSize: const Size(100, 44)),
          onPressed: () {
            final summary = _note.text.trim();
            if (summary.length < 3 || summary.length > 500) {
              setState(
                () =>
                    _error = 'Describe 3 to 500 characters of completed work.',
              );
              return;
            }
            Navigator.pop(context, {
              'note': summary,
              'percent': _percent.round(),
            });
          },
          child: const Text('Save update'),
        ),
      ],
    );
  }
}
