import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:prashikshan/features/industry/data/models/industry_dashboard_data.dart';
import 'package:prashikshan/features/industry/data/models/industry_internship_model.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';

import 'industry_attendance_screen.dart';
import 'industry_internship_details_screen.dart';
import 'internship_management_screen.dart';

class IndustryDashboardScreen extends StatefulWidget {
  final IndustryService? service;
  final ValueChanged<int>? onNavigateToTab;

  const IndustryDashboardScreen({
    super.key,
    this.service,
    this.onNavigateToTab,
  });

  @override
  State<IndustryDashboardScreen> createState() =>
      _IndustryDashboardScreenState();
}

class _IndustryDashboardScreenState extends State<IndustryDashboardScreen> {
  late final IndustryService _service;

  bool _loading = true;
  String? _error;
  IndustryDashboardData? _dashboardData;
  List<IndustryInternshipModel> _internships = [];
  int _unreadCount = 0;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? IndustryService();
    _loadData();
    _loadUnreadNotifications();
  }

  Future<void> _loadUnreadNotifications() async {
    try {
      final client = Supabase.instance.client;
      final user = client.auth.currentUser;
      if (user == null) return;
      final rows = await client
          .from('notifications')
          .select('id')
          .eq('recipient_id', user.id)
          .eq('is_read', false);
      if (mounted) {
        setState(() {
          _unreadCount = (rows as List).length;
        });
      }
    } catch (_) {}
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getDashboardData(),
        _service.getIndustryInternships(),
      ]);

      if (!mounted) return;

      setState(() {
        _dashboardData = results[0] as IndustryDashboardData;
        _internships = results[1] as List<IndustryInternshipModel>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _navigateToTabOrScreen(int tabIndex, Widget screen) {
    if (widget.onNavigateToTab != null) {
      widget.onNavigateToTab!(tabIndex);
    } else {
      Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    }
  }

  Future<void> _showNotificationsDialog() async {
    await showDialog(
      context: context,
      builder: (ctx) => FutureBuilder<List<Map<String, dynamic>>>(
        future: () async {
          try {
            final client = Supabase.instance.client;
            final user = client.auth.currentUser;
            if (user == null) return <Map<String, dynamic>>[];
            final rows = await client
                .from('notifications')
                .select('*')
                .eq('recipient_id', user.id)
                .order('created_at', ascending: false)
                .limit(20);
            return List<Map<String, dynamic>>.from(rows as List);
          } catch (_) {
            return <Map<String, dynamic>>[];
          }
        }(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const AlertDialog(
              content: SizedBox(
                height: 100,
                child: Center(child: CircularProgressIndicator()),
              ),
            );
          }

          final list = snapshot.data ?? [];
          return AlertDialog(
            title: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Row(
                  children: [
                    Icon(Icons.notifications, color: Colors.blue),
                    SizedBox(width: 8),
                    Text('Notifications'),
                  ],
                ),
                if (list.isNotEmpty)
                  TextButton(
                    onPressed: () async {
                      try {
                        final client = Supabase.instance.client;
                        final user = client.auth.currentUser;
                        if (user != null) {
                          await client
                              .from('notifications')
                              .update({'is_read': true})
                              .eq('recipient_id', user.id);
                        }
                      } catch (_) {}
                      if (context.mounted) {
                        Navigator.pop(ctx);
                        _loadUnreadNotifications();
                      }
                    },
                    child: const Text(
                      'Mark all read',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            content: SizedBox(
              width: 450,
              child: list.isEmpty
                  ? const Padding(
                      padding: EdgeInsets.all(24),
                      child: Text(
                        'No notifications yet.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    )
                  : ListView.separated(
                      shrinkWrap: true,
                      itemCount: list.length,
                      separatorBuilder: (context, index) => const Divider(),
                      itemBuilder: (context, index) {
                        final notif = list[index];
                        final isRead = notif['is_read'] == true;
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: CircleAvatar(
                            backgroundColor: isRead
                                ? Colors.grey.shade200
                                : Colors.blue.shade100,
                            child: Icon(
                              isRead ? Icons.done : Icons.notifications_active,
                              size: 18,
                              color: isRead ? Colors.grey : Colors.blue,
                            ),
                          ),
                          title: Text(
                            notif['title']?.toString() ?? 'Notification',
                            style: TextStyle(
                              fontWeight: isRead
                                  ? FontWeight.normal
                                  : FontWeight.bold,
                            ),
                          ),
                          subtitle: Text(notif['message']?.toString() ?? ''),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Close'),
              ),
            ],
          );
        },
      ),
    );
    _loadUnreadNotifications();
  }

  Future<void> _showAffiliationRequestDialog() async {
    final companyController = TextEditingController();
    final designationController = TextEditingController(text: 'Supervisor');
    final emailController = TextEditingController();
    final phoneController = TextEditingController();
    final websiteController = TextEditingController();

    final submitted = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.business, color: Colors.blue),
            SizedBox(width: 8),
            Text('Request Company Affiliation'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Submit your company affiliation request for review by administrators or T&P officers.',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: companyController,
                decoration: const InputDecoration(
                  labelText: 'Company / Organization Name *',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.corporate_fare),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: designationController,
                decoration: const InputDecoration(
                  labelText: 'Your Designation',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailController,
                decoration: const InputDecoration(
                  labelText: 'Official Contact Email',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.email),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: phoneController,
                decoration: const InputDecoration(
                  labelText: 'Contact Phone Number',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.phone),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: websiteController,
                decoration: const InputDecoration(
                  labelText: 'Company Website (optional)',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.language),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              if (companyController.text.trim().isEmpty) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Please enter company name')),
                );
                return;
              }
              Navigator.pop(ctx, true);
            },
            child: const Text('Submit Request'),
          ),
        ],
      ),
    );

    if (submitted == true) {
      try {
        await _service.submitAffiliationRequest(
          companyName: companyController.text.trim(),
          designation: designationController.text.trim(),
          contactEmail: emailController.text.trim().isNotEmpty
              ? emailController.text.trim()
              : null,
          contactPhone: phoneController.text.trim().isNotEmpty
              ? phoneController.text.trim()
              : null,
          website: websiteController.text.trim().isNotEmpty
              ? websiteController.text.trim()
              : null,
        );

        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Company affiliation request submitted successfully! Awaiting T&P administrator approval.',
            ),
            backgroundColor: Colors.green,
          ),
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to submit request: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Industry Dashboard'),
        centerTitle: false,
        actions: [
          IconButton(
            icon: Badge(
              isLabelVisible: _unreadCount > 0,
              label: Text('$_unreadCount'),
              child: const Icon(Icons.notifications_outlined),
            ),
            tooltip: 'Notifications',
            onPressed: _showNotificationsDialog,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 50, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                'Unable to load dashboard.\n\n$_error',
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: _loadData,
                child: const Text('Try Again'),
              ),
            ],
          ),
        ),
      );
    }

    final data = _dashboardData ?? IndustryDashboardData.empty();

    return RefreshIndicator(
      onRefresh: _loadData,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        children: [
          // Industry Company Header Banner
          Card(
            color: const Color(0xFF14213D),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: const Color(0xFFE09F1F),
                    child: Text(
                      data.industryName.isNotEmpty
                          ? data.industryName[0].toUpperCase()
                          : 'I',
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.bold,
                        color: Colors.black,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data.industryName,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Company Supervisor Portal',
                          style: TextStyle(fontSize: 13, color: Colors.white70),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          if (data.industryName.isEmpty ||
              data.industryName.toLowerCase().contains('unassigned') ||
              data.industryName.toLowerCase().contains('unverified')) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.amber.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.amber.shade400),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    color: Colors.amber.shade900,
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Company Assignment Pending',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.amber.shade900,
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'No verified company association is linked to your supervisor account. Intern records, attendance tracking, and evaluations remain restricted until an administrator assigns your company.',
                          style: TextStyle(
                            color: Colors.amber.shade900,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        FilledButton.tonalIcon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.amber.shade200,
                            foregroundColor: Colors.amber.shade900,
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: _showAffiliationRequestDialog,
                          icon: const Icon(Icons.business, size: 16),
                          label: const Text(
                            'Request Company Affiliation',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),

          // Primary KPI Stat Cards Row 1: Total Interns & Active Interns
          Row(
            children: [
              Expanded(
                child: _DashboardCard(
                  title: 'Total Assigned',
                  value: data.totalInterns.toString(),
                  icon: Icons.groups_outlined,
                  color: Colors.blueGrey,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InternshipManagementScreen(
                        service: _service,
                        initialFilter: 'all',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardCard(
                  title: 'Active Interns',
                  value: data.activeInterns.toString(),
                  icon: Icons.people,
                  color: Colors.teal,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InternshipManagementScreen(
                        service: _service,
                        initialFilter: 'active',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // KPI Stat Cards Row 2: Attendance Pending & Evaluations Due
          Row(
            children: [
              Expanded(
                child: _DashboardCard(
                  title: 'Attendance Pending',
                  value: data.pendingAttendance.toString(),
                  icon: Icons.fact_check_outlined,
                  color: Colors.orange,
                  onTap: () => _navigateToTabOrScreen(
                    2,
                    IndustryAttendanceScreen(service: _service),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardCard(
                  title: 'Evaluations Due',
                  value: data.pendingEvaluations.toString(),
                  icon: Icons.assignment_turned_in,
                  color: Colors.indigo,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InternshipManagementScreen(
                        service: _service,
                        initialFilter: 'pending_eval',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // KPI Stat Cards Row 3: Certificates Pending & Completed
          Row(
            children: [
              Expanded(
                child: _DashboardCard(
                  title: 'Certificates Pending',
                  value: data.pendingCertificates.toString(),
                  icon: Icons.workspace_premium_outlined,
                  color: Colors.deepPurple,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InternshipManagementScreen(
                        service: _service,
                        initialFilter: 'completed',
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DashboardCard(
                  title: 'Completed',
                  value: data.completedInternships.toString(),
                  icon: Icons.check_circle,
                  color: Colors.green,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => InternshipManagementScreen(
                        service: _service,
                        initialFilter: 'completed',
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Recent Interns Section
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Assigned Interns',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              TextButton(
                onPressed: () => _navigateToTabOrScreen(
                  1,
                  InternshipManagementScreen(service: _service),
                ),
                child: const Text('View All'),
              ),
            ],
          ),

          const SizedBox(height: 8),

          if (_internships.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: Text('No active internships found.')),
              ),
            )
          else
            ..._internships
                .take(4)
                .map(
                  (internship) => Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(
                        child: Text(
                          internship.studentName.isNotEmpty
                              ? internship.studentName[0].toUpperCase()
                              : 'S',
                        ),
                      ),
                      title: Text(
                        internship.studentName,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Text(
                        '${internship.internshipTitle} • Progress: ${internship.progress.toStringAsFixed(0)}%',
                      ),
                      trailing: const Icon(Icons.arrow_forward_ios, size: 14),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => IndustryInternshipDetailsScreen(
                              internship: internship,
                              industryService: _service,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
        ],
      ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _DashboardCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withAlpha(25),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, size: 28, color: color),
              ),
              const SizedBox(height: 10),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 26,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                title,
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13, color: Colors.grey.shade700),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
