import 'package:flutter/material.dart';
import '../../models/notification_models.dart';
import '../../services/notification_service.dart';
import 'application_detail_screen.dart';

IconData _iconFor(String type) => switch (type) {
      'application' => Icons.assignment_turned_in_outlined,
      'document' => Icons.description_outlined,
      'progress' => Icons.timeline,
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
  final Set<String> _hidden = {}; // dismissed locally until the stream catches up

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
    if (!n.isRead) await _svc.markRead(n.id).catchError((_) {});
    final appId = n.applicationId;
    if (appId == null) return;
    try {
      final app = await _svc.applicationFor(appId);
      if (!mounted) return;
      if (app == null) return _toast('That application is no longer available.');
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ApplicationDetailScreen(application: app)),
      );
    } catch (_) {
      _toast('Could not open the application. Try again.');
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
          TextButton(
            onPressed: () => _svc.markAllRead().catchError((_) {}),
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
          if (list.isEmpty) {
            return const Center(child: Text('No notifications yet.'));
          }
          return ListView.separated(
            itemCount: list.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final n = list[i];
              return Dismissible(
                key: ValueKey(n.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: scheme.errorContainer,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  child: Icon(Icons.delete_outline, color: scheme.onErrorContainer),
                ),
                onDismissed: (_) => _delete(n),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor:
                        n.isRead ? scheme.surfaceContainerHighest : scheme.primaryContainer,
                    child: Icon(_iconFor(n.type)),
                  ),
                  title: Text(n.title,
                      style: TextStyle(fontWeight: n.isRead ? FontWeight.normal : FontWeight.bold)),
                  subtitle: Text(n.body),
                  trailing: n.applicationId != null
                      ? const Icon(Icons.chevron_right)
                      : (n.isRead ? null : const Icon(Icons.circle, size: 10, color: Colors.blue)),
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
        final unread = (s.data ?? const <AppNotification>[]).where((n) => !n.isRead).length;
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
