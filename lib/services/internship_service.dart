import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/internship_model.dart';

class InternshipService {
  final SupabaseClient _client = Supabase.instance.client;

  // Create a new internship application
  Future<Internship> createInternship(Internship internship) async {
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