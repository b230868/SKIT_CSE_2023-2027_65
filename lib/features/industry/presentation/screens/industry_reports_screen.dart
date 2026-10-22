
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'package:prashikshan/features/industry/data/models/industry_dashboard_data.dart';
import 'package:prashikshan/features/industry/data/models/industry_internship_model.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';

import 'industry_reports_analytics_screen.dart';

class IndustryReportsScreen extends StatefulWidget {
  final IndustryService? industryService;
  final IndustryService? service;

  const IndustryReportsScreen({
    super.key,
    this.industryService,
    this.service,
  });

  @override
  State<IndustryReportsScreen> createState() => _IndustryReportsScreenState();
}

class _IndustryReportsScreenState extends State<IndustryReportsScreen> {
  late final IndustryService _industryService;

  bool _loading = true;
  String? _error;

  IndustryDashboardData? _dashboardData;
  List<IndustryInternshipModel> _internships = [];

  String _selectedStatusFilter = 'all';

  @override
  void initState() {
    super.initState();
    _industryService =
        widget.industryService ?? widget.service ?? IndustryService();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _industryService.getDashboardData(),
        _industryService.getIndustryInternships(),
      ]);

      if (!mounted) return;

      setState(() {
        _dashboardData = results[0] as IndustryDashboardData;
        _internships = results[1] as List<IndustryInternshipModel>;
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

  List<IndustryInternshipModel> get _filteredInternships {
    if (_selectedStatusFilter == 'all') return _internships;
    return _internships
        .where(
          (i) => i.status.toLowerCase() == _selectedStatusFilter.toLowerCase(),
        )
        .toList();
  }

  void _exportReportSummary() {
    final buffer = StringBuffer();
    buffer.writeln('=== PRASHIKSHAN INDUSTRY INTERNSHIP REPORT ===');
    buffer.writeln('Generated on: ${DateTime.now().toLocal()}');
    buffer.writeln(
      'Organization: ${_dashboardData?.industryName ?? 'Industry Partner'}',
    );
    buffer.writeln('--------------------------------------------------');
    buffer.writeln(
      'Total Interns Enrolled: ${_dashboardData?.totalInterns ?? 0}',
    );
    buffer.writeln('Active Internships: ${_dashboardData?.activeInterns ?? 0}');
    buffer.writeln(
      'Completed Internships: ${_dashboardData?.completedInternships ?? 0}',
    );
    buffer.writeln(
      'Pending Daily Attendance: ${_dashboardData?.pendingAttendance ?? 0}',
    );
    buffer.writeln(
      'Evaluations Completed: ${_dashboardData?.completedEvaluations ?? 0}',
    );
    buffer.writeln(
      'Evaluations Pending: ${_dashboardData?.pendingEvaluations ?? 0}',
    );
    buffer.writeln(
      'Offer Letters Issued: ${_dashboardData?.issuedOfferLetters ?? 0}',
    );
    buffer.writeln(
      'Certificates Issued: ${_dashboardData?.issuedCertificates ?? 0}',
    );
    buffer.writeln(
      'Completion Rate: ${_dashboardData?.completionRate.toStringAsFixed(1) ?? '0.0'}%',
    );
    buffer.writeln('--------------------------------------------------');
    buffer.writeln('INTERN RECORDS (${_filteredInternships.length}):');
    for (final intern in _filteredInternships) {
      buffer.writeln(
        '- ${intern.studentName} | ${intern.internshipTitle} | Status: ${intern.status} | Progress: ${intern.progress.toStringAsFixed(0)}% | Eval: ${intern.evaluationStatus} | Attendance: ${intern.attendanceRate?.toStringAsFixed(0) ?? "N/A"}%',
      );
    }
    buffer.writeln('==================================================');

    Clipboard.setData(ClipboardData(text: buffer.toString()));
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Comprehensive report summary copied to clipboard!'),
        backgroundColor: Colors.green,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.insights_outlined),
            tooltip: 'Detailed Analytics & Grade Bands',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => IndustryReportsAnalyticsScreen(
                    industryService: _industryService,
                  ),
                ),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.share),
            tooltip: 'Copy Report Summary',
            onPressed: _loading || _dashboardData == null
                ? null
                : _exportReportSummary,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
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
                'Unable to load analytics.\n\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadReportData,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _dashboardData ?? IndustryDashboardData.empty();

    return RefreshIndicator(
      onRefresh: _loadReportData,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header summary card
          Card(
            color: const Color(0xFF14213D),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          data.industryName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFE09F1F),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${data.completionRate.toStringAsFixed(0)}% Completed',
                          style: const TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Internship Cohort Performance & Compliance Overview',
                    style: TextStyle(color: Colors.white70, fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Key metric grids
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Total Interns',
                  value: data.totalInterns.toString(),
                  icon: Icons.groups,
                  color: Colors.indigo,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Active Now',
                  value: data.activeInterns.toString(),
                  icon: Icons.trending_up,
                  color: Colors.teal,
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  label: 'Attendance Pending',
                  value: '${data.pendingAttendance}/${data.activeInterns}',
                  icon: Icons.fact_check_outlined,
                  color: Colors.orange,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MetricTile(
                  label: 'Evaluations',
                  value: '${data.completedEvaluations}/${data.totalInterns}',
                  icon: Icons.verified,
                  color: Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Visual Chart: Status Distribution
          const Text(
            'Internship Status Distribution',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: data.totalInterns == 0
                  ? const Center(
                      child: Padding(
                        padding: EdgeInsets.all(20),
                        child: Text('No internship data to chart.'),
                      ),
                    )
                  : Column(
                      children: [
                        SizedBox(
                          height: 180,
                          child: PieChart(
                            PieChartData(
                              sectionsSpace: 3,
                              centerSpaceRadius: 40,
                              sections: [
                                PieChartSectionData(
                                  value: data.activeInterns.toDouble(),
                                  title: '${data.activeInterns}',
                                  color: Colors.teal,
                                  radius: 40,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                PieChartSectionData(
                                  value: data.completedInternships.toDouble(),
                                  title: '${data.completedInternships}',
                                  color: Colors.green,
                                  radius: 40,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                PieChartSectionData(
                                  value:
                                      (data.totalInterns -
                                              data.activeInterns -
                                              data.completedInternships)
                                          .clamp(0, 999)
                                          .toDouble(),
                                  title:
                                      '${(data.totalInterns - data.activeInterns - data.completedInternships).clamp(0, 999)}',
                                  color: Colors.orange,
                                  radius: 40,
                                  titleStyle: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _LegendIndicator(
                              color: Colors.teal,
                              text: 'Active',
                            ),
                            _LegendIndicator(
                              color: Colors.green,
                              text: 'Completed',
                            ),
                            _LegendIndicator(
                              color: Colors.orange,
                              text: 'Planned / Other',
                            ),
                          ],
                        ),
                      ],
                    ),
            ),
          ),

          const SizedBox(height: 24),

          // Filter bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Internship Cohort List',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              DropdownButton<String>(
                value: _selectedStatusFilter,
                underline: const SizedBox(),
                items: const [
                  DropdownMenuItem(value: 'all', child: Text('All Statuses')),
                  DropdownMenuItem(value: 'active', child: Text('Active')),
                  DropdownMenuItem(
                    value: 'completed',
                    child: Text('Completed'),
                  ),
                  DropdownMenuItem(value: 'planned', child: Text('Planned')),
                ],
                onChanged: (val) {
                  if (val != null) {
                    setState(() => _selectedStatusFilter = val);
                  }
                },
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (_filteredInternships.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(
                  child: Text('No internships match the selected filter.'),
                ),
              ),
            )
          else
            ..._filteredInternships.map(
              (item) => Card(
                margin: const EdgeInsets.only(bottom: 10),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: item.status == 'completed'
                        ? Colors.green.shade100
                        : Colors.blue.shade100,
                    child: Icon(
                      item.status == 'completed' ? Icons.check : Icons.person,
                      color: item.status == 'completed'
                          ? Colors.green.shade800
                          : Colors.blue.shade800,
                    ),
                  ),
                  title: Text(
                    item.studentName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    '${item.internshipTitle}\nEval: ${item.evaluationStatus.toUpperCase()} | Attendance: ${item.attendanceRate?.toStringAsFixed(0) ?? "N/A"}%',
                  ),
                  isThreeLine: true,
                  trailing: Text(
                    '${item.progress.toStringAsFixed(0)}%',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _MetricTile({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: color.withAlpha(30),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    label,
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LegendIndicator extends StatelessWidget {
  final Color color;
  final String text;

  const _LegendIndicator({required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
