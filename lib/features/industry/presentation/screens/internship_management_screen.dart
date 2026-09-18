import 'package:flutter/material.dart';

import '../../data/models/industry_internship_model.dart';
import '../../data/services/industry_service.dart';
import 'industry_internship_details_screen.dart';

class InternshipManagementScreen extends StatefulWidget {
  const InternshipManagementScreen({super.key});

  @override
  State<InternshipManagementScreen> createState() =>
      _InternshipManagementScreenState();
}

class _InternshipManagementScreenState
    extends State<InternshipManagementScreen> {
  final IndustryService _industryService = IndustryService();

  late Future<List<IndustryInternshipModel>> _internshipsFuture;

  @override
  void initState() {
    super.initState();
    _loadInternships();
  }

  void _loadInternships() {
    _internshipsFuture =
        _industryService.getIndustryInternships();
  }

  Future<void> _refreshInternships() async {
    setState(_loadInternships);
    await _internshipsFuture;
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'active':
      case 'approved':
      case 'verified':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'submitted':
        return Colors.indigo;
      case 'under_review':
      case 'in_progress':
        return Colors.orange;
      case 'pending':
      case 'draft':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  Widget _statusChip(String status) {
    return Chip(
      label: Text(
        _formatStatus(status),
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
        ),
      ),
      backgroundColor: _getStatusColor(status),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Internship Management'),
      ),
      body: FutureBuilder<List<IndustryInternshipModel>>(
        future: _internshipsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState ==
              ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  'Unable to load internships.\n\n'
                  '${snapshot.error}',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }

          final internships = snapshot.data ?? [];

          if (internships.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refreshInternships,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 250),
                  Center(
                    child: Text(
                      'No internships available.',
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refreshInternships,
            child: ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.all(16),
              itemCount: internships.length,
              itemBuilder: (context, index) {
                final internship = internships[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              IndustryInternshipDetailsScreen(
                            internship: internship,
                          ),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                child: Text(
                                  internship.studentName
                                          .isNotEmpty
                                      ? internship.studentName[0]
                                          .toUpperCase()
                                      : 'S',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  internship.studentName,
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                size: 16,
                              ),
                            ],
                          ),

                          const SizedBox(height: 12),

                          Text(
                            internship.internshipTitle,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w500,
                            ),
                          ),

                          const SizedBox(height: 16),

                          LinearProgressIndicator(
                            value: (internship.progress / 100)
                                .clamp(0.0, 1.0),
                          ),

                          const SizedBox(height: 6),

                          Text(
                            'Progress: '
                            '${internship.progress.toStringAsFixed(0)}%',
                          ),

                          const SizedBox(height: 12),

                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: [
                              _statusChip(internship.status),
                              _statusChip(internship.itrStatus),
                              _statusChip(
                                internship.evaluationStatus,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }
}