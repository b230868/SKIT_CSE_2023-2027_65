import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/theme.dart';
import '../../../../screens/student/notification_screen.dart';
import '../../../approval/domain/entities/approval_review_stage.dart';
import '../../../approval/domain/entities/approval_status.dart';
import '../../../approval/presentation/screens/approval_list_screen.dart';
import '../../../approval/presentation/screens/tp_approval_dashboard_screen.dart';
import '../../../faculty_reports/presentation/screens/faculty_reports_screen.dart';
import '../../../placement/data/models/placement_models.dart';
import '../../../placement/data/services/placement_repository_provider.dart';
import '../../../placement/presentation/screens/tp_noc_management_screen.dart';
import '../../../placement/presentation/screens/tp_notice_editor_screen.dart';
import '../../../placement/presentation/screens/tp_notices_screen.dart';
import '../../../placement/presentation/screens/tp_queries_faqs_screen.dart';
import '../../data/models/dashboard_stat_item.dart';
import '../../data/repositories/faculty_dashboard_repository_factory.dart';
import '../../data/services/faculty_dashboard_service.dart';
import '../../domain/entities/dashboard_statistics.dart';
import '../widgets/dashboard_action_button.dart';
import '../widgets/dashboard_stat_card.dart';
import 'company_assignment_screen.dart';
import 'faculty_dashboard_screen.dart';
import 'student_monitoring_screen.dart';

class TpDashboardScreen extends StatefulWidget {
  const TpDashboardScreen({super.key});

  @override
  State<TpDashboardScreen> createState() => _TpDashboardScreenState();
}

class _TpDashboardScreenState extends State<TpDashboardScreen> {
  late final FacultyDashboardService _service;
  final _placementRepo = PlacementRepositoryProvider.instance;

  DashboardStatistics? _statistics;
  TpPlacementSummary _placementSummary = const TpPlacementSummary();
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
      final statistics = await _service.loadStatistics(
        stage: ApprovalReviewStage.tpAdmin,
      );

      TpPlacementSummary summary = const TpPlacementSummary();
      try {
        summary = await _placementRepo.getDashboardSummary();
      } catch (_) {}

      if (!mounted) return;

