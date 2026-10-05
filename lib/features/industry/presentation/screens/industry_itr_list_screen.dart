import 'package:flutter/material.dart';

import '../../../itr/data/models/itr_model.dart';
import '../../../itr/data/services/itr_service.dart';
import 'industry_itr_review_screen.dart';

class IndustryItrListScreen extends StatefulWidget {
  final ItrService? itrService;

  const IndustryItrListScreen({super.key, this.itrService});

  @override
  State<IndustryItrListScreen> createState() => _IndustryItrListScreenState();
}

class _IndustryItrListScreenState extends State<IndustryItrListScreen> {
  late final ItrService _itrService;
  late Future<List<ItrModel>> _itrsFuture;

  @override
  void initState() {
    super.initState();
    _itrService = widget.itrService ?? ItrService();
    _loadItrs();
  }

  void _loadItrs() {
    _itrsFuture = _itrService.getIndustryItrs();
  }

  Future<void> _refresh() async {
    setState(_loadItrs);
    await _itrsFuture;
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
    if (date == null) return 'Draft / Unsubmitted';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Student ITRs'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _refresh,
          ),
        ],
      ),
      body: FutureBuilder<List<ItrModel>>(
        future: _itrsFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading student ITRs...'),
                ],
              ),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 55,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'Unable to load ITRs',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${snapshot.error}',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey.shade700),
                    ),
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final itrs = snapshot.data ?? [];

          if (itrs.isEmpty) {
            return RefreshIndicator(
              onRefresh: _refresh,
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 180),
                  Icon(Icons.assignment_outlined, size: 65, color: Colors.grey),
                  SizedBox(height: 16),
                  Center(
                    child: Text(
                      'No student ITR submissions found.',
                      style: TextStyle(fontSize: 17, fontWeight: FontWeight.w600),
                    ),
                  ),
                  SizedBox(height: 8),
                  Center(
                    child: Text(
                      'When assigned interns submit their reports, they will appear here.',
                      style: TextStyle(color: Colors.grey),
                    ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: itrs.length,
              itemBuilder: (context, index) {
                final itr = itrs[index];

                return Card(
                  margin: const EdgeInsets.only(bottom: 14),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => IndustryItrReviewScreen(
                            itr: itr,
                            itrService: _itrService,
                          ),
                        ),
                      );

                      if (result == true) {
                        await _refresh();
                      }
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              CircleAvatar(
                                child: Text(
                                  itr.studentName.isNotEmpty
                                      ? itr.studentName[0].toUpperCase()
                                      : 'S',
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      itr.studentName,
                                      style: const TextStyle(
                                        fontSize: 17,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      itr.internshipTitle,
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Colors.grey.shade700,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Chip(
                                label: Text(
                                  _formatStatus(itr.status),
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                backgroundColor: _getStatusColor(itr.status),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          if (itr.content != null && itr.content!.trim().isNotEmpty)
                            Text(
                              itr.content!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontSize: 13),
                            ),
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Submitted: ${_formatDate(itr.submittedAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                              const Row(
                                children: [
                                  Text(
                                    'Review Report',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.blue,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  SizedBox(width: 4),
                                  Icon(
                                    Icons.arrow_forward_ios,
                                    size: 13,
                                    color: Colors.blue,
                                  ),
                                ],
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
