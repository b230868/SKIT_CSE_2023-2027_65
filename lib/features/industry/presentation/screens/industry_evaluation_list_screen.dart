import 'package:flutter/material.dart';

import '../../data/models/industry_evaluation_model.dart';
import '../../data/services/industry_evaluation_service.dart';
import 'industry_evaluation_form_screen.dart';

class IndustryEvaluationListScreen extends StatefulWidget {
  final IndustryEvaluationService? evaluationService;

  const IndustryEvaluationListScreen({super.key, this.evaluationService});

  @override
  State<IndustryEvaluationListScreen> createState() =>
      _IndustryEvaluationListScreenState();
}

class _IndustryEvaluationListScreenState
    extends State<IndustryEvaluationListScreen> {
  late final IndustryEvaluationService _service;
  late Future<List<IndustryEvaluationModel>> _future;

  String _filterStatus = 'all';
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _service = widget.evaluationService ?? IndustryEvaluationService();
    _loadEvaluations();
  }

  void _loadEvaluations() {
    _future = _service.getEvaluations();
  }

  Future<void> _refresh() async {
    setState(_loadEvaluations);
    await _future;
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'verified':
      case 'completed':
        return Colors.green;
      case 'in_progress':
        return Colors.orange;
      case 'pending':
        return Colors.blue;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Color _getGradeColor(String grade) {
    switch (grade) {
      case 'A+':
      case 'A':
        return Colors.green;
      case 'B+':
      case 'B':
        return Colors.blue;
      case 'C':
        return Colors.orange;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Intern Evaluations & Verification'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter Bar
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Search intern or title...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.trim()),
            ),
          ),

          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _filterStatus == 'all',
                  onSelected: (_) => setState(() => _filterStatus = 'all'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Pending'),
                  selected: _filterStatus == 'pending',
                  onSelected: (_) => setState(() => _filterStatus = 'pending'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('In Progress'),
                  selected: _filterStatus == 'in_progress',
                  onSelected: (_) =>
                      setState(() => _filterStatus = 'in_progress'),
                ),
                const SizedBox(width: 8),
                FilterChip(
                  label: const Text('Verified'),
                  selected: _filterStatus == 'verified',
                  onSelected: (_) => setState(() => _filterStatus = 'verified'),
                ),
              ],
            ),
          ),

          const Divider(),

          Expanded(
            child: FutureBuilder<List<IndustryEvaluationModel>>(
              future: _future,
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }

                if (snapshot.hasError) {
                  return Center(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.error_outline,
                            size: 50,
                            color: Colors.red,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Unable to load evaluations.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            '${snapshot.error}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: Colors.grey),
                          ),
                          const SizedBox(height: 16),
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

                final rawList = snapshot.data ?? [];

                final filtered = rawList.where((item) {
                  final matchesFilter =
                      _filterStatus == 'all' ||
                      item.status.toLowerCase() == _filterStatus.toLowerCase();

                  final query = _searchQuery.toLowerCase();
                  final matchesSearch =
                      query.isEmpty ||
                      item.studentName.toLowerCase().contains(query) ||
                      item.internshipTitle.toLowerCase().contains(query);

                  return matchesFilter && matchesSearch;
                }).toList();

                if (filtered.isEmpty) {
                  return RefreshIndicator(
                    onRefresh: _refresh,
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 160),
                        Icon(
                          Icons.assignment_turned_in_outlined,
                          size: 60,
                          color: Colors.grey,
                        ),
                        SizedBox(height: 14),
                        Center(
                          child: Text(
                            'No evaluation records found.',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        SizedBox(height: 6),
                        Center(
                          child: Text(
                            'Assigned intern evaluations will appear here.',
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
                    physics: const AlwaysScrollableScrollPhysics(),
                    padding: const EdgeInsets.all(16),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final item = filtered[index];

                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: InkWell(
                          borderRadius: BorderRadius.circular(12),
                          onTap: () async {
                            final changed = await Navigator.push<bool>(
                              context,
                              MaterialPageRoute(
                                builder: (_) => IndustryEvaluationFormScreen(
                                  evaluation: item,
                                  evaluationService: _service,
                                ),
                              ),
                            );
                            if (changed == true) {
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
                                        item.studentName.isNotEmpty
                                            ? item.studentName[0].toUpperCase()
                                            : 'S',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item.studentName,
                                            style: const TextStyle(
                                              fontSize: 17,
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          Text(
                                            item.internshipTitle,
                                            style: TextStyle(
                                              fontSize: 13,
                                              color: Colors.grey.shade700,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 10,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: _getGradeColor(item.grade)
                                            .withAlpha(38),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Text(
                                        'Grade: ${item.grade}',
                                        style: TextStyle(
                                          color: _getGradeColor(item.grade),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      'Score: ${item.totalScore.toStringAsFixed(1)} / 100',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    Chip(
                                      label: Text(
                                        item.status
                                            .replaceAll('_', ' ')
                                            .toUpperCase(),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      backgroundColor: _getStatusColor(
                                        item.status,
                                      ),
                                    ),
                                  ],
                                ),
                                if (item.feedback != null &&
                                    item.feedback!.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    item.feedback!,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade800,
                                    ),
                                  ),
                                ],
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
          ),
        ],
      ),
    );
  }
}
