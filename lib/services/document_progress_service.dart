import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DocumentItem {
  final String id, docType, fileName;
  final DateTime uploadedAt;
  const DocumentItem(this.id, this.docType, this.fileName, this.uploadedAt);

  factory DocumentItem.fromMap(Map<String, dynamic> m) => DocumentItem(
        m['id'] as String,
        m['doc_type'] as String,
        m['file_name'] as String,
        DateTime.parse(m['uploaded_at'] as String),
      );
}

class ProgressLog {
  final String id, summary;
  final int weekNo, progress;
  const ProgressLog(this.id, this.weekNo, this.progress, this.summary);

  factory ProgressLog.fromMap(Map<String, dynamic> m) => ProgressLog(
        m['id'] as String,
        m['week_no'] as int,
        m['progress'] as int,
        (m['summary'] ?? '') as String,
      );
}

class DocumentProgressService {
  final SupabaseClient _db = Supabase.instance.client;
  String get _uid => _db.auth.currentUser!.id;

  Future<List<DocumentItem>> documents(String internshipId) async {
    final rows = await _db
        .from('documents')
        .select()
        .eq('internship_id', internshipId)
        .order('uploaded_at', ascending: false);
    return rows.map<DocumentItem>((r) => DocumentItem.fromMap(r)).toList();
  }

  Future<void> upload(
    String internshipId,
    String docType,
    PlatformFile file,
  ) async {
    final safe = file.name.replaceAll(RegExp(r'[^\w.\-]'), '_');
    final path =
        '$_uid/$internshipId/${DateTime.now().millisecondsSinceEpoch}_$safe';
    await _db.storage.from('documents').uploadBinary(
          path,
          await file.readAsBytes(),
        );
    await _db.from('documents').insert({
      'internship_id': internshipId,
      'student_id': _uid,
      'doc_type': docType,
      'file_name': file.name,
      'file_path': path,
    });
  }

  Future<List<ProgressLog>> progress(String internshipId) async {
    final rows = await _db
        .from('progress_logs')
        .select()
        .eq('internship_id', internshipId)
        .order('week_no', ascending: false);
    return rows.map<ProgressLog>((r) => ProgressLog.fromMap(r)).toList();
  }

  Future<void> addProgress(
    String internshipId,
    int week,
    int progress,
    String summary,
  ) async {
    await _db.from('progress_logs').insert({
      'internship_id': internshipId,
      'student_id': _uid,
      'week_no': week,
      'progress': progress,
      'summary': summary,
    });
  }
}
