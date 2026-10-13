import 'package:flutter/material.dart';

import '../../models/notification_models.dart';
import '../../services/notification_service.dart';

IconData _iconFor(String type) => switch (type) {
  'application' => Icons.assignment_turned_in_outlined,
  'document' => Icons.description_outlined,
  'progress' => Icons.timeline,
  _ => Icons.notifications_outlined,
};

/// Now backed by a live stream: approvals, rejections and other events
/// created by the database triggers appear here instantly.
class NotificationScreen extends StatefulWidget {
  final NotificationDataSource? service;
  const NotificationScreen({super.key, this.service});

  @override
  State<NotificationScreen> createState() => _NotificationScreenState();
}

class _NotificationScreenState extends State<NotificationScreen> {
  late final NotificationDataSource _svc;
  late final Stream<List<AppNotification>> _stream = _svc.watch();

  @override
  void initState() {
    super.initState();
    _svc = widget.service ?? NotificationService();
  }

  Future<void> _onTap(AppNotification n) async {
    if (!n.isRead) {
      try {
        await _svc.markRead(n.id);
      } catch (_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not update the notification.')),
        );
      }
    }
  }

  Future<void> _markAllRead() async {
    try {
      await _svc.markAllRead();
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not update notifications.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
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
          final list = s.data ?? const <AppNotification>[];
          if (list.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
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
                    fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold,
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
            .where((n) => !n.isRead)
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
