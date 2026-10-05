import 'package:flutter/material.dart';

import '../auth/data/auth_service.dart';
import '../auth/models/app_user.dart';
import '../faculty_tp/presentation/screens/faculty_dashboard_screen.dart';
import '../faculty_tp/presentation/screens/tp_dashboard_screen.dart';
import '../industry/presentation/screens/industry_dashboard_screen.dart';
import '../../screens/student/student_shell.dart';
import 'coming_soon_screen.dart';

/// Routes signed-in users to the dashboard for their role.
class RoleHome extends StatefulWidget {
  const RoleHome({super.key});

  @override
  State<RoleHome> createState() => _RoleHomeState();
}

class _RoleHomeState extends State<RoleHome> {
  late Future<AppUser> _future;

  @override
  void initState() {
    super.initState();
    _future = AuthService().fetchProfile();
  }

  void _retry() => setState(() => _future = AuthService().fetchProfile());

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<AppUser>(
      future: _future,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || !snap.hasData) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('We could not load your profile.'),
                    const SizedBox(height: 16),
                    FilledButton(onPressed: _retry, child: const Text('Try again')),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () => AuthService().signOut(),
                      child: const Text('Sign out'),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        final user = snap.data!;
        switch (user.role) {
          case 'student':
            return StudentShell(user: user);
          case 'faculty':
            return const FacultyDashboardScreen();
          case 'tnp':
            return const TpDashboardScreen();
          case 'industry':
            return const IndustryDashboardScreen();
          default:
            return ComingSoonScreen(user: user);
        }
      },
    );
  }
}
