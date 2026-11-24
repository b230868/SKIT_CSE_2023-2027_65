import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/widgets/empty_state_widget.dart';
import '../../models/student_models.dart';
import '../../services/document_progress_service.dart';
import '../../services/student_service.dart';
import 'application_detail_screen.dart';
import 'student_ui.dart';

class ApplicationsScreen extends StatefulWidget {
  final StudentDataSource? service;
  final DocumentProgressDataSource? documentService;
  final String initialFilter;
  const ApplicationsScreen({
    super.key,
    this.service,
    this.documentService,
    this.initialFilter = 'all',
  });

  @override
  State<ApplicationsScreen> createState() => _ApplicationsScreenState();
}

class _ApplicationsScreenState extends State<ApplicationsScreen> {
  late final StudentDataSource _service;
  late Future<List<Application>> _future;
  late String _selectedFilter;

  @override
  void initState() {
    super.initState();
    _selectedFilter = widget.initialFilter;
    _service = widget.service ?? StudentService();
    _future = _service.myApplications();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.myApplications();
    });
    await _future.catchError((_) => <Application>[]);
  }

  @override
  Widget build(BuildContext context) {
    final canPop = ModalRoute.of(context)?.canPop ?? false;

    return Material(
      color: AppTheme.paper,
      child: Scaffold(
        backgroundColor: AppTheme.paper,
        appBar: canPop
            ? AppBar(
                title: const Text('My Applications & Documents'),
                elevation: 0,
              )
            : null,
        body: RefreshIndicator(
          onRefresh: _refresh,
          child: FutureBuilder<List<Application>>(
            future: _future,
            builder: (context, s) {
              if (s.connectionState != ConnectionState.done) {
                return const Center(child: CircularProgressIndicator());
              }
              if (s.hasError) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    EmptyStateWidget(
                      message: 'Could not load applications. Pull down to retry.',
                      icon: Icons.error_outline,
                    ),
                  ],
                );
              }
              final list = s.data ?? [];
              if (list.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    EmptyStateWidget(
                      message:
                          'No applications found.\nBrowse internships from the Internships tab and submit your application.',
                      icon: Icons.work_off_outlined,
                    ),
                  ],
                );
              }

              int countFor(String st) => list
                  .where((a) =>
                      a.status.trim().toLowerCase() == st.trim().toLowerCase())
                  .length;

              final filtered = _selectedFilter == 'all'
                  ? list
                  : list
                      .where((a) =>
                          a.status.trim().toLowerCase() ==
                          _selectedFilter.trim().toLowerCase())
                      .toList();

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: double.infinity,
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Row(
                        children: [
                          _buildFilterChip('all', 'All (${list.length})'),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                              'pending', 'Pending (${countFor('pending')})'),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                              'approved', 'Approved (${countFor('approved')})'),
                          const SizedBox(width: 8),
                          _buildFilterChip(
                              'rejected', 'Rejected (${countFor('rejected')})'),
                        ],
                      ),
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: filtered.isEmpty
                        ? EmptyStateWidget(
                            message: 'No $_selectedFilter applications found.',
                            icon: Icons.filter_alt_off_outlined,
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.all(16),
                            itemCount: filtered.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(height: 12),
                            itemBuilder: (context, i) {
                              final a = filtered[i];
                              return Card(
                                child: InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => ApplicationDetailScreen(
                                        application: a,
                                        service: widget.documentService,
                                      ),
                                    ),
                                  ),
                                  child: Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Row(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 44,
                                          height: 44,
                                          decoration: BoxDecoration(
                                            color: const Color(0xFFEFF6FF),
                                            borderRadius:
                                                BorderRadius.circular(10),
                                            border: Border.all(
                                              color: const Color(0xFFBFDBFE),
                                            ),
                                          ),
                                          child: const Icon(
                                            Icons.business_center_outlined,
                                            color: Color(0xFF1D4ED8),
                                            size: 22,
                                          ),
                                        ),
                                        const SizedBox(width: 14),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                a.internship.title,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w700,
                                                  fontSize: 16,
                                                  color: AppTheme.ink,
                                                ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                a.internship.companyName,
                                                style: const TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppTheme.slateMuted,
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Text(
                                                'Applied: ${formatDate(a.appliedAt)}',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color: Colors.grey.shade600,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            statusChip(a.status),
                                            const SizedBox(height: 8),
                                            const Icon(
                                              Icons.chevron_right,
                                              color: AppTheme.slateMuted,
                                              size: 20,
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
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String filterKey, String label) {
    final isSelected = _selectedFilter == filterKey;
    return FilterChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.ink,
      ),
      selectedColor: AppTheme.ink,
      backgroundColor: Colors.white,
      checkmarkColor: Colors.white,
      side: BorderSide(
        color: isSelected ? AppTheme.ink : AppTheme.slateBorder,
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      onSelected: (_) => setState(() => _selectedFilter = filterKey),
    );
  }
}
