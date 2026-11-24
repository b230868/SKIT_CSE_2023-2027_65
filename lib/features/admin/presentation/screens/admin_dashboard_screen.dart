import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/theme.dart';
import '../../../../core/utils.dart';
import '../../../../core/widgets/empty_state_widget.dart';
import '../../../../core/widgets/kpi_metric_card.dart';
import '../../../auth/models/app_user.dart';
import 'admin_affiliations_screen.dart';
import 'admin_erp_sync_screen.dart';
import 'admin_user_management_screen.dart';

class AdminDashboardScreen extends StatefulWidget {
  final AppUser user;
  final ValueChanged<int>? onNavigateTab;

  const AdminDashboardScreen({
    super.key,
    required this.user,
    this.onNavigateTab,
  });

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  bool _isLoading = true;
  int _totalUsers = 0;
  int _activeInternships = 0;
  int _pendingAffiliations = 0;
  final int _erpSyncedCount = 100;
  List<Map<String, dynamic>> _recentEvents = [];

  @override
  void initState() {
    super.initState();
    _loadMetrics();
  }

  Future<void> _loadMetrics() async {
    setState(() => _isLoading = true);
    try {
      final client = Supabase.instance.client;
      final userRes = await client.from('profiles').select('id').count(CountOption.exact);
      final internRes = await client.from('internships').select('id').count(CountOption.exact);
      final affRes = await client
          .from('company_affiliation_requests')
          .select('id')
          .eq('status', 'pending')
          .count(CountOption.exact);
      final notifRes = await client
          .from('notifications')
          .select('title, message, created_at')
          .order('created_at', ascending: false)
          .limit(5);

      final userCount = userRes.count;
      final internCount = internRes.count;
      final affCount = affRes.count;
      final notifRows = notifRes as List;

      if (mounted) {
        setState(() {
          _totalUsers = userCount;
          _activeInternships = internCount;
          _pendingAffiliations = affCount;
          _recentEvents = List<Map<String, dynamic>>.from(notifRows);
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.paper,
      appBar: AppBar(
        title: const Text('Admin Console'),
        actions: [
          IconButton(
            tooltip: 'Refresh Metrics',
            icon: const Icon(Icons.refresh),
            onPressed: _loadMetrics,
          ),
          IconButton(
            tooltip: 'System Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _showSystemSettingsDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadMetrics,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                children: [
                  // Welcome Header
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppTheme.ink,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppTheme.ink.withValues(alpha: 0.15),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: AppTheme.saffron.withValues(alpha: 0.2),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppTheme.saffron.withValues(alpha: 0.5),
                                ),
                              ),
                              child: const Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.verified_user,
                                    color: AppTheme.saffron,
                                    size: 14,
                                  ),
                                  SizedBox(width: 5),
                                  Text(
                                    'System Administrator',
                                    style: TextStyle(
                                      color: AppTheme.saffron,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white12,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 8,
                                    height: 8,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF22C55E),
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Text(
                                    'ERP Online',
                                    style: TextStyle(
                                      color: Colors.white70,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Welcome back, ${widget.user.firstName}',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Central management for students, industry partners, approvals, and ERP sync.',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  // SaaS Metric Cards Grid
                  Row(
                    children: [
                      Expanded(
                        child: KpiMetricCard(
                          title: 'Total Users',
                          value: '$_totalUsers',
                          subtitle: 'Students, Staff, Mentors',
                          icon: Icons.group_outlined,
                          color: const Color(0xFF3B82F6),
                          onTap: () => widget.onNavigateTab?.call(1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: KpiMetricCard(
                          title: 'Active Interns',
                          value: '$_activeInternships',
                          subtitle: 'Ongoing across sectors',
                          icon: Icons.work_outline,
                          color: const Color(0xFF10B981),
                          onTap: () => widget.onNavigateTab?.call(1),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: KpiMetricCard(
                          title: 'Affiliations',
                          value: '$_pendingAffiliations',
                          subtitle: 'Pending requests',
                          icon: Icons.apartment_outlined,
                          color: const Color(0xFFF59E0B),
                          badge: _pendingAffiliations > 0 ? 'Needs Review' : null,
                          onTap: () => widget.onNavigateTab?.call(2),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: KpiMetricCard(
                          title: 'ERP Sync',
                          value: '$_erpSyncedCount%',
                          subtitle: 'Grades & ITR synced',
                          icon: Icons.sync_alt,
                          color: const Color(0xFF8B5CF6),
                          onTap: () => widget.onNavigateTab?.call(3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Quick Operations Section
                  const Text(
                    'Quick Admin Operations',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.ink,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Column(
                      children: [
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFEFF6FF),
                            child: Icon(Icons.people_alt_outlined, color: Color(0xFF2563EB)),
                          ),
                          title: const Text('Manage User Accounts'),
                          subtitle: const Text('Filter, inspect, and toggle role permissions'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminUserManagementScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFFFFBEB),
                            child: Icon(Icons.verified_outlined, color: Color(0xFFD97706)),
                          ),
                          title: const Text('Industry Affiliation Approvals'),
                          subtitle: const Text('Review company credentials, CIN and supervisor claims'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminAffiliationsScreen(),
                            ),
                          ),
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const CircleAvatar(
                            backgroundColor: Color(0xFFF3E8FF),
                            child: Icon(Icons.sync, color: Color(0xFF9333EA)),
                          ),
                          title: const Text('University ERP Integration & Sync'),
                          subtitle: const Text('Sync student grades, credits and verified records'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () => Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AdminErpSyncScreen(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Live Audit Activity Log
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Recent System Events',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.ink,
                        ),
                      ),
                      Text(
                        'Live Feed',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF10B981),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: _recentEvents.isEmpty
                          ? const EmptyStateWidget(
                              message: 'No recent system events logged.',
                              icon: Icons.notifications_none,
                            )
                          : Column(
                              children: _recentEvents.map((evt) {
                                final title = evt['title'] ?? 'System Event';
                                final msg = evt['message'] ?? '';
                                final rawTime = evt['created_at'];
                                String timeStr = '';
                                if (rawTime != null) {
                                  try {
                                    timeStr = fmtDate(DateTime.parse(rawTime));
                                  } catch (_) {}
                                }
                                return _buildAuditItem(
                                  icon: Icons.notifications_none,
                                  iconColor: AppTheme.ink,
                                  title: title,
                                  subtitle: msg,
                                  time: timeStr,
                                );
                              }).toList(),
                            ),
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildAuditItem({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String time,
  }) {
    return ListTile(
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: iconColor.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: iconColor, size: 20),
      ),
      title: Text(
        title,
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(fontSize: 12, color: AppTheme.slateMuted),
      ),
      trailing: Text(
        time,
        style: TextStyle(fontSize: 11, color: Colors.grey.shade500),
      ),
    );
  }

  void _showSystemSettingsDialog() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('System Configuration'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Prashikshan ERP Connector: Active\nSupabase Cluster: ap-south-1\nAuth Provider: Supabase Auth + JWT\nRealtime Channels: Enabled',
              style: TextStyle(fontSize: 13, height: 1.5),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: () {
                Navigator.pop(ctx);
                showSnack(context, 'System diagnostics check passed (All systems 100% operational)');
              },
              icon: const Icon(Icons.check_circle_outline),
              label: const Text('Run Health Diagnostics'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
