import 'package:flutter/material.dart';

import '../../../../core/widgets/app_navigation_shell.dart';
import '../../../auth/models/app_user.dart';
import '../../../auth/presentation/profile_screen.dart';
import 'industry_attendance_screen.dart';
import 'industry_dashboard_screen.dart';
import 'industry_reports_screen.dart';
import 'internship_management_screen.dart';

/// Navigation shell for Industry partners and supervisors:
/// Dashboard | Internships | Attendance | Reports | Profile
class IndustryShell extends StatefulWidget {
  final AppUser user;

  const IndustryShell({super.key, required this.user});

  @override
  State<IndustryShell> createState() => _IndustryShellState();
}

class _IndustryShellState extends State<IndustryShell> {
  late AppUser _user;

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
          screen: IndustryDashboardScreen(),
          icon: Icons.dashboard_outlined,
          selectedIcon: Icons.dashboard,
          label: 'Dashboard',
        ),
        const NavigationShellTab(
          screen: InternshipManagementScreen(),
          icon: Icons.business_center_outlined,
          selectedIcon: Icons.business_center,
          label: 'Internships',
        ),
        const NavigationShellTab(
          screen: IndustryAttendanceScreen(),
          icon: Icons.fact_check_outlined,
          selectedIcon: Icons.fact_check,
          label: 'Attendance',
        ),
        const NavigationShellTab(
          screen: IndustryReportsScreen(),
          icon: Icons.bar_chart_outlined,
          selectedIcon: Icons.bar_chart,
          label: 'Reports',
        ),
        NavigationShellTab(
          screen: ProfileScreen(
            user: _user,
            onUpdated: (u) => setState(() => _user = u),
          ),
          icon: Icons.person_outline,
          selectedIcon: Icons.person,
          label: 'Profile',
        ),
      ],
    );
  }
}
