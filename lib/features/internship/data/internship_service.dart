import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/network/network_errors.dart';
import '../../../core/storage/cache_service.dart';
import '../../../core/utils.dart';
import '../models/internship.dart';

class InternshipService {
  static const _bucket = 'internship-docs';
  final SupabaseClient _c = Supabase.instance.client;

  String get _uid => _c.auth.currentUser!.id;

  // ---------- internships ----------
  Future<List<Internship>> fetchMine() async {
    final ownerId = _uid;
    try {
      final data = await _c
          .from('internships')
          .select()
          .eq('student_id', ownerId)
          .order('created_at', ascending: false);
      final internships = data.map<Internship>(Internship.fromMap).toList();
      await CacheService.cacheData(
        ownerId: ownerId,
        key: 'internships',
        data: internships.map(_internshipToMap).toList(),
      );
      return internships;
    } on Exception catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = CacheService.getCachedData(
        ownerId: ownerId,
        key: 'internships',
      );
      if (cached == null) rethrow;
      return _asMapList(cached).map(Internship.fromMap).toList();
    }
  }

  Future<Internship> fetchOne(String id) async {
    final ownerId = _uid;
    try {
      final data = await _c.from('internships').select().eq('id', id).single();
      final internship = Internship.fromMap(data);
      await CacheService.cacheData(
        ownerId: ownerId,
        key: 'internship:$id',
        data: _internshipToMap(internship),
      );
      return internship;
    } on Exception catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = CacheService.getCachedData(
        ownerId: ownerId,
        key: 'internship:$id',
      );
      if (cached == null) rethrow;
      return Internship.fromMap(Map<String, dynamic>.from(cached as Map));
    }
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
    await _invalidateInternshipCache();
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
    await _c
        .from('internships')
        .update({
          'company_name': companyName,
          'title': title,
          'description': description,
          'mode': mode,
          'start_date': isoDate(startDate),
          'end_date': isoDate(endDate),
        })
        .eq('id', id);
    await _invalidateInternshipCache(id);
  }

  Future<void> delete(String id) async {
    await _c.from('internships').delete().eq('id', id);
    await _invalidateInternshipCache(id);
  }

  // ---------- progress ----------
  Future<List<ProgressUpdate>> fetchProgress(String internshipId) async {
    final ownerId = _uid;
    try {
      final data = await _c
          .from('progress_updates')
          .select()
          .eq('internship_id', internshipId)
          .order('created_at', ascending: false);
      final updates = data.map<ProgressUpdate>(ProgressUpdate.fromMap).toList();
      await CacheService.cacheData(
        ownerId: ownerId,
        key: 'internship:$internshipId:progress',
        data: updates.map(_progressToMap).toList(),
      );
      return updates;
    } on Exception catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = CacheService.getCachedData(
        ownerId: ownerId,
        key: 'internship:$internshipId:progress',
      );
      if (cached == null) rethrow;
      return _asMapList(cached).map(ProgressUpdate.fromMap).toList();
    }
  }

  Future<void> addProgress(
    String internshipId,
    String note,
    int percent,
  ) async {
    await _c.from('progress_updates').insert({
      'internship_id': internshipId,
      'student_id': _uid,
      'note': note,
      'percent': percent,
    });
    await _invalidateInternshipCache(internshipId);
  }

  // ---------- documents ----------
  Future<List<InternshipDocument>> fetchDocuments(String internshipId) async {
    final ownerId = _uid;
    try {
      final data = await _c
          .from('internship_documents')
          .select()
          .eq('internship_id', internshipId)
          .order('created_at', ascending: false);
      final documents = data
          .map<InternshipDocument>(InternshipDocument.fromMap)
          .toList();
      await CacheService.cacheData(
        ownerId: ownerId,
        key: 'internship:$internshipId:documents',
        data: documents.map(_documentToMap).toList(),
      );
      return documents;
    } on Exception catch (error) {
      if (!isNetworkError(error)) rethrow;
      final cached = CacheService.getCachedData(
        ownerId: ownerId,
        key: 'internship:$internshipId:documents',
      );
      if (cached == null) rethrow;
      return _asMapList(cached).map(InternshipDocument.fromMap).toList();
    }
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
    final bytes = await file.readAsBytes();

    final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final path =
        '$_uid/$internshipId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

    await _c.storage
        .from(_bucket)
        .uploadBinary(
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
    await CacheService.removeCachedData(
      ownerId: _uid,
      key: 'internship:$internshipId:documents',
    );
  }

  Future<String> signedUrl(String path) {
    return _c.storage.from(_bucket).createSignedUrl(path, 3600);
  }

  Future<void> deleteDocument(
    InternshipDocument doc, {
    required String internshipId,
  }) async {
    await _c.storage.from(_bucket).remove([doc.filePath]);
    await _c.from('internship_documents').delete().eq('id', doc.id);
    await CacheService.removeCachedData(
      ownerId: _uid,
      key: 'internship:$internshipId:documents',
    );
  }

  Future<void> _invalidateInternshipCache([String? id]) async {
    final ownerId = _uid;
    await CacheService.removeCachedData(ownerId: ownerId, key: 'internships');
    if (id == null) return;
    await CacheService.removeCachedData(
      ownerId: ownerId,
      key: 'internship:$id',
    );
    await CacheService.removeCachedData(
      ownerId: ownerId,
      key: 'internship:$id:progress',
    );
    await CacheService.removeCachedData(
      ownerId: ownerId,
      key: 'internship:$id:documents',
    );
  }

  static List<Map<String, dynamic>> _asMapList(Object data) {
    if (data is! List) {
      throw const FormatException('Cached data has an invalid format.');
    }
    return data.map((item) {
      if (item is! Map) {
        throw const FormatException('Cached data has an invalid format.');
      }
      return Map<String, dynamic>.from(item);
    }).toList();
  }

  static Map<String, dynamic> _internshipToMap(Internship internship) => {
    'id': internship.id,
    'student_id': internship.studentId,
    'company_name': internship.companyName,
    'title': internship.title,
    'description': internship.description,
    'mode': internship.mode,
    'start_date': internship.startDate.toIso8601String(),
    'end_date': internship.endDate.toIso8601String(),
    'status': internship.status,
    'progress': internship.progress,
    'created_at': internship.createdAt.toIso8601String(),
  };

  static Map<String, dynamic> _progressToMap(ProgressUpdate update) => {
    'id': update.id,
    'note': update.note,
    'percent': update.percent,
    'created_at': update.createdAt.toIso8601String(),
  };

  static Map<String, dynamic> _documentToMap(InternshipDocument document) => {
    'id': document.id,
    'file_name': document.fileName,
    'file_path': document.filePath,
    'created_at': document.createdAt.toIso8601String(),
  };
}
