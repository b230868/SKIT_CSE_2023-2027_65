import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../data/models/approval_request_model.dart';
import '../../data/repositories/approval_repository.dart';
import '../../data/services/approval_repository_provider.dart';
import '../../domain/entities/approval_review_stage.dart';
import '../../domain/entities/approval_status.dart';
import 'approval_list_screen.dart';

class FacultyApprovalDashboardScreen extends StatefulWidget {
  const FacultyApprovalDashboardScreen({super.key});

  @override
  State<FacultyApprovalDashboardScreen> createState() =>
      _FacultyApprovalDashboardScreenState();
}

class _FacultyApprovalDashboardScreenState
    extends State<FacultyApprovalDashboardScreen> {
  final ApprovalRepository _repository =
      ApprovalRepositoryProvider.instance;

  int _pending = 0;
  int _underReview = 0;
  int _approved = 0;
  int _rejected = 0;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadStatistics();
  }

  Future<void> _loadStatistics() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requests =
          await _repository.getApprovalRequests(
        stage: ApprovalReviewStage.faculty,
      );

      if (!mounted) return;

      setState(() {
        _pending = _count(
          requests,
          ApprovalStatus.pending,
        );
        _underReview = _count(
          requests,
          ApprovalStatus.underReview,
        );
        _approved = _count(
          requests,
          ApprovalStatus.approved,
        );
        _rejected = _count(
          requests,
          ApprovalStatus.rejected,
        );
        _isLoading = false;
      });
    } catch (error) {
      if (!mounted) return;

      final String message;
      if (error is UnauthenticatedException) {
        message = 'Please sign in to access approval data.';
      } else if (error is UnauthorizedException ||
          (error is PostgrestException && error.code == '42501') ||
          error.toString().toLowerCase().contains('permission denied')) {
        message = 'Your account does not have permission to access approval data.';
      } else {
        message = 'Unable to load approval data: $error';
      }

      setState(() {
        _isLoading = false;
        _errorMessage = message;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
    }
  }

  int _count(
    List<ApprovalRequestModel> requests,
    ApprovalStatus status,
  ) {
    return requests
        .where(
          (request) => request.approvalStatus == status,
        )
        .length;
  }

  Widget _statCard(
    String title,
    int value,
    IconData icon, {
    VoidCallback? onTap,
  }) {
    return Card(
      child: ListTile(
        leading: Icon(icon),
        title: Text(title),
        trailing: Text(
          '$value',
          style: const TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
        onTap: onTap,
      ),
    );
  }

  void _openApprovalList([ApprovalStatus? initialStatus]) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApprovalListScreen(
          title: 'Faculty Approval Requests',
          stage: ApprovalReviewStage.faculty,
          initialStatus: initialStatus,
        ),
      ),
    ).then((_) => _loadStatistics());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Faculty Approval Dashboard',
        ),
        actions: [
          IconButton(
            onPressed: () => AuthService.showAuthDialog(
              context,
              onSessionChanged: _loadStatistics,
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
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(),
            )
          : _errorMessage != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          _errorMessage!,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 16),
                        ElevatedButton(
                          onPressed: _loadStatistics,
                          child: const Text('Retry'),
                        ),
                        if (_errorMessage!.contains('sign in')) ...[
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => AuthService.showAuthDialog(
                              context,
                              onSessionChanged: _loadStatistics,
                            ),
                            child: const Text('Sign In'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _loadStatistics,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  const Text(
                    'Approval Overview',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _statCard(
                    'Pending Approvals',
                    _pending,
                    Icons.pending_actions,
                    onTap: () => _openApprovalList(ApprovalStatus.pending),
                  ),
                  _statCard(
                    'Under Review',
                    _underReview,
                    Icons.rate_review,
                    onTap: () => _openApprovalList(ApprovalStatus.underReview),
                  ),
                  _statCard(
                    'Approved',
                    _approved,
                    Icons.check_circle,
                    onTap: () => _openApprovalList(ApprovalStatus.approved),
                  ),
                  _statCard(
                    'Rejected',
                    _rejected,
                    Icons.cancel,
                    onTap: () => _openApprovalList(ApprovalStatus.rejected),
                  ),
                  const SizedBox(height: 20),
                  FilledButton.icon(
                    onPressed: _openApprovalList,
                    icon: const Icon(Icons.list),
                    label: const Text(
                      'View Approval Requests',
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}