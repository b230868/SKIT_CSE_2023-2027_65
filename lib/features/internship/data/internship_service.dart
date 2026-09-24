import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/utils.dart';
import '../models/internship.dart';

class InternshipService {
  static const _bucket = 'internship-docs';
  final SupabaseClient _c = Supabase.instance.client;

  String get _uid => _c.auth.currentUser!.id;

  // ---------- internships ----------
  Future<List<Internship>> fetchMine() async {
    final data = await _c
        .from('internships')
        .select()
        .eq('student_id', _uid)
        .order('created_at', ascending: false);
    return data.map<Internship>(Internship.fromMap).toList();
  }

  Future<Internship> fetchOne(String id) async {
    final data = await _c.from('internships').select().eq('id', id).single();
    return Internship.fromMap(data);
  }

  Future<void> create({
    required String companyName,
    required String title,
    String? description,
    required String mode,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _c.from('internships').insert({
      'student_id': _uid,
      'company_name': companyName,
      'title': title,
      'description': description,
      'mode': mode,
      'start_date': isoDate(startDate),
      'end_date': isoDate(endDate),
    });
  }

  Future<void> update(
    String id, {
    required String companyName,
    required String title,
    String? description,
    required String mode,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    await _c.from('internships').update({
      'company_name': companyName,
      'title': title,
      'description': description,
      'mode': mode,
      'start_date': isoDate(startDate),
      'end_date': isoDate(endDate),
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _c.from('internships').delete().eq('id', id);
  }

  // ---------- progress ----------
  Future<List<ProgressUpdate>> fetchProgress(String internshipId) async {
    final data = await _c
        .from('progress_updates')
        .select()
        .eq('internship_id', internshipId)
        .order('created_at', ascending: false);
    return data.map<ProgressUpdate>(ProgressUpdate.fromMap).toList();
  }

  Future<void> addProgress(String internshipId, String note, int percent) async {
    await _c.from('progress_updates').insert({
      'internship_id': internshipId,
      'student_id': _uid,
      'note': note,
      'percent': percent,
    });
  }

  // ---------- documents ----------
  Future<List<InternshipDocument>> fetchDocuments(String internshipId) async {
    final data = await _c
        .from('internship_documents')
        .select()
        .eq('internship_id', internshipId)
        .order('created_at', ascending: false);
    return data.map<InternshipDocument>(InternshipDocument.fromMap).toList();
  }

  String _contentType(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  Future<void> uploadDocument(String internshipId, PlatformFile file) async {
    final bytes = file.bytes;
    if (bytes == null) throw Exception('Could not read the selected file');

    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$_uid/$internshipId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _c.storage.from(_bucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(contentType: _contentType(file.extension)),
        );

    await _c.from('internship_documents').insert({
      'internship_id': internshipId,
      'student_id': _uid,
      'file_name': file.name,
      'file_path': path,
    });
  }

  Future<String> signedUrl(String path) {
    return _c.storage.from(_bucket).createSignedUrl(path, 3600);
  }

  Future<void> deleteDocument(InternshipDocument doc) async {
    await _c.storage.from(_bucket).remove([doc.filePath]);
    await _c.from('internship_documents').delete().eq('id', doc.id);
  }
}
