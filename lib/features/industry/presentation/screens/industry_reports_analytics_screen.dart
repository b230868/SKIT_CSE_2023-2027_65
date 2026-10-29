import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/models/industry_evaluation_model.dart';
import '../../data/services/industry_service.dart';

class IndustryReportsAnalyticsScreen extends StatefulWidget {
  final IndustryService? industryService;

  const IndustryReportsAnalyticsScreen({super.key, this.industryService});

  @override
  State<IndustryReportsAnalyticsScreen> createState() =>
      _IndustryReportsAnalyticsScreenState();
}

class _IndustryReportsAnalyticsScreenState
    extends State<IndustryReportsAnalyticsScreen> {
  late final IndustryService _service;
  late Future<IndustryAnalyticsData> _future;

  @override
  void initState() {
    super.initState();
    _service = widget.industryService ?? IndustryService();
    _loadAnalytics();
  }

  void _loadAnalytics() {
    _future = _service.getAnalyticsData();
  }

  Future<void> _refresh() async {
    setState(_loadAnalytics);
    await _future;
  }

  void _showExportSummaryDialog(IndustryAnalyticsData data) {
    final summary = StringBuffer();
    summary.writeln('=== PRASHIKSHAN INDUSTRY ANALYTICS REPORT ===');
    summary.writeln('Industry Partner: ${data.industryName}');
    summary.writeln('Generated: ${DateTime.now().toLocal()}');
    summary.writeln('');
    summary.writeln('--- INTERNSHIP TOTALS ---');
    summary.writeln('Total Assigned Interns: ${data.totalInterns}');
    summary.writeln('Active Internships: ${data.activeInterns}');
    summary.writeln('Completed Internships: ${data.completedInternships}');
    summary.writeln('');
    summary.writeln('--- ATTENDANCE & EVALUATION METRICS ---');
    summary.writeln('Pending Daily Attendance: ${data.pendingAttendance}');
    summary.writeln(
      'Average Attendance Rate: ${data.attendanceRate.toStringAsFixed(1)}%',
    );
    summary.writeln('Pending Evaluations: ${data.pendingEvaluations}');
    summary.writeln('Completed Evaluations: ${data.completedEvaluations}');
    summary.writeln(
      'Average Evaluation Score: ${data.averageScore.toStringAsFixed(1)} / 100',
    );
    summary.writeln('');
    summary.writeln('--- DOCUMENT VERIFICATION METRICS ---');
    summary.writeln('Offer Letters Issued: ${data.issuedOfferLetters}');
    summary.writeln('Offer Letters Pending: ${data.pendingOfferLetters}');
    summary.writeln('Certificates Issued: ${data.issuedCertificates}');
    summary.writeln('Certificates Pending: ${data.pendingCertificates}');
    summary.writeln('');
    summary.writeln('--- GRADE DISTRIBUTION ---');
    data.gradeDistribution.forEach((k, v) {
      summary.writeln('Grade $k: $v interns');
    });

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Export Analytics Summary'),
        content: SingleChildScrollView(
          child: SelectableText(
            summary.toString(),
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
          FilledButton.icon(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: summary.toString()));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Report copied to clipboard!')),
              );
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy to Clipboard'),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Icon(icon, color: color, size: 22),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Industry Reports & Analytics'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _refresh,
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: FutureBuilder<IndustryAnalyticsData>(
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
                      'Unable to load analytics.',
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

          final data = snapshot.data!;

          return RefreshIndicator(
            onRefresh: _refresh,
            child: ListView(
              padding: const EdgeInsets.all(16),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                // Industry Partner Header Card
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Icon(
                          Icons.analytics,
                          size: 32,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                data.industryName,
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Performance & Progress Intelligence Report',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onPrimaryContainer
                                      .withAlpha(204),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Top KPI Grid
                Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Total Interns',
                        value: data.totalInterns.toString(),
                        icon: Icons.people,
                        color: Colors.indigo,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Active Interns',
                        value: data.activeInterns.toString(),
                        icon: Icons.trending_up,
                        color: Colors.green,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 12),

                Row(
                  children: [
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Average Score',
                        value: (data.averageScore > 0)
                            ? '${data.averageScore.toStringAsFixed(1)} / 100'
                            : 'N/A',
                        icon: Icons.grade,
                        color: Colors.amber.shade800,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _buildKpiCard(
                        title: 'Completed',
                        value: data.completedInternships.toString(),
                        icon: Icons.task_alt,
                        color: Colors.teal,
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // Progress Distribution Chart
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Intern Progress Bands',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Distribution of intern completion percentages',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 24),
                        SizedBox(
                          height: 180,
                          child: BarChart(
                            BarChartData(
                              alignment: BarChartAlignment.spaceAround,
                              maxY: (data.totalInterns > 0
                                  ? data.totalInterns.toDouble() + 1
                                  : 5.0),
                              barTouchData: BarTouchData(enabled: true),
                              titlesData: FlTitlesData(
                                show: true,
                                bottomTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    getTitlesWidget: (val, meta) {
                                      const keys = [
                                        '0-25%',
                                        '26-50%',
                                        '51-75%',
                                        '76-100%',
                                      ];
                                      final index = val.toInt();
                                      if (index >= 0 && index < keys.length) {
                                        return Padding(
                                          padding: const EdgeInsets.only(
                                            top: 8,
                                          ),
                                          child: Text(
                                            keys[index],
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        );
                                      }
                                      return const SizedBox.shrink();
                                    },
                                  ),
                                ),
                                leftTitles: AxisTitles(
                                  sideTitles: SideTitles(
                                    showTitles: true,
                                    reservedSize: 28,
                                    interval: 1,
                                  ),
                                ),
                                topTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                                rightTitles: const AxisTitles(
                                  sideTitles: SideTitles(showTitles: false),
                                ),
                              ),
                              gridData: const FlGridData(show: false),
                              borderData: FlBorderData(show: false),
                              barGroups: [
                                BarChartGroupData(
                                  x: 0,
                                  barRods: [
                                    BarChartRodData(
                                      toY: (data.progressBands['0-25%'] ?? 0)
                                          .toDouble(),
                                      color: Colors.redAccent,
                                      width: 22,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 1,
                                  barRods: [
                                    BarChartRodData(
                                      toY: (data.progressBands['26-50%'] ?? 0)
                                          .toDouble(),
                                      color: Colors.orangeAccent,
                                      width: 22,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 2,
                                  barRods: [
                                    BarChartRodData(
                                      toY: (data.progressBands['51-75%'] ?? 0)
                                          .toDouble(),
                                      color: Colors.blueAccent,
                                      width: 22,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                                BarChartGroupData(
                                  x: 3,
                                  barRods: [
                                    BarChartRodData(
                                      toY: (data.progressBands['76-100%'] ?? 0)
                                          .toDouble(),
                                      color: Colors.green,
                                      width: 22,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                // Company Evaluation & Document Compliance
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Evaluation & Document Status',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Supervisory evaluations and milestone verification progress',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (data.totalInterns == 0)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(24),
                              child: Text(
                                'No internship records available yet.',
                              ),
                            ),
                          )
                        else
                          SizedBox(
                            height: 160,
                            child: PieChart(
                              PieChartData(
                                sectionsSpace: 2,
                                centerSpaceRadius: 36,
                                sections: [
                                  if (data.completedEvaluations > 0)
                                    PieChartSectionData(
                                      value: data.completedEvaluations
                                          .toDouble(),
                                      title: '${data.completedEvaluations}',
                                      color: Colors.teal,
                                      radius: 40,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (data.pendingEvaluations > 0)
                                    PieChartSectionData(
                                      value: data.pendingEvaluations.toDouble(),
                                      title: '${data.pendingEvaluations}',
                                      color: Colors.orange,
                                      radius: 40,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                  if (data.issuedCertificates > 0)
                                    PieChartSectionData(
                                      value: data.issuedCertificates.toDouble(),
                                      title: '${data.issuedCertificates}',
                                      color: Colors.indigo,
                                      radius: 40,
                                      titleStyle: const TextStyle(
                                        color: Colors.white,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 12,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildLegendItem('Evaluated', Colors.teal),
                            _buildLegendItem('Pending Eval', Colors.orange),
                            _buildLegendItem('Certificates', Colors.indigo),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Export Button
                FilledButton.icon(
                  onPressed: () => _showExportSummaryDialog(data),
                  icon: const Icon(Icons.file_download_outlined),
                  label: const Text('Export Analytics Summary'),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLegendItem(String label, Color color) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12)),
      ],
    );
  }
}
