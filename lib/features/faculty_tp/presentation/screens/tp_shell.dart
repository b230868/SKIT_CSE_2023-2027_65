import 'package:flutter/material.dart';

import '../../../auth/models/app_user.dart';
import '../../../auth/presentation/profile_screen.dart';
import '../../../faculty_reports/presentation/screens/faculty_reports_screen.dart';
import '../../../placement/presentation/screens/tp_noc_and_approvals_screen.dart';
import '../../../placement/presentation/screens/tp_notices_screen.dart';
import '../../../placement/presentation/screens/tp_queries_faqs_screen.dart';
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
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.sizeOf(context).width >= 800;

    final wideScreens = [
      const TpDashboardScreen(),
      const TpNoticesScreen(),
      const TpQueriesFaqsScreen(),
      const TpNocAndApprovalsScreen(),
      const StudentMonitoringScreen(),
      const CompanyAssignmentScreen(),
      const FacultyReportsScreen(),
      ProfileScreen(
        user: _user,
        onUpdated: (u) => setState(() => _user = u),
      ),
    ];

    const wideDestinations = [
      (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
      (Icons.campaign_outlined, Icons.campaign, 'Notices'),
      (Icons.question_answer_outlined, Icons.question_answer, 'Queries'),
      (Icons.fact_check_outlined, Icons.fact_check, 'NOC & Approvals'),
      (Icons.people_outline, Icons.people, 'Monitoring'),
      (Icons.business_outlined, Icons.business, 'Companies'),
      (Icons.bar_chart_outlined, Icons.bar_chart, 'Reports'),
      (Icons.person_outline, Icons.person, 'Profile'),
    ];

    final mobileScreens = [
      const TpDashboardScreen(),
      const TpNoticesScreen(),
      const TpQueriesFaqsScreen(),
      const TpNocAndApprovalsScreen(),
      _TpMoreScreen(
        user: _user,
        onUserUpdated: (u) => setState(() => _user = u),
      ),
    ];

    const mobileDestinations = [
      (Icons.dashboard_outlined, Icons.dashboard, 'Dashboard'),
      (Icons.campaign_outlined, Icons.campaign, 'Notices'),
      (Icons.question_answer_outlined, Icons.question_answer, 'Queries'),
      (Icons.fact_check_outlined, Icons.fact_check, 'NOC & Approvals'),
      (Icons.apps_outlined, Icons.apps, 'More'),
    ];

    if (isWide) {
      final idx = _currentIndex.clamp(0, wideScreens.length - 1);
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: idx,
              onDestinationSelected: (i) => setState(() => _currentIndex = i),
              labelType: NavigationRailLabelType.all,
              destinations: wideDestinations
                  .map(
                    (d) => NavigationRailDestination(
                      icon: Icon(d.$1),
                      selectedIcon: Icon(d.$2),
                      label: Text(d.$3),
                    ),
                  )
                  .toList(),
            ),
            const VerticalDivider(width: 1, thickness: 1),
            Expanded(
              child: IndexedStack(index: idx, children: wideScreens),
            ),
          ],
        ),
      );
    }

    final mobileIdx = _currentIndex.clamp(0, mobileScreens.length - 1);
    return Scaffold(
      body: IndexedStack(index: mobileIdx, children: mobileScreens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: mobileIdx,
        onDestinationSelected: (i) => setState(() => _currentIndex = i),
        destinations: mobileDestinations
            .map(
              (d) => NavigationDestination(
                icon: Icon(d.$1),
                selectedIcon: Icon(d.$2),
                label: d.$3,
              ),
            )
            .toList(),
      ),
    );
  }
}

class _TpMoreScreen extends StatelessWidget {
  final AppUser user;
  final ValueChanged<AppUser> onUserUpdated;

  const _TpMoreScreen({required this.user, required this.onUserUpdated});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('T&P Workspace')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.people_outline),
                  title: const Text('Student Monitoring'),
                  subtitle: const Text('Track internships, ITRs & student documents'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StudentMonitoringScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.business_outlined),
                  title: const Text('Companies & Supervisors'),
                  subtitle: const Text('Manage verified partner companies'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CompanyAssignmentScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.bar_chart_outlined),
                  title: const Text('Reports & Analytics'),
                  subtitle: const Text('View institutional placement & ITR reports'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const FacultyReportsScreen(),
                    ),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.person_outline),
                  title: const Text('My Profile'),
                  subtitle: Text(user.email),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ProfileScreen(
                        user: user,
                        onUpdated: onUserUpdated,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
