import 'package:flutter/material.dart';

import '../../../../core/widgets/app_navigation_shell.dart';
import '../../../approval/domain/entities/approval_review_stage.dart';
import '../../../approval/presentation/screens/approval_list_screen.dart';
import '../../../auth/models/app_user.dart';
import '../../../auth/presentation/profile_screen.dart';
import '../../../faculty_reports/presentation/screens/faculty_reports_screen.dart';
import 'faculty_dashboard_screen.dart';
import 'student_monitoring_screen.dart';

class FacultyShell extends StatefulWidget {
  final AppUser user;

  const FacultyShell({super.key, required this.user});

  @override
  State<FacultyShell> createState() => _FacultyShellState();
}

class _FacultyShellState extends State<FacultyShell> {
  late AppUser _user;
  int _refreshCounter = 0;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    return AppNavigationShell(
      tabs: [
        const NavigationShellTab(
          screen: FacultyDashboardScreen(),
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Dashboard',
        ),
        const NavigationShellTab(
          screen: StudentMonitoringScreen(),
          icon: Icons.people_outline,
          selectedIcon: Icons.people,
          label: 'Monitoring',
        ),
        NavigationShellTab(
          screen: ApprovalListScreen(
            key: ValueKey('faculty-approvals-$_refreshCounter'),
            title: 'Faculty Approvals',
            stage: ApprovalReviewStage.faculty,
          ),
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check,
          label: 'Approvals',
        ),
        const NavigationShellTab(
          screen: FacultyReportsScreen(),
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          label: 'Reports',
        ),
        NavigationShellTab(
          screen: ProfileScreen(
            user: _user,
            onUpdated: (u) => setState(() {
              _user = u;
              _refreshCounter++;
            }),
          ),
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profile',
        ),
      ],
    );
  }
}
