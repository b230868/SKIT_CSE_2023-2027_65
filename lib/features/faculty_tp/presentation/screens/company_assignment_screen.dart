import 'package:flutter/material.dart';

import '../../data/models/company_assignment_model.dart';
import '../../data/repositories/company_assignment_repository.dart';
import '../../data/repositories/mock_company_assignment_repository.dart';
import '../../data/repositories/supabase_company_assignment_repository.dart';

class CompanyAssignmentScreen extends StatefulWidget {
  final CompanyAssignmentRepository? repository;

  const CompanyAssignmentScreen({super.key, this.repository});

  @override
  State<CompanyAssignmentScreen> createState() =>
      _CompanyAssignmentScreenState();
}

class _CompanyAssignmentScreenState extends State<CompanyAssignmentScreen> {
  late final CompanyAssignmentRepository _repository;

  List<CompanyAssignmentUser> _supervisors = [];
  List<VerifiedCompany> _companies = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _repository = widget.repository ?? _resolveDefaultRepository();
    _loadData();
  }

  CompanyAssignmentRepository _resolveDefaultRepository() {
    try {
      return SupabaseCompanyAssignmentRepository();
    } catch (_) {
      return MockCompanyAssignmentRepository();
    }
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final sups = await _repository.getIndustrySupervisors();
      final comps = await _repository.getVerifiedCompanies();

      if (!mounted) return;
      setState(() {
        _supervisors = sups;
        _companies = comps;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _showAssignDialog(CompanyAssignmentUser user) async {
    String? selectedCompanyId =
        user.assignedIndustryId ??
        (_companies.isNotEmpty ? _companies.first.id : null);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Assign Verified Company'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Supervisor: ${user.fullName}',
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              if (user.requestedCompanyName != null) ...[
                const SizedBox(height: 4),
                Text(
                  'Self-Registered Note: "${user.requestedCompanyName}"',
                  style: const TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ],
              const SizedBox(height: 16),
              const Text('Select Verified Organization:'),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                initialValue: selectedCompanyId,
                isExpanded: true,
                items: _companies
                    .map(
                      (c) => DropdownMenuItem(value: c.id, child: Text(c.name)),
                    )
                    .toList(),
                onChanged: (val) {
                  setDialogState(() {
                    selectedCompanyId = val;
                  });
                },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: selectedCompanyId != null
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Confirm Assignment'),
            ),
          ],
        ),
      ),
    );

    if (confirmed == true && selectedCompanyId != null) {
      try {
        await _repository.assignSupervisorToCompany(
          supervisorUserId: user.id,
          industryId: selectedCompanyId!,
        );
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Company assignment updated successfully.'),
            backgroundColor: Colors.green,
          ),
        );
        _loadData();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Assignment failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _revokeAssignment(CompanyAssignmentUser user) async {
    try {
      await _repository.revokeSupervisorAssignment(supervisorUserId: user.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Supervisor company assignment revoked.')),
      );
      _loadData();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Revocation failed: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Industry Company Assignment'),
        actions: [
          IconButton(
            onPressed: _loadData,
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
      return const Center(child: CircularProgressIndicator());
    }

    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 12),
              Text(_errorMessage!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: _loadData, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (_supervisors.isEmpty) {
      return const Center(
        child: Text('No industry supervisor accounts found.'),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _supervisors.length,
      itemBuilder: (context, idx) {
        final sup = _supervisors[idx];
        final isAssigned = sup.isAssigned;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        sup.fullName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: isAssigned
                            ? Colors.green.shade50
                            : Colors.amber.shade50,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isAssigned
                              ? Colors.green.shade400
                              : Colors.amber.shade400,
                        ),
                      ),
                      child: Text(
                        isAssigned ? 'VERIFIED ASSIGNED' : 'PENDING ASSIGNMENT',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                          color: isAssigned
                              ? Colors.green.shade900
                              : Colors.amber.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                if (sup.requestedCompanyName != null &&
                    sup.requestedCompanyName!.isNotEmpty)
                  Text(
                    'Requested Company: ${sup.requestedCompanyName}',
                    style: const TextStyle(color: Colors.black87, fontSize: 13),
                  ),
                const SizedBox(height: 4),
                Text(
                  isAssigned ? 'Verified Company: ${sup.assignedIndustryName}' : 'Verified Company: None (Restricted from accessing interns)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: isAssigned
                        ? FontWeight.w600
                        : FontWeight.normal,
                    color: isAssigned
                        ? Colors.green.shade800
                        : Colors.red.shade700,
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (isAssigned) ...[
                      TextButton.icon(
                        onPressed: () => _revokeAssignment(sup),
                        icon: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.red,
                        ),
                        label: const Text(
                          'Revoke',
                          style: TextStyle(color: Colors.red),
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],
                    FilledButton.icon(
                      onPressed: () => _showAssignDialog(sup),
                      icon: const Icon(Icons.business, size: 16),
                      label: Text(isAssigned ? 'Reassign' : 'Assign Company'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
