import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/status_chip.dart';

class AdminAffiliationsScreen extends StatefulWidget {
  const AdminAffiliationsScreen({super.key});

  @override
  State<AdminAffiliationsScreen> createState() =>
      _AdminAffiliationsScreenState();
}

class _AdminAffiliationsScreenState extends State<AdminAffiliationsScreen> {
  String _selectedFilter = 'pending';
  bool _isLoading = true;
  List<Map<String, dynamic>> _requests = [];

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final rows = await client
          .from('company_affiliation_requests')
          .select('*')
          .order('created_at', ascending: false);

      final list = List<Map<String, dynamic>>.from(rows as List);
      if (mounted) {
        setState(() {
          _requests = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _requests = [];
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(
    Map<String, dynamic> req,
    String newStatus, {
    String? reason,
  }) async {
    try {
      final client = Supabase.instance.client;
      await client
          .from('company_affiliation_requests')
          .update({'status': newStatus})
          .eq('id', req['id']);
    } catch (_) {
      // Fallback to local state if offline
    }

    setState(() {
      req['status'] = newStatus;
      if (reason != null) req['rejection_reason'] = reason;
    });

    if (mounted) {
      showSnack(
        context,
        '${req['company_name']} affiliation has been $newStatus',
      );
    }
  }

  List<Map<String, dynamic>> get _filteredRequests {
    if (_selectedFilter == 'all') return _requests;
    return _requests
        .where((r) =>
            (r['status'] ?? 'pending').toString().toLowerCase() ==
            _selectedFilter)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredRequests;
    final pendingCount = _requests
        .where((r) => (r['status'] ?? 'pending') == 'pending')
        .length;

    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        title: const Text('Industry Affiliations'),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh),
            onPressed: _fetchRequests,
          ),
        ],
      ),
      body: Column(
        children: [
          // Filter Tabs
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildFilterTab(
                    'pending',
                    'Pending ($pendingCount)',
                    isAlert: pendingCount > 0,
                  ),
                  const SizedBox(width: 8),
                  _buildFilterTab('approved', 'Approved'),
                  const SizedBox(width: 8),
                  _buildFilterTab('rejected', 'Rejected'),
                  const SizedBox(width: 8),
                  _buildFilterTab('all', 'All (${_requests.length})'),
                ],
              ),
            ),
          ),
          const Divider(height: 1),

          // List
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : filtered.isEmpty
                    ? EmptyStateWidget(
                        message: 'No $_selectedFilter affiliation requests.',
                        icon: Icons.apartment_outlined,
                      )
                    : RefreshIndicator(
                        onRefresh: _fetchRequests,
                        child: ListView.separated(
                          padding: const EdgeInsets.all(16),
                          itemCount: filtered.length,
                          separatorBuilder: (context, index) =>
                              const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final req = filtered[index];
                            return _buildAffiliationCard(req);
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(String key, String label, {bool isAlert = false}) {
    final isSelected = _selectedFilter == key;
    return ChoiceChip(
      selected: isSelected,
      label: Text(label),
      labelStyle: TextStyle(
        fontSize: 13,
        fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
        color: isSelected ? Colors.white : AppTheme.ink,
      ),
      selectedColor: isAlert ? const Color(0xFFD97706) : AppTheme.ink,
      backgroundColor: Colors.white,
      side: BorderSide(
        color: isSelected
            ? (isAlert ? const Color(0xFFD97706) : AppTheme.ink)
            : AppTheme.slateBorder,
      ),
      onSelected: (_) => setState(() => _selectedFilter = key),
    );
  }

  Widget _buildAffiliationCard(Map<String, dynamic> req) {
    final status = (req['status'] ?? 'pending').toString().toLowerCase();
    final company = req['company_name'] ?? 'Unknown Company';
    final supervisor = req['designation'] ?? 'Industry Supervisor';
    final email = req['contact_email'] ?? '';
    final website = req['website'] ?? '';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.apartment,
                    color: AppTheme.ink,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        company,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        supervisor,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppTheme.slateMuted,
                        ),
                      ),
                      if (email.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          email,
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade600,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                StatusChip(status: status),
              ],
            ),
            if (website.isNotEmpty) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  const Icon(
                    Icons.language,
                    size: 15,
                    color: AppTheme.slateMuted,
                  ),
                  const SizedBox(width: 6),
                  Text(
                    website,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ],
            if (status == 'pending') ...[
              const SizedBox(height: 14),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red.shade700,
                      side: BorderSide(color: Colors.red.shade200),
                      minimumSize: const Size(100, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 14),
                    ),
                    icon: const Icon(Icons.close, size: 16),
                    label: const Text('Reject'),
                    onPressed: () => _showRejectDialog(req),
                  ),
                  const SizedBox(width: 10),
                  FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF10B981),
                      minimumSize: const Size(120, 38),
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    icon: const Icon(Icons.check, size: 16),
                    label: const Text('Approve Company'),
                    onPressed: () => _updateStatus(req, 'approved'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showRejectDialog(Map<String, dynamic> req) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject ${req['company_name']}?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Specify reason for rejecting this industry affiliation request:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reasonCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                hintText: 'e.g. Unverified corporate registration / missing CIN',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red.shade700),
            onPressed: () {
              Navigator.pop(ctx);
              _updateStatus(req, 'rejected', reason: reasonCtrl.text.trim());
            },
            child: const Text('Confirm Rejection'),
          ),
        ],
      ),
    );
  }
}
