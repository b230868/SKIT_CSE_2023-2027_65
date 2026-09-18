import 'package:flutter/material.dart';

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
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _error = 'Unable to load student monitoring data';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Monitoring'),
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