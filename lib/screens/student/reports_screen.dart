import 'package:flutter/material.dart';

import '../../models/notification_models.dart';
import '../../services/report_service.dart';

/// Interface design for the student's internship report.
/// Export to PDF and date-range filters are planned once this layout
/// is reviewed by the team.
class ReportsScreen extends StatefulWidget {
  final ReportDataSource? service;
  const ReportsScreen({super.key, this.service});

  @override
  State<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends State<ReportsScreen> {
  late final ReportDataSource _service;
  late Future<ReportSummary> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? ReportService();
    _future = _service.studentSummary();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _service.studentSummary();
    });
    await _future.catchError((_) => ReportSummary.empty());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('My report')),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<ReportSummary>(
          future: _future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 160),
                  Center(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'Could not load your report. Pull down to retry.',
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              );
            }
            final r = s.data!;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Text('Application summary', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                      'Total',
                      r.totalApplications,
                      Icons.assignment_outlined,
                    ),
                    _StatCard(
                      'Approved',
                      r.approved,
                      Icons.check_circle_outline,
                      color: Colors.green,
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _StatCard(
                      'Pending',
                      r.pending,
                      Icons.hourglass_empty,
                      color: Colors.orange,
                    ),
                    _StatCard(
                      'Rejected',
                      r.rejected,
                      Icons.cancel_outlined,
                      color: Colors.red,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text('Internship progress', style: theme.textTheme.titleMedium),
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Latest progress: ${r.latestProgress}%'),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: r.latestProgress / 100,
                          minHeight: 10,
                        ),
                        const SizedBox(height: 12),
                        Text('${r.documentsUploaded} document(s) uploaded'),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'PDF export is coming once this layout is approved.',
                      ),
                    ),
                  ),
                  icon: const Icon(Icons.picture_as_pdf_outlined),
                  label: const Text('Export as PDF'),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final int value;
  final IconData icon;
  final Color? color;
  const _StatCard(this.label, this.value, this.icon, {this.color});

  @override
  Widget build(BuildContext context) {
    final c = color ?? Theme.of(context).colorScheme.primary;
    return Expanded(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Icon(icon, color: c),
              const SizedBox(height: 8),
              Text('$value', style: Theme.of(context).textTheme.headlineSmall),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
