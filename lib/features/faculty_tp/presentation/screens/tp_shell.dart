import 'package:flutter/material.dart';

import '../../../../core/widgets/app_navigation_shell.dart';
import '../../../approval/domain/entities/approval_review_stage.dart';
import '../../../approval/presentation/screens/approval_list_screen.dart';
import '../../../auth/models/app_user.dart';
import '../../../auth/presentation/profile_screen.dart';
import '../../../faculty_reports/presentation/screens/faculty_reports_screen.dart';
import 'company_assignment_screen.dart';
import 'student_monitoring_screen.dart';
import 'tp_dashboard_screen.dart';

class TpShell extends StatefulWidget {
  final AppUser user;

  const TpShell({super.key, required this.user});

  @override
  State<TpShell> createState() => _TpShellState();
}

class _TpShellState extends State<TpShell> {
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
          screen: TpDashboardScreen(),
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
            key: ValueKey('tp-approvals-$_refreshCounter'),
            title: 'T&P Final Approvals',
            stage: ApprovalReviewStage.tpAdmin,
          ),
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check,
          label: 'Approvals',
        ),
        const NavigationShellTab(
          screen: CompanyAssignmentScreen(),
          icon: Icons.business_outlined,
          selectedIcon: Icons.business,
          label: 'Companies',
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
