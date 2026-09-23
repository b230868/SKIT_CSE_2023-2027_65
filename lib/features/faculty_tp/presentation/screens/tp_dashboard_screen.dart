import '../../../approval/presentation/screens/tp_approval_dashboard_screen.dart';
import '../../../faculty_reports/presentation/screens/faculty_reports_screen.dart';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import 'faculty_dashboard_screen.dart';
import 'student_monitoring_screen.dart';
import '../../data/models/dashboard_stat_item.dart';
import '../../data/repositories/faculty_dashboard_repository_factory.dart';
import '../../data/services/faculty_dashboard_service.dart';
import '../../domain/entities/dashboard_statistics.dart';
import '../widgets/dashboard_action_button.dart';
import '../widgets/dashboard_stat_card.dart';

class TpDashboardScreen extends StatefulWidget {
  const TpDashboardScreen({super.key});

  @override
  State<TpDashboardScreen> createState() => _TpDashboardScreenState();
}

class _TpDashboardScreenState extends State<TpDashboardScreen> {
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
    } catch (e) {
      if (!mounted) return;

      final String message;
      if (e is UnauthenticatedException) {
        message = 'Please sign in to access dashboard data.';
      } else if (e is UnauthorizedException ||
          (e is PostgrestException && e.code == '42501') ||
          e.toString().toLowerCase().contains('permission denied')) {
        message = 'Your account does not have permission to access dashboard data.';
      } else {
        message = 'Unable to load T&P dashboard';
      }

      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('T&P Dashboard'),
        actions: [
          IconButton(
            onPressed: () => AuthService.showAuthDialog(
              context,
              onSessionChanged: _loadDashboard,
            ),
            icon: Icon(
              AuthService.hasActiveSession
                  ? Icons.account_circle
                  : Icons.account_circle_outlined,
            ),
            tooltip: AuthService.hasActiveSession ? 'Account' : 'Sign In',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FacultyReportsScreen(),
                ),
              );
            },
            icon: const Icon(Icons.bar_chart),
            tooltip: 'Reports & Analytics',
          ),
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => const FacultyDashboardScreen(),
                ),
              );
            },
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Switch to Faculty Dashboard',
          ),
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
        child: CircularProgressIndicator(),
      );
    }

    final error = _error;

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                error,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _loadDashboard,
                  child: const Text('Retry'),
                ),
                if (error.contains('sign in')) ...[
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => AuthService.showAuthDialog(
                      context,
                      onSessionChanged: _loadDashboard,
                    ),
                    child: const Text('Sign In'),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    final statistics = _statistics;

    if (statistics == null) {
      return const Center(
        child: Text('No dashboard data available'),
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
                'T&P Overview',
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
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const TpApprovalDashboardScreen(),
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

              const SizedBox(height: 12),

              DashboardActionButton(
                label: 'Reports & Analytics',
                icon: Icons.bar_chart,
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FacultyReportsScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

