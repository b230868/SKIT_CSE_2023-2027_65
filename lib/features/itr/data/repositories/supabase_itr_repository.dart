import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/itr_model.dart';
import 'itr_repository.dart';

class SupabaseItrRepository implements ItrRepository {
  SupabaseItrRepository({SupabaseClient? client})
      : _customClient = client;

  final SupabaseClient? _customClient;

  SupabaseClient get _client =>
      _customClient ?? Supabase.instance.client;

  static const String _bucketName = 'itr-files';

  @override
  Future<List<ItrModel>> getItrs() async {
    final User? user;
    try {
      user = _client.auth.currentUser;
    } catch (_) {
      return [];
    }

    if (user == null) {
      return [];
    }

    final student = await _client
        .from('students')
        .select('id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (student == null) {
      return [];
    }

    final studentId = student['id'].toString();

    // Ensure every internship belonging to this student has at least a draft ITR record
    try {
      final internships = await _client
          .from('internships')
          .select('id')
          .eq('student_id', studentId);

      final existingItrs = await _client
          .from('itrs')
          .select('internship_id')
          .eq('student_id', studentId);

      final existingInternshipIds = (existingItrs as List)
          .map((e) => e['internship_id']?.toString())
          .whereType<String>()
          .toSet();

      for (final intern in (internships as List)) {
        final internId = intern['id']?.toString();
        if (internId != null && !existingInternshipIds.contains(internId)) {
          await _client.from('itrs').upsert(
            {
              'internship_id': internId,
              'student_id': studentId,
              'status': 'draft',
            },
            onConflict: 'internship_id',
            ignoreDuplicates: true,
          );
        }
      }
    } catch (_) {
      // Non-blocking if auto-draft creation encounters a transient issue
    }

    final data = await _client
        .from('itrs')
        .select('''
          id,
          internship_id,
          student_id,
          status,
          content,
          work_done,
          technologies_used,
          key_learnings,
          challenges_faced,
          document_path,
          project_zip_path,
          presentation_path,
          submitted_at,
          reviewer_id,
          reviewer_name,
          remarks,
          internships (
            internship_title,
            industries (
              name
            ),
            students (
              profiles (
                full_name
              )
            )
          )
        ''')
        .eq('student_id', studentId)
        .order('created_at', ascending: false);

    return data.map<ItrModel>((item) {
      return _mapItr(item);
    }).toList();
  }

  @override
  Future<ItrModel?> getItrById(String id) async {
    final itr = await _client
        .from('itrs')
        .select('''
          id,
          internship_id,
          student_id,
          status,
          content,
          work_done,
          technologies_used,
          key_learnings,
          challenges_faced,
          document_path,
          project_zip_path,
          presentation_path,
          submitted_at,
          reviewer_id,
          reviewer_name,
          remarks,
          internships (
            internship_title,
            industries (
              name
            ),
            students (
              profiles (
                full_name
              )
            )
          )
        ''')
        .eq('id', id)
        .maybeSingle();

    if (itr == null) {
      return null;
    }

    return _mapItr(itr);
  }

  ItrModel _mapItr(Map<String, dynamic> item) {
    final internshipData = item['internships'];

    String internshipTitle = 'Unknown Internship';
    String studentName = 'Unknown Student';
    String companyName = 'Unknown Company';

    if (internshipData is Map) {
      internshipTitle =
          internshipData['internship_title']?.toString() ??
          'Unknown Internship';

      final industryData = internshipData['industries'];

      if (industryData is Map) {
        companyName = industryData['name']?.toString() ?? 'Unknown Company';
      }

      final studentData = internshipData['students'];

      if (studentData is Map) {
        final profileData = studentData['profiles'];

        if (profileData is Map) {
          studentName =
              profileData['full_name']?.toString() ?? 'Unknown Student';
        }
      }
    }

    return ItrModel(
      id: item['id'].toString(),
      internshipId: item['internship_id'].toString(),
      studentId: item['student_id'].toString(),
      studentName: studentName,
      internshipTitle: internshipTitle,
      companyName: companyName,
      status: item['status']?.toString() ?? 'draft',
      content: item['content']?.toString(),
      workDone: item['work_done']?.toString(),
      technologiesUsed: item['technologies_used']?.toString(),
      keyLearnings: item['key_learnings']?.toString(),
      challengesFaced: item['challenges_faced']?.toString(),
      documentPath: item['document_path']?.toString(),
      projectZipPath: item['project_zip_path']?.toString(),
      presentationPath: item['presentation_path']?.toString(),
      submittedAt: item['submitted_at'] != null
          ? DateTime.tryParse(item['submitted_at'].toString())
          : null,
      reviewerName: item['reviewer_name']?.toString(),
      remarks: item['remarks']?.toString(),
    );
  }

