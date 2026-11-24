import 'package:flutter/material.dart';

import '../../../core/theme.dart';
import '../../../models/notification_models.dart';
import '../../../screens/student/notification_screen.dart';
import '../../../services/notification_service.dart';
import '../../internship/presentation/internship_detail_screen.dart';

/// Notification bell with live unread badge.
/// Tapping it opens a quick preview modal of the top 5 notifications
/// with inline mark-as-read and a "See all" link.
class StudentNotificationBell extends StatelessWidget {
  final NotificationDataSource? service;

  const StudentNotificationBell({super.key, this.service});

  @override
  Widget build(BuildContext context) {
    final svc = service ?? NotificationService();

    return StreamBuilder<List<AppNotification>>(
      stream: svc.watch(),
      builder: (context, snapshot) {
        final notifications = snapshot.data ?? const <AppNotification>[];
        final unreadCount = notifications.where((n) => !n.isRead).length;

        return IconButton(
          tooltip: 'Notifications ($unreadCount unread)',
          icon: Badge(
            label: Text('$unreadCount'),
            isLabelVisible: unreadCount > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () => _showQuickPreview(context, svc, notifications),
        );
      },
    );
  }

  void _showQuickPreview(
    BuildContext context,
    NotificationDataSource svc,
    List<AppNotification> notifications,
  ) {
    final isWide = MediaQuery.of(context).size.width >= 600;

    if (isWide) {
      showDialog(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480, maxHeight: 580),
            child: _QuickPreviewSheet(
              service: svc,
              notifications: notifications,
            ),
          ),
        ),
      );
    } else {
      showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => FractionallySizedBox(
          heightFactor: 0.75,
          child: _QuickPreviewSheet(service: svc, notifications: notifications),
        ),
      );
    }
  }
}

class _QuickPreviewSheet extends StatefulWidget {
  final NotificationDataSource service;
  final List<AppNotification> notifications;

  const _QuickPreviewSheet({
    required this.service,
    required this.notifications,
  });

  @override
  State<_QuickPreviewSheet> createState() => _QuickPreviewSheetState();
}

class _QuickPreviewSheetState extends State<_QuickPreviewSheet> {
  final Set<String> _readLocally = {};

  bool _isRead(AppNotification n) => n.isRead || _readLocally.contains(n.id);

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    return '${dt.day}/${dt.month}/${dt.year}';
  }

  IconData _iconFor(String type) => switch (type.toLowerCase()) {
    'application' => Icons.assignment_turned_in_outlined,
    'document' => Icons.description_outlined,
    'progress' => Icons.timeline,
    'alert' => Icons.warning_amber_rounded,
    _ => Icons.notifications_outlined,
  };

  Future<void> _markRead(String id) async {
    setState(() => _readLocally.add(id));
    try {
      await widget.service.markRead(id);
    } catch (_) {}
  }

  Future<void> _markAllRead(List<AppNotification> items) async {
    setState(() {
      for (final item in items) {
        _readLocally.add(item.id);
      }
    });
    try {
      await widget.service.markAllRead();
    } catch (_) {}
  }

  Future<void> _handleTap(AppNotification n) async {
    if (!_isRead(n)) {
      await _markRead(n.id);
    }
    if (!mounted) return;
    Navigator.of(context).pop();

    final internshipId = n.internshipId;
    if (internshipId != null) {
      try {
        final internship = await widget.service.internshipFor(internshipId);
        if (mounted && internship != null) {
          await Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) =>
                  InternshipDetailScreen(internshipId: internship.id),
            ),
          );
        }
      } catch (_) {}
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final top5 = widget.notifications.take(5).toList();
    final hasUnread = top5.any((n) => !_isRead(n));

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 16, 12),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  'Notifications',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: isDark ? Colors.white : AppTheme.ink,
                  ),
                ),
              ),
              if (hasUnread)
                TextButton.icon(
                  onPressed: () => _markAllRead(top5),
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text(
                    'Mark all read',
                    style: TextStyle(fontSize: 12),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.blue.shade700,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                  ),
                ),
              IconButton(
                icon: const Icon(Icons.close, size: 20),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
        ),
        const Divider(height: 1),

        // Notifications List or Empty State
        Expanded(
          child: top5.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.notifications_none,
                        size: 48,
                        color: Colors.grey.shade400,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'No notifications yet',
                        style: TextStyle(
                          color: isDark
                              ? Colors.grey.shade400
                              : Colors.grey.shade600,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: top5.length,
                  separatorBuilder: (_, _) =>
                      const Divider(height: 1, indent: 64),
                  itemBuilder: (context, i) {
                    final n = top5[i];
                    final read = _isRead(n);

                    return ListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 4,
                      ),
                      leading: CircleAvatar(
                        backgroundColor: read
                            ? (isDark
                                  ? Colors.grey.shade800
                                  : Colors.grey.shade200)
                            : (isDark
                                  ? const Color(0xFF1E293B)
                                  : const Color(0xFFEFF6FF)),
                        child: Icon(
                          _iconFor(n.type),
                          size: 20,
                          color: read ? Colors.grey : AppTheme.ink,
                        ),
                      ),
                      title: Text(
                        n.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: read ? FontWeight.w500 : FontWeight.w700,
                          color: isDark ? Colors.white : AppTheme.ink,
                        ),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 2),
                          Text(
                            n.body,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark
                                  ? Colors.grey.shade400
                                  : Colors.grey.shade700,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _timeAgo(n.createdAt),
                            style: TextStyle(
                              fontSize: 10,
                              color: isDark
                                  ? Colors.grey.shade500
                                  : Colors.grey.shade500,
                            ),
                          ),
                        ],
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (!read)
                            IconButton(
                              icon: const Icon(
                                Icons.check_circle_outline,
                                size: 20,
                              ),
                              tooltip: 'Mark as read',
                              color: Colors.blue,
                              onPressed: () => _markRead(n.id),
                            ),
                          if (n.internshipId != null)
                            const Icon(Icons.chevron_right, size: 18),
                        ],
                      ),
                      onTap: () => _handleTap(n),
                    );
                  },
                ),
        ),

        // Footer with "See all notifications"
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Showing latest ${top5.length} items',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                ),
              ),
              FilledButton.tonalIcon(
                onPressed: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          NotificationScreen(service: widget.service),
                    ),
                  );
                },
                icon: const Icon(Icons.open_in_new, size: 14),
                label: const Text('See all notifications'),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  textStyle: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
