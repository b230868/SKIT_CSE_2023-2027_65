import 'package:flutter/material.dart';

import '../../features/internship/presentation/internship_detail_screen.dart';
import '../../models/notification_models.dart';
import '../../services/notification_cache_service.dart';

class AlertsScreen extends StatefulWidget {
  const AlertsScreen({super.key, this.onOpenInternship});

  /// Called when a notification linked to an internship is tapped.
  final void Function(String internshipId)? onOpenInternship;

  @override
  State<AlertsScreen> createState() => _AlertsScreenState();
}

class _AlertsScreenState extends State<AlertsScreen> {
  final _service = NotificationCacheService();
  late final Stream<List<AppNotification>> _stream;

  final _hidden = <String>{}; // deleted, waiting for the server
  final _readLocally = <String>{}; // read, waiting for the server
  List<AppNotification> _latest = const [];

  @override
  void initState() {
    super.initState();
    _stream = _service.watch();
  }

  bool _isRead(AppNotification n) => n.isRead || _readLocally.contains(n.id);

  Future<void> _markAll() async {
    final ids = _latest
        .where((n) => n.type == 'alert' && !_isRead(n))
        .map((n) => n.id)
        .toList();
    setState(() => _readLocally.addAll(ids));
    for (final id in ids) {
      await _service.markAsRead(id); // only alerts, not other notifications
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('All alerts marked as read')),
    );
  }

  Future<void> _open(AppNotification n) async {
    if (!_isRead(n)) {
      setState(() => _readLocally.add(n.id));
      await _service.markAsRead(n.id);
    }
    final internshipId = n.internshipId;
    if (internshipId != null) {
      if (widget.onOpenInternship != null) {
        widget.onOpenInternship!(internshipId);
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (_) => InternshipDetailScreen(internshipId: internshipId),
          ),
        );
      }
    }
  }

  Future<void> _delete(AppNotification n) async {
    setState(() => _hidden.add(n.id));
    try {
      await _service.delete(n.id);
    } catch (_) {
      if (!mounted) return;
      setState(() => _hidden.remove(n.id));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not delete. Check your connection.')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Alerts'),
        actions: [
          IconButton(
            icon: const Icon(Icons.done_all),
            tooltip: 'Mark all as read',
            onPressed: _markAll,
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<List<AppNotification>>(
              stream: _stream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                final all = snapshot.data!
                    .where((n) => !_hidden.contains(n.id))
                    .toList();
                _latest = all;

                final items = all.where((n) => n.type == 'alert').toList();
                final unread = items.where((n) => !_isRead(n)).length;

                return RefreshIndicator(
                  onRefresh: () => _service.fetchNotifications(),
                  child: items.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Icon(Icons.notifications_none, size: 56),
                            SizedBox(height: 12),
                            Center(child: Text('No alerts right now')),
                          ],
                        )
                      : ListView.separated(
                          itemCount: items.length + 1,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            if (index == 0) {
                              return Padding(
                                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                                child: Text(
                                  unread == 0
                                      ? 'You are all caught up'
                                      : '$unread unread',
                                  style: Theme.of(context).textTheme.labelLarge,
                                ),
                              );
                            }
                            return _tile(context, items[index - 1]);
                          },
                        ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(BuildContext context, AppNotification n) {
    final scheme = Theme.of(context).colorScheme;
    final read = _isRead(n);

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
        onTap: () => _open(n),
        leading: CircleAvatar(
          backgroundColor: n.type == 'alert'
              ? scheme.errorContainer
              : scheme.primaryContainer,
          child: Icon(
            _iconFor(n.type),
            color: n.type == 'alert'
                ? scheme.onErrorContainer
                : scheme.onPrimaryContainer,
          ),
        ),
        title: Text(
          n.title,
          style: TextStyle(
            fontWeight: read ? FontWeight.normal : FontWeight.bold,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (n.body.isNotEmpty) Text(n.body),
            const SizedBox(height: 2),
            Text(_timeAgo(n.createdAt), style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
        isThreeLine: n.body.isNotEmpty,
        trailing: read
            ? null
            : Icon(Icons.circle, size: 10, color: scheme.primary),
      ),
    );
  }

  IconData _iconFor(String type) {
    switch (type) {
      case 'application':
        return Icons.assignment_turned_in_outlined;
      case 'document':
        return Icons.description_outlined;
      case 'progress':
        return Icons.trending_up;
      case 'alert':
        return Icons.warning_amber_rounded;
      default:
        return Icons.notifications_none;
    }
  }

  String _timeAgo(DateTime time) {
    final diff = DateTime.now().difference(time.toLocal());
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
    if (diff.inHours < 24) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    final t = time.toLocal();
    return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}/${t.year}';
  }
}
