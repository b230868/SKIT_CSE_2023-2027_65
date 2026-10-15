import 'package:flutter/material.dart';

import '../../data/models/industry_internship_model.dart';

class IndustryInternshipDetailsScreen extends StatelessWidget {
  final IndustryInternshipModel internship;

  const IndustryInternshipDetailsScreen({
    super.key,
    required this.internship,
  });

  String _formatStatus(String value) {
    return value.replaceAll('_', ' ').toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Internship Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    internship.studentName,
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    internship.internshipTitle,
                    style: const TextStyle(fontSize: 17),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  _InfoRow(
                    label: 'Internship Status',
                    value: _formatStatus(internship.status),
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'Progress',
                    value:
                        '${internship.progress.toStringAsFixed(0)}%',
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'ITR Status',
                    value: _formatStatus(internship.itrStatus),
                  ),
                  const Divider(),
                  _InfoRow(
                    label: 'Evaluation Status',
                    value:
                        _formatStatus(internship.evaluationStatus),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Internship Progress',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  LinearProgressIndicator(
                    value: (internship.progress / 100)
                        .clamp(0.0, 1.0),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${internship.progress.toStringAsFixed(0)}% completed',
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Flexible(
          child: Text(
            value,
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }
}