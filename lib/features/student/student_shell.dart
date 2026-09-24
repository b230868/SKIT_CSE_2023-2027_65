import 'package:flutter/material.dart';

import '../auth/models/app_user.dart';
import '../auth/presentation/profile_screen.dart';
import '../internship/presentation/internship_list_screen.dart';
import 'student_dashboard_screen.dart';

/// Bottom navigation for the student portal: Home | Internships | Profile
class StudentShell extends StatefulWidget {
  final AppUser user;
  const StudentShell({super.key, required this.user});

  @override
  State<StudentShell> createState() => _StudentShellState();
}

class _StudentShellState extends State<StudentShell> {
  int _index = 0;
  int _version = 0; // bump to make the dashboard reload
  late AppUser _user;

  @override
  void initState() {
    super.initState();
    _user = widget.user;
  }

  void _refreshDashboard() => setState(() => _version++);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          StudentDashboardScreen(
            key: ValueKey('dashboard-$_version'),
            user: _user,
            onApply: () => setState(() => _index = 1),
          ),
          InternshipListScreen(onChanged: _refreshDashboard),
          ProfileScreen(
            user: _user,
            onUpdated: (u) => setState(() => _user = u),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              selectedIcon: Icon(Icons.dashboard),
              label: 'Home'),
          NavigationDestination(
              icon: Icon(Icons.work_outline),
              selectedIcon: Icon(Icons.work),
              label: 'Internships'),
          NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: 'Profile'),
        ],
      ),
    );
  }
}
