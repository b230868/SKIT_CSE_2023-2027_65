import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/internship_model.dart';

class InternshipService {
  final SupabaseClient _client = Supabase.instance.client;

  Future<void> _ensureProfileExists(String studentId) async {
    try {
      final existing = await _client
          .from('profiles')
          .select('id')
          .eq('id', studentId)
          .maybeSingle();
      if (existing == null) {
        final user = _client.auth.currentUser;
        final meta = user?.userMetadata ?? {};
        final fullName = (meta['full_name'] ?? meta['name'] ?? 'Student').toString().trim();
        final role = meta['role']?.toString().trim() ?? 'student';
        final enrollmentNo = meta['enrollment_no']?.toString().trim() ?? meta['roll_number']?.toString().trim();
        final branch = meta['branch']?.toString().trim() ?? 'CSE';

        final payload = <String, dynamic>{
          'id': studentId,
          'full_name': fullName,
          'role': role,
          'branch': branch,
          'department': branch,
        };
        if (enrollmentNo != null && enrollmentNo.isNotEmpty) {
          payload['enrollment_no'] = enrollmentNo;
        }
        if (user?.email != null) {
          payload['email'] = user!.email;
        }

        await _client.from('profiles').upsert(payload);
      }
    } catch (_) {
      // Non-blocking fallback
    }
  }

  // Create a new internship application
  Future<Internship> createInternship(Internship internship) async {
    await _ensureProfileExists(internship.studentId);
    final response = await _client
        .from('internships')
        .insert(internship.toMap())
        .select()
        .single();
    return Internship.fromMap(response);
  }

  // Get all internships for a specific student
  Future<List<Internship>> getStudentInternships(String studentId) async {
    final response = await _client
        .from('internships')
        .select()
        .eq('student_id', studentId);
    return (response as List).map((e) => Internship.fromMap(e)).toList();
  }

  // Upload document for an internship (Sprint 2 Task)
  Future<void> uploadDocument(String internshipId, String docType, String fileUrl) async {
    await _client.from('internship_documents').insert({
      'internship_id': internshipId,
      'document_type': docType,
      'file_url': fileUrl,
    });
  }
}