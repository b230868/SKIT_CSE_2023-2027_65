import 'package:flutter/material.dart';

import '../auth/data/auth_service.dart';
import '../auth/models/app_user.dart';
import '../student/student_shell.dart';
import 'coming_soon_screen.dart';

/// Role-based access: each role opens its own home.
/// MERGE POINT: teammates replace the ComingSoonScreen for their role here
/// (faculty/tnp -> Vineet, industry -> Yashi). Keep this the only shared edit.
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
          case 'tnp':
            // TODO (Vineet): return FacultyShell(user: user);
            return ComingSoonScreen(user: user);
          case 'industry':
            // TODO (Yashi): return IndustryShell(user: user);
            return ComingSoonScreen(user: user);
          default:
            return ComingSoonScreen(user: user);
        }
      },
    );
  }
}
