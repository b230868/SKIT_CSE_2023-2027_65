import 'package:flutter/material.dart';

import '../auth/data/auth_service.dart';
import '../auth/models/app_user.dart';

class ComingSoonScreen extends StatelessWidget {
  final AppUser user;
  const ComingSoonScreen({super.key, required this.user});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Prashikshan')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Welcome, ${user.firstName}',
                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('The ${user.roleLabel} dashboard is still being built.',
                  textAlign: TextAlign.center),
              const SizedBox(height: 24),
              SizedBox(
                width: 220,
                child: OutlinedButton.icon(
                  onPressed: () => AuthService().signOut(),
                  icon: const Icon(Icons.logout),
                  label: const Text('Sign out'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
