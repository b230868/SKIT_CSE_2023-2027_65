import 'package:flutter/material.dart';

import 'package:prashikshan/features/industry/data/models/industry_dashboard_data.dart';
import 'package:prashikshan/features/industry/data/models/industry_internship_model.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';

import 'industry_attendance_screen.dart';
import 'industry_internship_details_screen.dart';
import 'internship_management_screen.dart';

class IndustryDashboardScreen extends StatefulWidget {
  final IndustryService? service;
  final ValueChanged<int>? onNavigateToTab;

  const IndustryDashboardScreen({
    super.key,
    this.service,
    this.onNavigateToTab,
  });

  @override
  State<IndustryDashboardScreen> createState() =>
      _IndustryDashboardScreenState();
}

class _IndustryDashboardScreenState extends State<IndustryDashboardScreen> {
  late final IndustryService _service;

  bool _loading = true;
  String? _error;
  IndustryDashboardData? _dashboardData;
  List<IndustryInternshipModel> _internships = [];

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? IndustryService();
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getDashboardData(),
        _service.getIndustryInternships(),
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

  void _navigateToTabOrScreen(int tabIndex, Widget screen) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(tabIndex);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Industry Dashboard'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
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
                'Unable to load dashboard.\n\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadData,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _dashboardData ?? IndustryDashboardData.empty();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Industry Company Header Banner
          Card(
            color: const Color(0xFF14213D),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFE09F1F),
                    child: Text(
                      data.industryName.isNotEmpty
                          ? data.industryName[0].toUpperCase()
                          : 'I',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.industryName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Company Supervisor Portal',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (data.industryName.isEmpty ||
              data.industryName.toLowerCase().contains('unassigned') ||
              data.industryName.toLowerCase().contains('unverified')) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade900,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Assignment Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No verified company association is linked to your supervisor account. Intern records, attendance tracking, and evaluations remain restricted until an administrator assigns your company.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Primary KPI Stat Cards Row 1: Total Interns & Active Interns
          Row(
            children: [
              Expanded(
                child: _DashboardCard(
                  title: 'Total Assigned',
                  value: data.totalInterns.toString(),
                  icon: Icons.groups_outlined,
                  color: Colors.blueGrey,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InternshipManagementScreen(
                        service: _service,
                        initialFilter: 'all',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardCard(
                  title: 'Active Interns',
                  value: data.activeInterns.toString(),
                  icon: Icons.people,
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InternshipManagementScreen(
                        service: _service,
                        initialFilter: 'active',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // KPI Stat Cards Row 2: Attendance Pending & Evaluations Due
          Row(
            children: [
              Expanded(
                child: _DashboardCard(
                  title: 'Attendance Pending',
                  value: data.pendingAttendance.toString(),
                  icon: Icons.fact_check_outlined,
                  color: Colors.orange,
                  onTap: () => _navigateToTabOrScreen(
                    2,
                    IndustryAttendanceScreen(service: _service),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardCard(
                  title: 'Evaluations Due',
                  value: data.pendingEvaluations.toString(),
                  icon: Icons.assignment_turned_in,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InternshipManagementScreen(
                        service: _service,
                        initialFilter: 'pending_eval',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // KPI Stat Cards Row 3: Certificates Pending & Completed
          Row(
            children: [
              Expanded(
                child: _DashboardCard(
                  title: 'Certificates Pending',
                  value: data.pendingCertificates.toString(),
                  icon: Icons.workspace_premium_outlined,
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InternshipManagementScreen(
                        service: _service,
                        initialFilter: 'completed',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardCard(
                  title: 'Completed',
                  value: data.completedInternships.toString(),
                  icon: Icons.check_circle,
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InternshipManagementScreen(
                        service: _service,
                        initialFilter: 'completed',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Recent Interns Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assigned Interns',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => _navigateToTabOrScreen(
                  1,
                  InternshipManagementScreen(service: _service),
                ),
                child: const Text('View All'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (_internships.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No active internships found.')),
              ),
            )
          else
            ..._internships
                .take(4)
                .map(
                  (internship) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          internship.studentName.isNotEmpty
                              ? internship.studentName[0].toUpperCase()
                              : 'S',
                        ),
                      ),
                      title: Text(
                        internship.studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${internship.internshipTitle} • Progress: ${internship.progress.toStringAsFixed(0)}%',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IndustryInternshipDetailsScreen(
                              internship: internship,
                              industryService: _service,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