      setState(() {
        _statistics = statistics;
        _placementSummary = summary;
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
        message =
            'Your account does not have permission to access dashboard data.';
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
                MaterialPageRoute(builder: (_) => const FacultyReportsScreen()),
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
          const NotificationBell(),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
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
      return const Center(child: Text('No dashboard data available'));
    }

    final placementItems = [
      DashboardStatItem(
        title: 'Active Opportunities',
        value: _placementSummary.activeOpportunities,
        icon: Icons.campaign_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TpNoticesScreen(initialStatusFilter: 'open'),
            ),
          ).then((_) => _loadDashboard());
        },
      ),
      DashboardStatItem(
        title: 'New Notices',
        value: _placementSummary.newNotices,
        icon: Icons.fiber_new_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TpNoticesScreen()),
          ).then((_) => _loadDashboard());
        },
      ),
      DashboardStatItem(
        title: 'Upcoming Drives',
        value: _placementSummary.upcomingDrives,
        icon: Icons.event_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const TpNoticesScreen(initialStatusFilter: 'upcoming'),
            ),
          ).then((_) => _loadDashboard());
        },
      ),
      DashboardStatItem(
        title: 'Closing Soon',
        value: _placementSummary.closingSoon,
        icon: Icons.timer_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) =>
                  const TpNoticesScreen(initialStatusFilter: 'closing_soon'),
            ),
          ).then((_) => _loadDashboard());
        },
      ),
      DashboardStatItem(
        title: 'Pending NOC Requests',
        value: _placementSummary.pendingNocRequests,
        icon: Icons.assignment_turned_in_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => const TpNocManagementScreen()),
          ).then((_) => _loadDashboard());
        },
      ),
      DashboardStatItem(
        title: 'Unanswered Queries',
        value: _placementSummary.unansweredQueries,
        icon: Icons.question_answer_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TpQueriesFaqsScreen(initialTabIndex: 0),
            ),
          ).then((_) => _loadDashboard());
        },
      ),
      DashboardStatItem(
        title: 'FAQs',
        value: _placementSummary.activeFaqs,
        icon: Icons.quiz_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const TpQueriesFaqsScreen(initialTabIndex: 1),
            ),
          ).then((_) => _loadDashboard());
        },
      ),
    ];

    final approvalItems = [
      DashboardStatItem(
        title: 'Pending Approvals',
        value: statistics.pendingApprovals,
        icon: Icons.pending_actions,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ApprovalListScreen(
                title: 'Pending Approvals (T&P)',
                stage: ApprovalReviewStage.tpAdmin,
                initialStatus: ApprovalStatus.pending,
              ),
            ),
          ).then((_) => _loadDashboard());
        },
      ),
      DashboardStatItem(
        title: 'Approved Internships',
        value: statistics.approvedInternships,
        icon: Icons.check_circle_outline,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ApprovalListScreen(
                title: 'Approved Internships (T&P)',
                stage: ApprovalReviewStage.tpAdmin,
                initialStatus: ApprovalStatus.approved,
              ),
            ),
          ).then((_) => _loadDashboard());
        },
      ),
      DashboardStatItem(
        title: 'Rejected Applications',
        value: statistics.rejectedApplications,
        icon: Icons.cancel_outlined,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const ApprovalListScreen(
                title: 'Rejected Applications (T&P)',
                stage: ApprovalReviewStage.tpAdmin,
                initialStatus: ApprovalStatus.rejected,
              ),
            ),
          ).then((_) => _loadDashboard());
        },
      ),
      DashboardStatItem(
        title: 'Students Requiring Review',
        value: statistics.studentsRequiringReview,
        icon: Icons.person_search,
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const StudentMonitoringScreen(
                initialPendingApprovalsOnly: true,
              ),
            ),
          ).then((_) => _loadDashboard());
        },
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 900
            ? 4
            : constraints.maxWidth >= 600
                ? 2
                : 2;

        return RefreshIndicator(
          onRefresh: _loadDashboard,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Fast-Action Hero Strip
              Card(
                color: AppTheme.ink,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Row(
                    children: [
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Placement & Communication',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            SizedBox(height: 4),
                            Text(
                              'Forward company notices, target branches, resolve student queries & review NOCs.',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      FilledButton.icon(
                        style: FilledButton.styleFrom(
                          backgroundColor: AppTheme.saffron,
                          foregroundColor: AppTheme.ink,
                          minimumSize: const Size(140, 44),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const TpNoticeEditorScreen(),
                            ),
                          ).then((_) => _loadDashboard());
                        },
                        icon: const Icon(Icons.bolt),
                        label: const Text('Publish Notice'),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              Text(
                'Placements & Communication',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: constraints.maxWidth >= 600 ? 1.7 : 1.35,
                children: placementItems
                    .map(
                      (item) => DashboardStatCard(
                        title: item.title,
                        value: item.value,
                        onTap: item.onTap,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 20),

              Text(
                'Quick Actions',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  DashboardActionButton(
                    label: 'Publish Notice',
                    icon: Icons.add_alert_outlined,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TpNoticeEditorScreen(),
                        ),
                      ).then((_) => _loadDashboard());
                    },
                  ),
                  DashboardActionButton(
                    label: 'View Opportunities',
                    icon: Icons.campaign_outlined,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TpNoticesScreen(),
                        ),
                      ).then((_) => _loadDashboard());
                    },
                  ),
                  DashboardActionButton(
                    label: 'View Queries (${_placementSummary.unansweredQueries})',
                    icon: Icons.question_answer_outlined,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const TpQueriesFaqsScreen(initialTabIndex: 0),
                        ),
                      ).then((_) => _loadDashboard());
                    },
                  ),
                  DashboardActionButton(
                    label: 'Manage NOC (${_placementSummary.pendingNocRequests})',
                    icon: Icons.assignment_turned_in_outlined,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TpNocManagementScreen(),
                        ),
                      ).then((_) => _loadDashboard());
                    },
                  ),
                  DashboardActionButton(
                    label: 'Manage FAQs',
                    icon: Icons.quiz_outlined,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              const TpQueriesFaqsScreen(initialTabIndex: 1),
                        ),
                      ).then((_) => _loadDashboard());
                    },
                  ),
                  DashboardActionButton(
                    label: 'View Approvals',
                    icon: Icons.assignment_outlined,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const TpApprovalDashboardScreen(),
                        ),
                      ).then((_) => _loadDashboard());
                    },
                  ),
                  DashboardActionButton(
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
                  DashboardActionButton(
                    label: 'Companies',
                    icon: Icons.business_outlined,
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const CompanyAssignmentScreen(),
                        ),
                      );
                    },
                  ),
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
              const SizedBox(height: 24),

              Text(
                'Internship Approvals Overview',
                style: Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: EdgeInsets.zero,
                crossAxisCount: crossAxisCount,
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: constraints.maxWidth >= 600 ? 1.7 : 1.35,
                children: approvalItems
                    .map(
                      (item) => DashboardStatCard(
                        title: item.title,
                        value: item.value,
                        onTap: item.onTap,
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 24),
            ],
          ),
        );
      },
    );
  }
}
