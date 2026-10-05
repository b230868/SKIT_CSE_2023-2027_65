import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notification_models.dart';

/// UI-facing reads for this week's design pass.
/// Automatic notification creation (on approval, new document, etc.)
/// is wired up in the next milestone, once the interfaces are approved.
class NotificationService {
  final SupabaseClient _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<List<AppNotification>> list() async {
    final rows = await _db
        .from('notifications')
        .select()
        .eq('user_id', _uid)
        .order('created_at', ascending: false);
    return rows.map<AppNotification>((r) => AppNotification.fromMap(r)).toList();
  }

  Future<int> unreadCount() async {
    final rows =
        await _db.from('notifications').select('id').eq('user_id', _uid).eq('is_read', false);
    return rows.length;
  }

  Future<void> markRead(String id) async {
    await _db.from('notifications').update({'is_read': true}).eq('id', id);
  }

  Future<void> markAllRead() async {
    await _db.from('notifications').update({'is_read': true}).eq('user_id', _uid).eq('is_read', false);
  }
}