  @override
  Future<void> submitItr(ItrModel itr) async {
    final effectiveContent =
        (itr.content != null && itr.content!.trim().isNotEmpty)
            ? itr.content!.trim()
            : itr.workDone?.trim();

    await _client
        .from('itrs')
        .update({
          'status': 'submitted',
          'content': effectiveContent,
          'work_done': itr.workDone,
          'technologies_used': itr.technologiesUsed,
          'key_learnings': itr.keyLearnings,
          'challenges_faced': itr.challengesFaced,
          'document_path': itr.documentPath,
          'project_zip_path': itr.projectZipPath,
          'presentation_path': itr.presentationPath,
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', itr.id)
        .select('id')
        .single();
  }

  @override
  Future<void> updateItrStatus(String id, String status) async {
    await _client
        .from('itrs')
        .update({'status': status})
        .eq('id', id)
        .select('id')
        .single();
  }

  @override
  Future<String> uploadProjectZip({
    required String itrId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final path = '$itrId/project/$fileName';

    await _client.storage
        .from(_bucketName)
        .uploadBinary(
          path,
          fileBytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return path;
  }

  @override
  Future<String> uploadProjectPresentation({
    required String itrId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final path = '$itrId/presentation/$fileName';

    await _client.storage
        .from(_bucketName)
        .uploadBinary(
          path,
          fileBytes,
          fileOptions: const FileOptions(upsert: true),
        );

    return path;
  }

  @override
  Future<String?> getFileUrl(String filePath) async {
    try {
      return await _client.storage
          .from(_bucketName)
          .createSignedUrl(filePath, 3600);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> deleteFile(String filePath) async {
    await _client.storage.from(_bucketName).remove([filePath]);
  }

  Future<String?> _getIndustryId() async {
    final User? user;
    try {
      user = _client.auth.currentUser;
    } catch (_) {
      return null;
    }
    if (user == null) return null;

    final row = await _client
        .from('industry_users')
        .select('industry_id')
        .eq('user_id', user.id)
        .maybeSingle();

    return row?['industry_id']?.toString();
  }

  @override
  Future<List<ItrModel>> getIndustryItrs() async {
    final industryId = await _getIndustryId();
    if (industryId == null) {
      return [];
    }

    final internshipRows = await _client
        .from('internships')
        .select('id')
        .eq('industry_id', industryId);

    final internshipIds = (internshipRows as List)
        .map((r) => r['id'].toString())
        .toList();

    if (internshipIds.isEmpty) {
      return [];
    }

    final data = await _client
        .from('itrs')
        .select('''
          id,
          internship_id,
          student_id,
          status,
          content,
          work_done,
          technologies_used,
          key_learnings,
          challenges_faced,
          document_path,
          project_zip_path,
          presentation_path,
          submitted_at,
          reviewer_id,
          reviewer_name,
          remarks,
          internships (
            internship_title,
            industries (
              name
            ),
            students (
              profiles (
                full_name
              )
            )
          )
        ''')
        .inFilter('internship_id', internshipIds)
        .order('submitted_at', ascending: false);

    return data.map<ItrModel>((item) => _mapItr(item)).toList();
  }

  @override
  Future<ItrModel?> getItrByInternshipId(String internshipId) async {
    final data = await _client
        .from('itrs')
        .select('''
          id,
          internship_id,
          student_id,
          status,
          content,
          work_done,
          technologies_used,
          key_learnings,
          challenges_faced,
          document_path,
          project_zip_path,
          presentation_path,
          submitted_at,
          reviewer_id,
          reviewer_name,
          remarks,
          internships (
            internship_title,
            industries (
              name
            ),
            students (
              profiles (
                full_name
              )
            )
          )
        ''')
        .eq('internship_id', internshipId)
        .order('created_at', ascending: false)
        .limit(1);

    if (data.isEmpty) return null;
    return _mapItr(data.first);
  }

  @override
  Future<void> reviewItr({
    required String itrId,
    required String status,
    required String remarks,
    String? reviewerName,
  }) async {
    User? user;
    try {
      user = _client.auth.currentUser;
    } catch (_) {
      user = null;
    }
    final updates = <String, dynamic>{
      'status': status,
      'remarks': remarks,
      'updated_at': DateTime.now().toIso8601String(),
    };

    if (user != null) {
      updates['reviewer_id'] = user.id;
    }
    if (reviewerName != null && reviewerName.trim().isNotEmpty) {
      updates['reviewer_name'] = reviewerName.trim();
    }

    await _client
        .from('itrs')
        .update(updates)
        .eq('id', itrId)
        .select('id')
        .single();
  }
}
