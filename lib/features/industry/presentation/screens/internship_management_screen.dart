import 'package:flutter/material.dart';
import 'package:prashikshan/features/industry/data/models/industry_internship_model.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';

import 'industry_internship_details_screen.dart';

class InternshipManagementScreen extends StatefulWidget {
  final IndustryService? service;
  final String? initialFilter;

  const InternshipManagementScreen({
    super.key,
    this.service,
    this.initialFilter,
  });

  @override
  State<InternshipManagementScreen> createState() =>
      _InternshipManagementScreenState();
}

class _InternshipManagementScreenState
    extends State<InternshipManagementScreen> {
  late final IndustryService _industryService;
  late final TextEditingController _searchController;

  bool _loading = true;
  String? _error;
  List<IndustryInternshipModel> _allInternships = [];
  String _selectedFilter = 'all';
  String _sortBy = 'name'; // 'name' | 'progress'

  @override
  void initState() {
    super.initState();
    if (widget.initialFilter != null) {
      _selectedFilter = widget.initialFilter!;
    }
    _industryService = widget.service ?? IndustryService();
    _searchController = TextEditingController();
    _loadInternships();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadInternships() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final list = await _industryService.getIndustryInternships();
      if (!mounted) return;
      setState(() {
        _allInternships = list;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  List<IndustryInternshipModel> get _filteredAndSortedList {
    final query = _searchController.text.trim().toLowerCase();

    var list = _allInternships.where((item) {
      final matchesQuery =
          query.isEmpty ||
          item.studentName.toLowerCase().contains(query) ||
          item.internshipTitle.toLowerCase().contains(query);

      final matchesFilter =
          _selectedFilter == 'all' ||
          item.status.toLowerCase() == _selectedFilter.toLowerCase();

      return matchesQuery && matchesFilter;
    }).toList();

    if (_sortBy == 'progress') {
      list.sort((a, b) => b.progress.compareTo(a.progress));
    } else {
      list.sort(
        (a, b) =>
            a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()),
      );
    }

    return list;
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
        style: const TextStyle(color: Colors.white, fontSize: 11),
      ),
      backgroundColor: _getStatusColor(status),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
    );
  }

  @override
  Widget build(BuildContext context) {
    final displayList = _filteredAndSortedList;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Internship Management'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadInternships,
          ),
        ],
      ),
      body: Column(
        children: [
          // Search & Filter header
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: 'Search by student name or role...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear),
                        onPressed: () {
                          _searchController.clear();
                          setState(() {});
                        },
                      )
                    : null,
              ),
              onChanged: (_) => setState(() {}),
            ),
          ),

          // Filter chips & sort row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Row(
              children: [
                _buildFilterChip('all', 'All (${_allInternships.length})'),
                const SizedBox(width: 8),
                _buildFilterChip('active', 'Active'),
                const SizedBox(width: 8),
                _buildFilterChip('completed', 'Completed'),
                const SizedBox(width: 8),
                _buildFilterChip('planned', 'Planned'),
                const SizedBox(width: 16),
                ActionChip(
                  avatar: Icon(
                    _sortBy == 'progress' ? Icons.sort : Icons.sort_by_alpha,
                    size: 16,
                  ),
                  label: Text(
                    _sortBy == 'progress' ? 'By Progress' : 'By Name',
                  ),
                  onPressed: () {
                    setState(() {
                      _sortBy = _sortBy == 'name' ? 'progress' : 'name';
                    });
                  },
                ),
              ],
            ),
          ),

          // Content body
          Expanded(child: _buildListContent(displayList)),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final selected = _selectedFilter == filterKey;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (val) {
        if (val) {
          setState(() => _selectedFilter = filterKey);
        }
      },
    );
  }

  Widget _buildListContent(List<IndustryInternshipModel> displayList) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Unable to load internships.\n\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadInternships,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    if (displayList.isEmpty) {
      return RefreshIndicator(
        onRefresh: _loadInternships,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(
              child: Text(
                'No internships match the selected criteria.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadInternships,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        itemCount: displayList.length,
        itemBuilder: (context, index) {
          final internship = displayList[index];

          return Card(
            margin: const EdgeInsets.only(bottom: 14),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) =>
                        IndustryInternshipDetailsScreen(internship: internship),
                  ),
                );
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
                            internship.studentName.isNotEmpty
                                ? internship.studentName[0].toUpperCase()
                                : 'S',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                internship.studentName,
                                style: const TextStyle(
                                  fontSize: 17,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                internship.internshipTitle,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const Icon(
                          Icons.arrow_forward_ios,
                          size: 16,
                          color: Colors.grey,
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    LinearProgressIndicator(
                      value: (internship.progress / 100).clamp(0.0, 1.0),
                    ),

                    const SizedBox(height: 6),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Progress: ${internship.progress.toStringAsFixed(0)}%',
                          style: const TextStyle(fontSize: 13),
                        ),
                        Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          children: [
                            _statusChip(internship.status),
                            _statusChip(internship.itrStatus),
                            _statusChip(internship.evaluationStatus),
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
  }
}
