import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../data/repositories/student_monitoring_repository_factory.dart';
import '../../data/services/student_monitoring_service.dart';
import '../../data/models/student_monitoring_item.dart';

class StudentMonitoringScreen extends StatefulWidget {
  const StudentMonitoringScreen({super.key});

  @override
  State<StudentMonitoringScreen> createState() =>
      _StudentMonitoringScreenState();
}

class _StudentMonitoringScreenState
    extends State<StudentMonitoringScreen> {
  late final StudentMonitoringService _service;

  List<StudentMonitoringItem> _students = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();

    _service = StudentMonitoringService(
  repository: StudentMonitoringRepositoryFactory.create(),
);

    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final students = await _service.loadStudents();

      if (!mounted) return;

      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      final String message;
      if (e is UnauthenticatedException) {
        message = 'Please sign in to access student monitoring data.';
      } else if (e is UnauthorizedException ||
          (e is PostgrestException && e.code == '42501') ||
          e.toString().toLowerCase().contains('permission denied')) {
        message =
            'Your account does not have permission to access student monitoring data.';
      } else {
        message = 'Unable to load student monitoring data';
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
        title: const Text('Student Monitoring'),
        actions: [
          IconButton(
            onPressed: () => AuthService.showAuthDialog(
              context,
              onSessionChanged: _loadStudents,
            ),
            icon: Icon(
              AuthService.hasActiveSession
                  ? Icons.account_circle
                  : Icons.account_circle_outlined,
            ),
            tooltip: AuthService.hasActiveSession ? 'Account' : 'Sign In',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStudents,
              child: const Text('Retry'),
            ),
            if (_error!.contains('sign in')) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => AuthService.showAuthDialog(
                  context,
                  onSessionChanged: _loadStudents,
                ),
                child: const Text('Sign In'),
              ),
            ],
          ],
        ),
      );
    }

    if (_students.isEmpty) {
      return const Center(
        child: Text('No students available'),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadStudents,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _students.length,
        itemBuilder: (context, index) {
          final student = _students[index];

          return Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(student.studentName),
              subtitle: Text(
                '${student.internshipTitle}\n'
                'Status: ${student.applicationStatus}',
              ),
              isThreeLine: true,
            ),
          );
        },
      ),
    );
  }
}