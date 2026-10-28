import 'package:flutter/material.dart';
import 'package:prashikshan/features/auth/models/app_user.dart';
import 'package:prashikshan/features/auth/presentation/profile_screen.dart';

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
  int _currentIndex = 0;
  late AppUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  void _onTabSelected(int index) {
    setState(() {
      _currentIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: [
          IndustryDashboardScreen(onNavigateToTab: _onTabSelected),
          const InternshipManagementScreen(),
          const IndustryAttendanceScreen(),
          const IndustryReportsScreen(),
          ProfileScreen(
            user: _user,
            onUpdated: (u) => setState(() => _user = u),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _onTabSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.business_center_outlined),
            selectedIcon: Icon(Icons.business_center),
            label: 'Internships',
          ),
          NavigationDestination(
            icon: Icon(Icons.fact_check_outlined),
            selectedIcon: Icon(Icons.fact_check),
            label: 'Attendance',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
