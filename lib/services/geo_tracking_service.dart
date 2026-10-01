import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/geo_checkin_model.dart';

class GeoTrackingService {
  final SupabaseClient _client = Supabase.instance.client;

  // Submit a GPS check-in (Sprint 3 Task)
  Future<GeoCheckIn> submitCheckIn(GeoCheckIn checkIn) async {
    final response = await _client
        .from('geo_checkins')
        .insert(checkIn.toMap())
        .select()
        .single();
    return GeoCheckIn.fromMap(response);
  }

  // Get tracking history for an internship
  Future<List<GeoCheckIn>> getCheckInsForInternship(String internshipId) async {
    final response = await _client
        .from('geo_checkins')
        .select()
        .eq('internship_id', internshipId)
        .order('check_in_time', ascending: false);
    return (response as List).map((e) => GeoCheckIn.fromMap(e)).toList();
  }
}