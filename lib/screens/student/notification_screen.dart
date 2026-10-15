import 'package:flutter/material.dart';

import '../../models/notification_models.dart';
import '../../services/notification_service.dart';

IconData _iconFor(String type) => switch (type) {
  'application' => Icons.assignment_turned_in_outlined,
  'document' => Icons.description_outlined,
  'progress' => Icons.timeline,
  _ => Icons.notifications_outlined,
};

/// UI design for the notifications list. Entries are read from the
/// `notifications` table; the events that create them are added next week.
class NotificationsScreen extends StatefulWidget {
  final NotificationDataSource? service;
  const NotificationsScreen({super.key, this.service});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  late final NotificationDataSource _svc;
  late Future<List<AppNotification>> _future;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? NotificationService();
    _future = _svc.list();
  }

  Future<void> _refresh() async {
    setState(() {
      _future = _svc.list();
    });
    await _future.catchError((_) => <AppNotification>[]);
  }

  Future<void> _onTap(AppNotification n) async {
    if (!n.isRead) {
      try {
        await _svc.markRead(n.id);
        if (mounted) _refresh();
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the notification.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          TextButton(
            onPressed: () async {
              try {
                await _svc.markAllRead();
                if (mounted) _refresh();
              } catch (_) {
                if (!context.mounted) return;
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Could not update notifications.'),
                  ),
                );
              }
            },
            child: const Text('Mark all read'),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AppNotification>>(
          future: _future,
          builder: (context, s) {
            if (s.connectionState != ConnectionState.done) {
              return const Center(child: CircularProgressIndicator());
            }
            if (s.hasError) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(
                    child: Text(
                      'Could not load notifications. Pull down to retry.',
                    ),
                  ),
                ],
              );
            }
            final list = s.data!;
            if (list.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 160),
                  Center(child: Text('No notifications yet.')),
                ],
              );
            }
            return ListView.separated(
              itemCount: list.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) {
                final n = list[i];
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: n.isRead
                        ? Theme.of(context).colorScheme.surfaceContainerHighest
                        : Theme.of(context).colorScheme.primaryContainer,
                    child: Icon(_iconFor(n.type)),
                  ),
                  title: Text(
                    n.title,
                    style: TextStyle(
                      fontWeight: n.isRead
                          ? FontWeight.normal
                          : FontWeight.bold,
                    ),
                  ),
                  subtitle: Text(n.body),
                  trailing: n.isRead
                      ? null
                      : const Icon(Icons.circle, size: 10, color: Colors.blue),
                  onTap: () => _onTap(n),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

/// Small bell icon with an unread badge, meant for the dashboard AppBar.
class NotificationBell extends StatefulWidget {
  final NotificationDataSource? service;
  const NotificationBell({super.key, this.service});

  @override
  State<NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends State<NotificationBell> {
  late final NotificationDataSource _svc;
  late Future<int> _count;

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? NotificationService();
    _count = _svc.unreadCount();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _count,
      builder: (context, s) {
        final n = s.data ?? 0;
        return IconButton(
          tooltip: 'Notifications',
          icon: Badge(
            label: Text('$n'),
            isLabelVisible: n > 0,
            child: const Icon(Icons.notifications_outlined),
          ),
          onPressed: () async {
            await Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => NotificationsScreen(service: _svc),
              ),
            );
            if (mounted) {
              setState(() {
                _count = _svc.unreadCount();
              });
            }
          },
        );
      },
    );
  }
}
