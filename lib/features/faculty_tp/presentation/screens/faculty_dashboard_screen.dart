
import 'package:flutter/material.dart';
import 'student_monitoring_screen.dart';
import '../../data/models/dashboard_stat_item.dart';
import '../../data/repositories/faculty_dashboard_repository_factory.dart';
import '../../data/services/faculty_dashboard_service.dart';
import '../../domain/entities/dashboard_statistics.dart';
import '../widgets/dashboard_stat_card.dart';
import '../widgets/dashboard_action_button.dart';
class FacultyDashboardScreen extends StatefulWidget {
  const FacultyDashboardScreen({super.key});

  @override
  State<FacultyDashboardScreen> createState() =>
      _FacultyDashboardScreenState();
}

class _FacultyDashboardScreenState extends State<FacultyDashboardScreen> {
  late final FacultyDashboardService _service;

  DashboardStatistics? _statistics;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _service = FacultyDashboardService(
      repository: FacultyDashboardRepositoryFactory.create(),
    );

    _loadDashboard();
  }

  Future<void> _loadDashboard() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _error = null;
      });
    }

    try {
      final statistics = await _service.loadStatistics();

      if (!mounted) return;

      setState(() {
        _statistics = statistics;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load dashboard';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty & T&P Dashboard'),
        actions: [
          IconButton(
            onPressed: _loadDashboard,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading dashboard...'),
          ],
        ),
      );
    }

    final error = _error;

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(error),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboard,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final statistics = _statistics;

    if (statistics == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('No dashboard data available'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadDashboard,
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    final statItems = [
      DashboardStatItem(
        title: 'Pending Approvals',
        value: statistics.pendingApprovals,
        icon: Icons.pending_actions,
      ),
      DashboardStatItem(
        title: 'Approved Internships',
        value: statistics.approvedInternships,
        icon: Icons.check_circle_outline,
      ),
      DashboardStatItem(
        title: 'Rejected Applications',
        value: statistics.rejectedApplications,
        icon: Icons.cancel_outlined,
      ),
      DashboardStatItem(
        title: 'Students Requiring Review',
        value: statistics.studentsRequiringReview,
        icon: Icons.person_search,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
                ? 2
                : 1;

        return RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Overview',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 16),

              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.6,
                children: statItems
                    .map(
                      (item) => DashboardStatCard(
                        title: item.title,
                        value: item.value,
                      ),
                    )
                    .toList(),
              ),

              const SizedBox(height: 24),

              Text(
                'Quick Actions',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),

              const SizedBox(height: 12),

              Row(
                children: [
                 Expanded(
  child: DashboardActionButton(
    label: 'View Approvals',
    icon: Icons.assignment_outlined,
    onPressed: () {
      ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Approval list will be available soon.'),
        ),
    );
    },
  ),
),
const SizedBox(width: 12),
Expanded(
  child: DashboardActionButton(
    label: 'Student Monitoring',
    icon: Icons.people_outline,
    onPressed: () {
       Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => const StudentMonitoringScreen(),
      ),
    );
    },
  ),
),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

