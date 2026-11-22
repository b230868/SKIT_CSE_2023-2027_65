import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../core/utils.dart';
import '../../core/widgets/status_chip.dart';
import '../../models/notification_models.dart';
import '../../models/student_models.dart';
import '../../services/notification_service.dart';
import '../../shared/widgets/animated_count_card.dart';
import '../../shared/widgets/empty_state_view.dart';
import '../../shared/widgets/error_state_view.dart';
import '../../shared/widgets/progress_ring.dart';
import '../../shared/widgets/skeleton_loader.dart';
import '../auth/models/app_user.dart';
import '../internship/data/internship_service.dart';
import '../internship/models/internship.dart';
import '../internship/presentation/internship_detail_screen.dart';
import '../internship/presentation/internship_form_screen.dart';
import 'presentation/student_application_detail_screen.dart';
import 'presentation/student_applications_screen.dart';
import 'presentation/student_reports_screen.dart';
import 'widgets/student_notification_bell.dart';

class StudentDashboardScreen extends StatefulWidget {
  final AppUser user;
  final VoidCallback onApply;
  final void Function(int tabIndex, {String? filter})? onNavigate;

  const StudentDashboardScreen({
    super.key,
    required this.user,
    required this.onApply,
    this.onNavigate,
  });

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  final _service = InternshipService();
  final _notifService = NotificationService();
  late Future<List<Internship>> _future;
  late Future<List<AppNotification>> _notifFuture;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _future = _service.fetchMine();
    _notifFuture = _notifService.list();
  }

  Future<void> _reload() async {
    setState(() {
      _load();
    });
    try {
      await Future.wait([_future, _notifFuture]);
    } catch (_) {}
  }

  Future<void> _openApplyForm() async {
    final res = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const InternshipFormScreen()),
    );
    if (res == true || mounted) {
      await _reload();
    }
  }

  void _navigateToApplications([String filter = 'all']) {
    if (widget.onNavigate != null) {
      widget.onNavigate!(1, filter: filter); // Applications tab
    } else {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StudentApplicationsScreen(
            initialFilter: filter,
            onBrowseInternships: widget.onApply,
          ),
        ),
      ).then((_) => _reload());
    }
  }

  void _openReports() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const StudentReportsScreen()),
    );
  }

  void _openApplicationDetail(Internship item, {int tabIndex = 0}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => StudentApplicationDetailScreen(
          application: Application(item),
          initialTabIndex: tabIndex,
        ),
      ),
    ).then((_) => _reload());
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}';
  }

  IconData _iconForType(String type) => switch (type.toLowerCase()) {
        'application' => Icons.assignment_turned_in_outlined,
        'document' => Icons.description_outlined,
        'progress' => Icons.timeline,
        'alert' => Icons.warning_amber_rounded,
        _ => Icons.notifications_outlined,
      };

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Prashikshan'),
        actions: [
          IconButton(
            tooltip: 'My Reports & Analytics',
            icon: const Icon(Icons.bar_chart_outlined),
            onPressed: _openReports,
          ),
          const StudentNotificationBell(),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _reload,
        child: FutureBuilder<List<Internship>>(
          future: _future,
          builder: (context, snap) {
            if (snap.connectionState != ConnectionState.done) {
              return const DashboardSkeleton();
            }

            if (snap.hasError) {
              return ErrorStateView(
                title: 'Could not load dashboard',
                message: 'Unable to retrieve your internships. Please pull down to retry.',
                onRetry: _reload,
              );
            }

            final items = snap.data ?? [];
            final pending = items.where((i) => i.status.toLowerCase() == 'pending').length;
            final approved = items.where((i) {
              final s = i.status.toLowerCase();
              return s == 'approved' || s == 'active' || s == 'completed';
            }).length;
            final rejected = items.where((i) => i.status.toLowerCase() == 'rejected').length;

            final approvedInternship = items.where((i) {
              final s = i.status.toLowerCase();
              return s == 'approved' || s == 'active';
            }).firstOrNull;

            final latestInternship = approvedInternship ?? (items.isNotEmpty ? items.first : null);
            final latestProgress = latestInternship?.progress ?? 0;

            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 6, 20, 28),
              children: [
                // Welcome Greeting
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Hello, ${widget.user.firstName}',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: isDark ? Colors.white : AppTheme.ink,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          items.isEmpty
                              ? 'Apply for an internship to start your tracking journey.'
                              : 'Here is where your internship progress stands.',
                          style: TextStyle(
                            fontSize: 13,
                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade700,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 1. Animated Count-Up Stat Cards (Pending, Approved, Rejected)
                Row(
                  children: [
                    Expanded(
                      child: AnimatedCountCard(
                        label: 'Pending',
                        count: pending,
                        icon: Icons.hourglass_top_outlined,
                        color: AppTheme.saffron,
                        tooltip: 'View pending applications',
                        onTap: () => _navigateToApplications('pending'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedCountCard(
                        label: 'Approved',
                        count: approved,
                        icon: Icons.check_circle_outline,
                        color: Colors.green,
                        tooltip: 'View approved applications',
                        onTap: () => _navigateToApplications('approved'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: AnimatedCountCard(
                        label: 'Rejected',
                        count: rejected,
                        icon: Icons.cancel_outlined,
                        color: Colors.red,
                        tooltip: 'View rejected applications',
                        onTap: () => _navigateToApplications('rejected'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // 2. Progress Ring Card
                ProgressRingCard(
                  progress: latestProgress,
                  companyName: latestInternship?.companyName ?? 'Internship Journey',
                  roleTitle: latestInternship?.title,
                  isApproved: approvedInternship != null,
                  onTap: _openReports,
                  onLogProgress: approvedInternship != null
                      ? () => _openApplicationDetail(approvedInternship, tabIndex: 2)
                      : null,
                ),
                const SizedBox(height: 20),

                // 3. Quick Actions Row (Browse Internships, Upload Document, View Report)
                Text(
                  'Quick Actions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    _QuickActionTile(
                      icon: Icons.explore_outlined,
                      label: 'Browse',
                      subtitle: 'Find roles',
                      color: const Color(0xFF3B82F6),
                      onTap: widget.onApply,
                    ),
                    const SizedBox(width: 10),
                    _QuickActionTile(
                      icon: Icons.upload_file_outlined,
                      label: 'Upload Doc',
                      subtitle: 'Resume & NOC',
                      color: const Color(0xFF10B981),
                      onTap: () {
                        if (items.isNotEmpty) {
                          _openApplicationDetail(items.first, tabIndex: 1);
                        } else {
                          showSnack(context, 'Please apply for an internship first.');
                        }
                      },
                    ),
                    const SizedBox(width: 10),
                    _QuickActionTile(
                      icon: Icons.pie_chart_outline,
                      label: 'View Report',
                      subtitle: 'PDF & analytics',
                      color: AppTheme.saffron,
                      onTap: _openReports,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // 4. Recent Internships Header & List
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Recent Internships',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: isDark ? Colors.white : AppTheme.ink,
                      ),
                    ),
                    TextButton(
                      onPressed: () => _navigateToApplications('all'),
                      child: const Text('See all'),
                    ),
                  ],
                ),
                const SizedBox(height: 6),

                if (items.isEmpty)
                  EmptyStateView(
                    icon: Icons.work_outline,
                    title: 'No applications submitted',
                    description: 'Explore opportunities and apply to begin tracking.',
                    actionLabel: 'Apply for an internship',
                    onAction: _openApplyForm,
                  )
                else
                  ...items.take(3).map(
                        (i) => Card(
                          elevation: 0,
                          margin: const EdgeInsets.only(bottom: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                            side: BorderSide(
                              color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                            ),
                          ),
                          child: InkWell(
                            borderRadius: BorderRadius.circular(14),
                            onTap: () => _openApplicationDetail(i),
                            child: Padding(
                              padding: const EdgeInsets.all(14),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: isDark
                                        ? const Color(0xFF1E293B)
                                        : const Color(0xFFEFF6FF),
                                    child: const Icon(Icons.business_outlined, color: AppTheme.ink),
                                  ),
                                  const SizedBox(width: 14),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          i.title,
                                          style: const TextStyle(fontWeight: FontWeight.w700),
                                        ),
                                        const SizedBox(height: 2),
                                        Text(
                                          '${i.companyName} · ${fmtDate(i.startDate)}',
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  StatusChip(status: i.status),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.chevron_right, size: 18, color: Colors.grey),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                const SizedBox(height: 20),

                // 5. Recent Activity Feed (built from notifications)
                Text(
                  'Recent Activity',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: isDark ? Colors.white : AppTheme.ink,
                  ),
                ),
                const SizedBox(height: 8),

                FutureBuilder<List<AppNotification>>(
                  future: _notifFuture,
                  builder: (context, notifSnap) {
                    final notifs = notifSnap.data ?? [];
                    if (notifs.isEmpty) {
                      return Card(
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                          side: BorderSide(
                            color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                          ),
                        ),
                        child: const Padding(
                          padding: EdgeInsets.all(18),
                          child: Center(
                            child: Text(
                              'No recent activity yet.',
                              style: TextStyle(fontSize: 12, color: Colors.grey),
                            ),
                          ),
                        ),
                      );
                    }

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                        side: BorderSide(
                          color: isDark ? Colors.grey.shade800 : Colors.grey.shade300,
                        ),
                      ),
                      child: Column(
                        children: [
                          for (int i = 0; i < notifs.take(3).length; i++) ...[
                            ListTile(
                              leading: CircleAvatar(
                                backgroundColor: isDark
                                    ? const Color(0xFF1E293B)
                                    : const Color(0xFFF1F5F9),
                                child: Icon(
                                  _iconForType(notifs[i].type),
                                  size: 18,
                                  color: AppTheme.ink,
                                ),
                              ),
                              title: Text(
                                notifs[i].title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              subtitle: Text(
                                notifs[i].body,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11),
                              ),
                              trailing: Text(
                                _timeAgo(notifs[i].createdAt),
                                style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                              ),
                              onTap: () {
                                final linkedId = notifs[i].internshipId;
                                if (linkedId != null) {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) =>
                                          InternshipDetailScreen(internshipId: linkedId),
                                    ),
                                  );
                                }
                              },
                            ),
                            if (i < notifs.take(3).length - 1) const Divider(height: 1),
                          ],
                        ],
                      ),
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openApplyForm,
        icon: const Icon(Icons.add),
        label: const Text('Apply'),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(color: isDark ? Colors.grey.shade800 : Colors.grey.shade300),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CircleAvatar(
                  radius: 16,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, size: 18, color: color),
                ),
                const SizedBox(height: 8),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10,
                    color: isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
