import 'package:flutter/material.dart';

import '../../data/models/industry_evaluation_model.dart';
import '../../data/services/industry_service.dart';

class IndustryReportsScreen extends StatefulWidget {
  final IndustryService? service;

  const IndustryReportsScreen({super.key, this.service});

  @override
  State<IndustryReportsScreen> createState() => _IndustryReportsScreenState();
}

class _IndustryReportsScreenState extends State<IndustryReportsScreen> {
  late final IndustryService _service;
  IndustryAnalyticsData? _data;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? IndustryService();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _service.getAnalyticsData();
      if (!mounted) return;
      setState(() {
        _data = data;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Unable to load reports.\n\n$_error',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _load,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : _buildReport(_data!),
    );
  }

  Widget _buildReport(IndustryAnalyticsData data) {
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            data.industryName,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _MetricCard(label: 'Total interns', value: data.totalInterns),
              _MetricCard(label: 'Active interns', value: data.activeInterns),
              _MetricCard(
                label: 'Completed internships',
                value: data.completedInternships,
              ),
              _MetricCard(label: 'ITRs pending', value: data.pendingItrs),
              _MetricCard(label: 'ITRs submitted', value: data.submittedItrs),
              _MetricCard(label: 'ITRs approved', value: data.approvedItrs),
              _MetricCard(
                label: 'Evaluations pending',
                value: data.pendingEvaluations,
              ),
              _MetricCard(
                label: 'Evaluations completed',
                value: data.completedEvaluations,
              ),
            ],
          ),
          const SizedBox(height: 24),
          Text('Internship progress', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          ...data.progressBands.entries.map(
            (entry) => ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.key),
              trailing: Text(entry.value.toString()),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            'Internship Status Distribution',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Active'),
            trailing: Text(data.activeInterns.toString()),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Completed'),
            trailing: Text(data.completedInternships.toString()),
          ),
          const SizedBox(height: 16),
          Text('Evaluation results', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 8),
          if (data.averageScore == null || data.gradeDistribution.isEmpty)
            const Text(
              'Evaluation scores and grades are not available in the current '
              'ITR data.',
            )
          else ...[
            Text('Average score: ${data.averageScore!.toStringAsFixed(1)}'),
            ...data.gradeDistribution.entries.map(
              (entry) => ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text('Grade ${entry.key}'),
                trailing: Text(entry.value.toString()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String label;
  final int value;

  const _MetricCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value.toString(),
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(label),
            ],
          ),
        ),
      ),
    );
  }
}
