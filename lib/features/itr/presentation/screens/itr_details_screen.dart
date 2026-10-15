import 'package:flutter/material.dart';

import '../../data/models/itr_model.dart';
import '../../data/services/itr_service.dart';
import 'itr_submission_screen.dart';

class ItrDetailsScreen extends StatelessWidget {
  final ItrModel itr;
  final ItrService itrService;

  const ItrDetailsScreen({
    super.key,
    required this.itr,
    required this.itrService,
  });

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
    if (date == null) {
      return 'Not submitted yet';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Widget _section({
    required IconData icon,
    required String title,
    required String? value,
  }) {
    final displayValue = value == null || value.trim().isEmpty
        ? 'Not available'
        : value;

    return Card(
      margin: const EdgeInsets.only(bottom: 14),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon),

            const SizedBox(width: 14),

            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),

                  const SizedBox(height: 8),

                  Text(displayValue, style: const TextStyle(fontSize: 15)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  bool get _canEdit {
    return itr.status == 'draft' ||
        itr.status == 'changes_requested' ||
        itr.status == 'rejected';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ITR Details')),

      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),

        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,

          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),

                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,

                  children: [
                    const Icon(Icons.description, size: 45),

                    const SizedBox(height: 16),

                    Text(
                      itr.internshipTitle,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 8),

                    Text(itr.companyName, style: const TextStyle(fontSize: 16)),

                    const SizedBox(height: 16),

                    Chip(
                      label: Text(
                        _formatStatus(itr.status),
                        style: const TextStyle(color: Colors.white),
                      ),
                      backgroundColor: _getStatusColor(itr.status),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Submission Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _section(
              icon: Icons.calendar_today,
              title: 'Submission Date',
              value: _formatDate(itr.submittedAt),
            ),

            const SizedBox(height: 10),

            const Text(
              'Internship Work Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _section(
              icon: Icons.description_outlined,
              title: 'Internship Report Summary',
              value: itr.content,
            ),

            _section(
              icon: Icons.work,
              title: 'Work Done / Project Completed',
              value: itr.workDone,
            ),

            _section(
              icon: Icons.code,
              title: 'Technologies & Tools Used',
              value: itr.technologiesUsed,
            ),

            _section(
              icon: Icons.school,
              title: 'Key Learnings',
              value: itr.keyLearnings,
            ),

            _section(
              icon: Icons.psychology,
              title: 'Challenges Faced',
              value: itr.challengesFaced,
            ),

            const SizedBox(height: 10),

            const Text(
              'Review Information',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 12),

            _section(
              icon: Icons.person,
              title: 'Reviewer',
              value: itr.reviewerName,
            ),

            _section(
              icon: Icons.comment,
              title: 'Reviewer Remarks',
              value: itr.remarks,
            ),

            const SizedBox(height: 24),

            if (_canEdit)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ItrSubmissionScreen(
                          itr: itr,
                          itrService: itrService,
                        ),
                      ),
                    );

                    if (result == true && context.mounted) {
                      Navigator.pop(context, true);
                    }
                  },
                  icon: const Icon(Icons.edit),
                  label: Text(
                    itr.status == 'draft'
                        ? 'Complete & Submit ITR'
                        : 'Edit & Resubmit ITR',
                  ),
                ),
              ),

            if (!_canEdit)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline),

                      const SizedBox(width: 12),

                      Expanded(
                        child: Text(
                          'This ITR cannot currently be edited because it is ${_formatStatus(itr.status)}.',
                        ),
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
