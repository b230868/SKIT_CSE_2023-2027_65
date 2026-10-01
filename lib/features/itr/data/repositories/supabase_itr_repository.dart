import 'dart:typed_data';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/itr_model.dart';
import 'itr_repository.dart';

class SupabaseItrRepository implements ItrRepository {
  SupabaseItrRepository({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  static const String _bucketName = 'itr-files';

  @override
  Future<List<ItrModel>> getItrs() async {
    final user = _client.auth.currentUser;

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
        .eq('student_id', student['id'])
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
    );
  }

  @override
  Future<void> submitItr(ItrModel itr) async {
    await _client
        .from('itrs')
        .update({
          'status': 'submitted',
          'content': itr.content,
          'work_done': itr.workDone,
          'technologies_used': itr.technologiesUsed,
          'key_learnings': itr.keyLearnings,
          'challenges_faced': itr.challengesFaced,
          'document_path': itr.documentPath,
          'project_zip_path': itr.projectZipPath,
          'presentation_path': itr.presentationPath,
          'submitted_at': DateTime.now().toIso8601String(),
        })
        .eq('id', itr.id);
  }

  @override
  Future<void> updateItrStatus(String id, String status) async {
    await _client.from('itrs').update({'status': status}).eq('id', id);
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
}
