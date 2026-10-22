import 'package:flutter/material.dart';

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

  static Widget _message(String text) => ListView(
    children: [
      const SizedBox(height: 160),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(text, textAlign: TextAlign.center),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _refresh,
      child: FutureBuilder<List<Application>>(
        future: _future,
        builder: (context, s) {
          if (s.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return _message('Could not load applications. Pull down to retry.');
          }
          final list = s.data!;
          if (list.isEmpty) {
            return _message(
              'No applications yet. Open the Internships tab and apply.',
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
            children: [
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                child: Row(
                  children: [
                    ChoiceChip(
                      label: Text('All (${list.length})'),
                      selected: _selectedFilter == 'all',
                      onSelected: (_) => setState(() => _selectedFilter = 'all'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Pending (${countFor('pending')})'),
                      selected: _selectedFilter == 'pending',
                      onSelected: (_) =>
                          setState(() => _selectedFilter = 'pending'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Approved (${countFor('approved')})'),
                      selected: _selectedFilter == 'approved',
                      onSelected: (_) =>
                          setState(() => _selectedFilter = 'approved'),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: Text('Rejected (${countFor('rejected')})'),
                      selected: _selectedFilter == 'rejected',
                      onSelected: (_) =>
                          setState(() => _selectedFilter = 'rejected'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Text(
                            'No $_selectedFilter applications found.',
                            style: TextStyle(color: Colors.grey.shade700),
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: filtered.length,
                        itemBuilder: (context, i) {
                          final a = filtered[i];
                          return Card(
                            child: ListTile(
                              title: Text(a.internship.title),
                              subtitle: Text(
                                '${a.internship.companyName}\nApplied ${formatDate(a.appliedAt)}',
                              ),
                              isThreeLine: true,
                              trailing: statusChip(a.status),
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => ApplicationDetailScreen(
                                    application: a,
                                    service: widget.documentService,
                                  ),
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
    );
  }
}
