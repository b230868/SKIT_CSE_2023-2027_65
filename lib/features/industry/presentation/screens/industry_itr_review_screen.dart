import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../itr/data/models/itr_model.dart';
import '../../../itr/data/services/itr_service.dart';

class IndustryItrReviewScreen extends StatefulWidget {
  final ItrModel itr;
  final ItrService? itrService;

  const IndustryItrReviewScreen({
    super.key,
    required this.itr,
    this.itrService,
  });

  @override
  State<IndustryItrReviewScreen> createState() =>
      _IndustryItrReviewScreenState();
}

class _IndustryItrReviewScreenState extends State<IndustryItrReviewScreen> {
  late final ItrService _itrService;
  late final TextEditingController _remarksController;
  late final TextEditingController _reviewerNameController;

  bool _submitting = false;
  late ItrModel _currentItr;

  @override
  void initState() {
    super.initState();
    _itrService = widget.itrService ?? ItrService();
    _currentItr = widget.itr;
    _remarksController =
        TextEditingController(text: widget.itr.remarks ?? '');
    _reviewerNameController =
        TextEditingController(text: widget.itr.reviewerName ?? 'Industry Supervisor');
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _reviewerNameController.dispose();
    super.dispose();
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.blue;
      case 'under_review':
        return Colors.orange;
      case 'approved':
      case 'verified':
        return Colors.green;
      case 'changes_requested':
        return Colors.deepOrange;
      case 'rejected':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not submitted yet';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _handleFileAction(String? filePath, String fileLabel) async {
    if (filePath == null || filePath.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No $fileLabel was uploaded.')),
      );
      return;
    }

    try {
      final url = await _itrService.getFileUrl(filePath);
      if (!mounted) return;

      if (url == null || url.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to generate download URL for $fileLabel.'),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('$fileLabel Download Link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Storage Path:\n$filePath',
                  style: const TextStyle(fontSize: 12, color: Colors.grey)),
              const SizedBox(height: 12),
              const Text('Secure signed URL generated (valid for 1 hour):'),
              const SizedBox(height: 8),
              SelectableText(
                url,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Link'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error accessing file: $e')),
      );
    }
  }

  Future<void> _submitReview(String newStatus) async {
    final remarks = _remarksController.text.trim();
    final reviewerName = _reviewerNameController.text.trim();

    if ((newStatus == 'rejected' || newStatus == 'changes_requested') &&
        remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Please provide remarks explaining why changes are requested or rejected.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await _itrService.reviewItr(
        itrId: _currentItr.id,
        status: newStatus,
        remarks: remarks,
        reviewerName: reviewerName.isNotEmpty ? reviewerName : null,
      );

      if (!mounted) return;

      setState(() {
        _currentItr = ItrModel(
          id: _currentItr.id,
          internshipId: _currentItr.internshipId,
          studentId: _currentItr.studentId,
          studentName: _currentItr.studentName,
          internshipTitle: _currentItr.internshipTitle,
          companyName: _currentItr.companyName,
          status: newStatus,
          content: _currentItr.content,
          workDone: _currentItr.workDone,
          technologiesUsed: _currentItr.technologiesUsed,
          keyLearnings: _currentItr.keyLearnings,
          challengesFaced: _currentItr.challengesFaced,
          documentPath: _currentItr.documentPath,
          projectZipPath: _currentItr.projectZipPath,
          presentationPath: _currentItr.presentationPath,
          submittedAt: _currentItr.submittedAt,
          reviewerName: reviewerName,
          remarks: remarks,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('ITR review saved: ${_formatStatus(newStatus)}'),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Unable to update review: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String? value,
  }) {
    final display = value == null || value.trim().isEmpty ? 'Not provided' : value;
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 24, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(display, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _fileCard({
    required IconData icon,
    required String title,
    required String? filePath,
  }) {
    final hasFile = filePath != null && filePath.trim().isNotEmpty;
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: Icon(icon, color: hasFile ? Colors.blue : Colors.grey),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: Text(
          hasFile ? filePath : 'No file uploaded by student',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: hasFile
            ? TextButton.icon(
                icon: const Icon(Icons.download, size: 18),
                label: const Text('Get Link'),
                onPressed: () => _handleFileAction(filePath, title),
              )
            : const Chip(
                label: Text('Missing', style: TextStyle(fontSize: 11)),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Student ITR'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          child: Text(
                            _currentItr.studentName.isNotEmpty
                                ? _currentItr.studentName[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentItr.studentName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                _currentItr.internshipTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(
                            _formatStatus(_currentItr.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: _getStatusColor(_currentItr.status),
                        ),
                      ],
                    ),
                    const Divider(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Company: ${_currentItr.companyName}',
                            style: const TextStyle(fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Submitted: ${_formatDate(_currentItr.submittedAt)}',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            const Text(
              'Student Deliverables & Documentation',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _fileCard(
              icon: Icons.folder_zip,
              title: 'Project Source Code ZIP',
              filePath: _currentItr.projectZipPath,
            ),

            _fileCard(
              icon: Icons.slideshow,
              title: 'Project Presentation (PPT)',
              filePath: _currentItr.presentationPath,
            ),

            const SizedBox(height: 20),

            const Text(
              'Internship Work & Learning Details',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _infoCard(
              icon: Icons.description,
              title: 'Report Summary',
              value: _currentItr.content,
            ),

            _infoCard(
              icon: Icons.work,
              title: 'Work Completed',
              value: _currentItr.workDone,
            ),

            _infoCard(
              icon: Icons.code,
              title: 'Technologies & Tools Used',
              value: _currentItr.technologiesUsed,
            ),

            _infoCard(
              icon: Icons.school,
              title: 'Key Learnings',
              value: _currentItr.keyLearnings,
            ),

            _infoCard(
              icon: Icons.psychology,
              title: 'Challenges Faced & Solutions',
              value: _currentItr.challengesFaced,
            ),

            const SizedBox(height: 24),

            const Text(
              'Supervisor Review & Evaluation Decision',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _reviewerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Reviewer Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _remarksController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Review Remarks & Feedback',
                        hintText:
                            'Enter your evaluation remarks, feedback, or requested changes...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_submitting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.check_circle),
                            label: const Text('Approve ITR'),
                            onPressed: () => _submitReview('approved'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepOrange.shade800,
                              side: BorderSide(color: Colors.deepOrange.shade600),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Request Changes / Resubmission'),
                            onPressed: () => _submitReview('changes_requested'),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Reject ITR'),
                            onPressed: () => _submitReview('rejected'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
