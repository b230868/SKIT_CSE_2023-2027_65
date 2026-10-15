import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../data/repositories/faculty_report_repository_factory.dart';
import '../../data/services/faculty_report_service.dart';
import '../../domain/entities/faculty_report_data.dart';

class FacultyReportsScreen extends StatefulWidget {
  const FacultyReportsScreen({super.key});

  @override
  State<FacultyReportsScreen> createState() => _FacultyReportsScreenState();
}

class _FacultyReportsScreenState extends State<FacultyReportsScreen> {
  late final FacultyReportService _service;

  FacultyReportData? _report;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = FacultyReportService(
      repository: FacultyReportRepositoryFactory.create(),
    );
    _loadReport();
  }

  Future<void> _loadReport() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final report = await _service.loadReportData();
      if (!mounted) return;
      setState(() {
        _report = report;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      final String message;
      if (e is UnauthenticatedException) {
        message = 'Please sign in to access report data.';
      } else if (e is UnauthorizedException ||
          (e is PostgrestException && e.code == '42501') ||
          e.toString().toLowerCase().contains('permission denied')) {
        message =
            'Your account does not have permission to access report data.';
      } else {
        message = 'Unable to load report data';
      }

      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  Widget _statTile(String title, String value, IconData icon) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          value,
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Faculty & T&P Reports'),
        actions: [
          IconButton(
            onPressed: () => AuthService.showAuthDialog(
              context,
              onSessionChanged: _loadReport,
            ),
            icon: Icon(
              AuthService.hasActiveSession
                  ? Icons.account_circle
                  : Icons.account_circle_outlined,
            ),
            tooltip: AuthService.hasActiveSession ? 'Account' : 'Sign In',
          ),
          IconButton(
            onPressed: _loadReport,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('Loading report data...'),
          ],
        ),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Text(
                _error!,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _loadReport,
                  child: const Text('Retry'),
                ),
                if (_error!.contains('sign in')) ...[
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: () => AuthService.showAuthDialog(
                      context,
                      onSessionChanged: _loadReport,
                    ),
                    child: const Text('Sign In'),
                  ),
                ],
              ],
            ),
          ],
        ),
      );
    }

    final report = _report;
    if (report == null || report.totalInternships == 0) {
      return const Center(child: Text('No report data available'));
    }

    return RefreshIndicator(
      onRefresh: _loadReport,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Internship Overview',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _statTile(
            'Total Internships',
            '${report.totalInternships}',
            Icons.work_outline,
          ),
          _statTile(
            'Approval Rate',
            '${report.approvalRate.toStringAsFixed(1)}%',
            Icons.pie_chart_outline,
          ),
          _statTile(
            'Approved',
            '${report.approvedInternships}',
            Icons.check_circle_outline,
          ),
          _statTile(
            'Pending Approvals',
            '${report.pendingApprovals}',
            Icons.pending_actions,
          ),
          _statTile(
            'Under Review',
            '${report.underReviewApprovals}',
            Icons.rate_review_outlined,
          ),
          _statTile(
            'Rejected',
            '${report.rejectedApplications}',
            Icons.cancel_outlined,
          ),

          const SizedBox(height: 20),
          Text(
            'Stage Distribution',
            style: Theme.of(context).textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _statTile(
            'Faculty Review Stage',
            '${report.facultyStageCount}',
            Icons.school_outlined,
          ),
          _statTile(
            'T&P Review Stage',
            '${report.tpStageCount}',
            Icons.business_outlined,
          ),

          if (report.departmentSummary.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text(
              'Department Breakdown',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...report.departmentSummary.entries.map(
              (entry) => Card(
                child: ListTile(
                  leading: const Icon(Icons.apartment),
                  title: Text(entry.key),
                  trailing: Text(
                    '${entry.value}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
