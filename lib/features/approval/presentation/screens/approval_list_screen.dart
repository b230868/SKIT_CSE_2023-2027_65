import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../data/models/approval_request_model.dart';
import '../../data/repositories/approval_repository.dart';
import '../../data/services/approval_repository_provider.dart';
import '../../domain/entities/approval_review_stage.dart';
import '../../domain/entities/approval_status.dart';
import '../widgets/approval_status_filter.dart';
import 'approval_details_screen.dart';

class ApprovalListScreen extends StatefulWidget {
  final String title;
  final ApprovalReviewStage stage;

  const ApprovalListScreen({
    super.key,
    this.title = 'Approval Requests',
    required this.stage,
  });

  @override
  State<ApprovalListScreen> createState() =>
      _ApprovalListScreenState();
}

class _ApprovalListScreenState
    extends State<ApprovalListScreen> {
  final ApprovalRepository _repository =
      ApprovalRepositoryProvider.instance;

  final _searchController = TextEditingController();

  List<ApprovalRequestModel> _requests = [];
  List<ApprovalRequestModel> _filteredRequests = [];
  ApprovalStatus? _selectedStatus;
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    _searchController.addListener(_applyFilters);
    _loadRequests();
  }

  Future<void> _loadRequests() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final requests =
          await _repository.getApprovalRequests(
        stage: widget.stage,
      );

      if (!mounted) return;

      setState(() {
        _requests = requests;
        _isLoading = false;
      });

      _applyFilters();
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
        message = 'Unable to load approval requests: $error';
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

  void _applyFilters() {
    final query =
        _searchController.text.trim().toLowerCase();

    final filtered = _requests.where((request) {
      final matchesSearch =
          query.isEmpty ||
          request.studentName
              .toLowerCase()
              .contains(query) ||
          request.rollNumber
              .toLowerCase()
              .contains(query) ||
          request.internshipTitle
              .toLowerCase()
              .contains(query) ||
          request.industryName
              .toLowerCase()
              .contains(query);

      final matchesStatus =
          _selectedStatus == null ||
          request.approvalStatus == _selectedStatus;

      return matchesSearch && matchesStatus;
    }).toList();

    if (!mounted) return;

    setState(() {
      _filteredRequests = filtered;
    });
  }

  void _onStatusChanged(ApprovalStatus? status) {
    setState(() {
      _selectedStatus = status;
    });

    _applyFilters();
  }

  void _openDetails(
    ApprovalRequestModel request,
  ) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ApprovalDetailsScreen(
          request: request,
          stage: widget.stage,
        ),
      ),
    ).then((_) => _loadRequests());
  }

  String _statusLabel(ApprovalStatus status) {
    switch (status) {
      case ApprovalStatus.pending:
        return 'Pending';
      case ApprovalStatus.underReview:
        return 'Under Review';
      case ApprovalStatus.approved:
        return 'Approved';
      case ApprovalStatus.rejected:
        return 'Rejected';
    }
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_applyFilters)
      ..dispose();

    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            onPressed: () => AuthService.showAuthDialog(
              context,
              onSessionChanged: _loadRequests,
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
                          onPressed: _loadRequests,
                          child: const Text('Retry'),
                        ),
                        if (_errorMessage!.contains('sign in')) ...[
                          const SizedBox(height: 12),
                          FilledButton(
                            onPressed: () => AuthService.showAuthDialog(
                              context,
                              onSessionChanged: _loadRequests,
                            ),
                            child: const Text('Sign In'),
                          ),
                        ],
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
              onRefresh: _loadRequests,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      16,
                      16,
                      8,
                    ),
                    child: TextField(
                      controller: _searchController,
                      decoration: const InputDecoration(
                        labelText: 'Search approvals',
                        hintText:
                            'Student, roll number, internship or industry',
                        prefixIcon:
                            Icon(Icons.search),
                        border:
                            OutlineInputBorder(),
                      ),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      16,
                      8,
                      16,
                      16,
                    ),
                    child: ApprovalStatusFilter(
                      selectedStatus:
                          _selectedStatus,
                      onChanged:
                          _onStatusChanged,
                    ),
                  ),
                  Expanded(
                    child: _filteredRequests.isEmpty
                        ? const Center(
                            child: Text(
                              'No approval requests found.',
                            ),
                          )
                        : ListView.builder(
                            padding:
                                const EdgeInsets.symmetric(
                              horizontal: 16,
                            ),
                            itemCount:
                                _filteredRequests.length,
                            itemBuilder:
                                (context, index) {
                              final request =
                                  _filteredRequests[
                                      index];

                              return Card(
                                margin:
                                    const EdgeInsets.only(
                                  bottom: 12,
                                ),
                                child: ListTile(
                                  leading:
                                      const CircleAvatar(
                                    child: Icon(
                                      Icons.person,
                                    ),
                                  ),
                                  title: Text(
                                    request.studentName,
                                  ),
                                  subtitle: Text(
                                    '${request.rollNumber}\n'
                                    '${request.internshipTitle}\n'
                                    '${request.industryName}',
                                  ),
                                  isThreeLine: true,
                                  trailing: Column(
                                    mainAxisAlignment:
                                        MainAxisAlignment
                                            .center,
                                    children: [
                                      Text(
                                        _statusLabel(
                                          request
                                              .approvalStatus,
                                        ),
                                        style:
                                            const TextStyle(
                                          fontWeight:
                                              FontWeight
                                                  .bold,
                                        ),
                                      ),
                                      const Icon(
                                        Icons
                                            .chevron_right,
                                      ),
                                    ],
                                  ),
                                  onTap: () =>
                                      _openDetails(
                                    request,
                                  ),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
    );
  }
}