import 'package:flutter/material.dart';

import 'alerts_screen.dart';

import '../../features/internship/presentation/internship_detail_screen.dart';
import '../../features/placement/presentation/screens/placement_notice_detail_screen.dart';
import '../../features/placement/presentation/screens/student_placements_hub_screen.dart';
import '../../models/notification_models.dart';
import '../../services/notification_cache_service.dart';
import '../../services/notification_service.dart';

IconData _iconFor(String type) => switch (type) {
  'application' => Icons.assignment_turned_in_outlined,
  'document' => Icons.description_outlined,
  'progress' => Icons.timeline,
  'placement' => Icons.campaign_outlined,
  'query' => Icons.question_answer_outlined,
  'noc' => Icons.verified_outlined,
  _ => Icons.notifications_outlined,
};

/// Integrated workflow: tapping a notification marks it read and opens the
/// related application (documents / progress). Swipe left to delete.
class NotificationScreen extends StatefulWidget {
  final NotificationDataSource? service;

  const NotificationScreen({super.key, this.service});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final NotificationDataSource _svc;
  late final Stream<List<AppNotification>> _stream;
  final Set<String> _hidden =
      {}; // dismissed locally until the stream catches up
  final Set<String> _readLocally = {};
  List<AppNotification> _currentList = const [];

  bool _isRead(AppNotification n) =>
      n.isRead ||
      _readLocally.contains(n.id) ||
      NotificationCacheService.isReadLocally(n.id);

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? NotificationService();
    _stream = _svc.watch();
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _open(AppNotification n) async {
    if (!_isRead(n)) {
      setState(() => _readLocally.add(n.id));
      try {
        await _svc.markRead(n.id);
      } catch (_) {
        _toast('Could not mark the notification as read.');
      }
    }
    final noticeId = n.noticeId;
    if (noticeId != null && noticeId.isNotEmpty) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PlacementNoticeDetailScreen(noticeId: noticeId),
        ),
      );
      return;
    }

    if (n.type == 'query' || n.queryId != null) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const StudentPlacementsHubScreen(initialTabIndex: 1),
        ),
      );
      return;
    }

    if (n.type == 'noc' || n.nocRequestId != null) {
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => const StudentPlacementsHubScreen(initialTabIndex: 2),
        ),
      );
      return;
    }

    final internshipId = n.internshipId;
    if (internshipId == null) return;
    try {
      final internship = await _svc.internshipFor(internshipId);
      if (!mounted) return;
      if (internship == null) {
        return _toast('That internship is no longer available.');
      }
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InternshipDetailScreen(internshipId: internship.id),
        ),
      );
    } catch (_) {
      _toast('Could not open the internship. Try again.');
    }
  }

  Future<void> _markAllRead() async {
    setState(() {
      for (final n in _currentList) {
        _readLocally.add(n.id);
      }
    });
    try {
      await _svc.markAllRead();
      _toast('All notifications marked as read.');
    } catch (_) {
      _toast('Could not mark notifications as read.');
    }
  }

  Future<void> _delete(AppNotification n) async {
    setState(() => _hidden.add(n.id));
    try {
      await _svc.delete(n.id);
    } catch (_) {
      if (mounted) setState(() => _hidden.remove(n.id));
      _toast('Could not delete the notification.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          IconButton(
            tooltip: 'View Alerts',
            icon: const Icon(Icons.warning_amber_rounded),
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const AlertsScreen()),
            ),
          ),
          TextButton(
            onPressed: _markAllRead,
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: StreamBuilder<List<AppNotification>>(
        stream: _stream,
        builder: (context, s) {
          if (s.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (s.hasError) {
            return const Center(child: Text('Could not load notifications.'));
          }
          final list = (s.data ?? const <AppNotification>[])
              .where((n) => !_hidden.contains(n.id))
              .toList();
          _currentList = list;
          if (list.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = list[i];
              final isRead = _isRead(n);
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: scheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: Icon(
                    Icons.delete_outline,
                    color: scheme.onErrorContainer,
                  ),
                ),
                onDismissed: (_) => _delete(n),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isRead
                        ? scheme.surfaceContainerHighest
                        : scheme.primaryContainer,
                    child: Icon(_iconFor(n.type)),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(n.body),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (!isRead)
                        IconButton(
                          tooltip: 'Mark as read',
                          icon: const Icon(Icons.done_all, size: 20, color: Colors.blue),
                          onPressed: () async {
                            setState(() => _readLocally.add(n.id));
                            await _svc.markRead(n.id);
                          },
                        ),
                      if (n.internshipId != null ||
                          n.noticeId != null ||
                          n.queryId != null ||
                          n.nocRequestId != null)
                        const Icon(Icons.chevron_right)
                      else if (!isRead)
                        const Icon(
                          Icons.circle,
                          size: 10,
                          color: Colors.blue,
                        ),
                    ],
                  ),
                  onTap: () => _open(n),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

/// Bell icon with a live unread badge. Place it in an AppBar's actions.
class NotificationBell extends StatelessWidget {
  final NotificationDataSource? service;

  const NotificationBell({super.key, this.service});

  @override
  Widget build(BuildContext context) {
    final svc = service ?? NotificationService();
    return StreamBuilder<List<AppNotification>>(
      stream: svc.watch(),
      builder: (context, s) {
        final unread = (s.data ?? const <AppNotification>[])
            .where((n) => !n.isRead && !NotificationCacheService.isReadLocally(n.id))
            .length;
        return IconButton(
          tooltip: 'Notifications',
          icon: Badge(
            label: Text('$unread'),
            isLabelVisible: unread > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => NotificationScreen(service: svc)),
          ),
        );
      },
    );
  }
}

typedef NotificationsScreen = NotificationScreen;
