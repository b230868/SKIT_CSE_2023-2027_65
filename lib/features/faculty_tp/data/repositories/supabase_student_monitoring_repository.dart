import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../models/mock_student_monitoring_data.dart';
import '../models/student_monitoring_detail.dart';
import '../models/student_monitoring_item.dart';
import 'student_monitoring_repository.dart';

class SupabaseStudentMonitoringRepository
    implements StudentMonitoringRepository {
  final SupabaseClient? _providedClient;

  SupabaseStudentMonitoringRepository({
    SupabaseClient? client,
  }) : _providedClient = client;

  SupabaseClient? get _client {
    if (_providedClient != null) return _providedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<List<StudentMonitoringItem>> getStudents() async {
    final client = _client;
    if (client == null) {
      return MockStudentMonitoringData.students;
    }

    await AuthService.requireAuthenticatedClient(client: client);

    try {
      final response = await client.from('internships').select('''
        id,
        internship_title,
        status,
        company_name,
        progress,
        student_id,
        created_at,
        students (
          id,
          roll_number,
          department,
          batch_year,
          user_id,
          profiles:user_id (
            full_name,
            email,
            department,
            branch,
            phone,
            phone_number,
            address,
            avatar_url
          )
        ),
        itrs (
          id,
          status,
          content,
          project_title,
          document_path
        ),
        certificates (
          id,
          file_path,
          status,
          created_at
        ),
        approval_reviews (
          id,
          status,
          review_stage,
          remarks,
          created_at
        )
      ''').order('created_at', ascending: false);

      final items = <StudentMonitoringItem>[];

      for (final item in response as List) {
        final map = Map<String, dynamic>.from(item as Map);

        final student = map['students'] is Map
            ? Map<String, dynamic>.from(map['students'] as Map)
            : <String, dynamic>{};

        final profile = student['profiles'] is Map
            ? Map<String, dynamic>.from(student['profiles'] as Map)
            : <String, dynamic>{};

        final studentName = profile['full_name'] as String? ?? 'Unknown Student';
        final internshipTitle =
            map['internship_title'] as String? ?? 'Untitled Internship';
        final internshipId = map['id'] as String? ?? '';
        final studentId =
            map['student_id'] as String? ?? (student['id'] as String? ?? '');

        final reviews = (map['approval_reviews'] as List? ?? [])
            .map((r) => Map<String, dynamic>.from(r as Map))
            .toList();

        reviews.sort((a, b) {
          final bDate = b['created_at'] != null
              ? DateTime.tryParse(b['created_at'].toString()) ?? DateTime(1970)
              : DateTime(1970);
          final aDate = a['created_at'] != null
              ? DateTime.tryParse(a['created_at'].toString()) ?? DateTime(1970)
              : DateTime(1970);
          return bDate.compareTo(aDate);
        });

        final status = reviews.isNotEmpty
            ? (reviews.first['status'] as String? ?? 'pending')
            : (map['status'] as String? ?? 'pending');

        final bool hasPendingReview = reviews.any(
          (r) => (r['status'] as String?)?.toLowerCase() == 'pending',
        ) || (map['status'] as String?)?.toLowerCase() == 'pending';

        // Extract ITR status
        String? itrStatus;
        if (map['itrs'] is List && (map['itrs'] as List).isNotEmpty) {
          itrStatus = (map['itrs'] as List).first['status'] as String?;
        } else if (map['itrs'] is Map) {
          itrStatus = (map['itrs'] as Map)['status'] as String?;
        }

        // Extract Certificate status
        bool hasCertificate = false;
        String? certStatus;
        if (map['certificates'] is List && (map['certificates'] as List).isNotEmpty) {
          final cert = (map['certificates'] as List).first as Map;
          final filePath = cert['file_path'] as String?;
          hasCertificate = filePath != null && filePath.trim().isNotEmpty;
          certStatus = cert['status'] as String?;
        } else if (map['certificates'] is Map) {
          final filePath = (map['certificates'] as Map)['file_path'] as String?;
          hasCertificate = filePath != null && filePath.trim().isNotEmpty;
          certStatus = (map['certificates'] as Map)['status'] as String?;
        }

        final int progressVal = map['progress'] is num
            ? (map['progress'] as num).toInt()
            : 0;

        items.add(
          StudentMonitoringItem(
            studentId: studentId,
            studentName: studentName,
            internshipId: internshipId,
            internshipTitle: internshipTitle,
            applicationStatus: status,
            studentEmail: profile['email'] as String?,
            rollNumber: student['roll_number'] as String?,
            department: student['department'] as String? ?? profile['department'] as String?,
            batchYear: student['batch_year'] is int
                ? student['batch_year'] as int
                : int.tryParse(student['batch_year']?.toString() ?? ''),
            companyName: map['company_name'] as String?,
            internshipStatus: map['status'] as String?,
            itrStatus: itrStatus,
            hasCertificate: hasCertificate,
            certificateStatus: certStatus,
            progress: progressVal,
            hasPendingApprovals: hasPendingReview,
          ),
        );
      }

      return items;
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.message.toLowerCase().contains('permission denied')) {
        throw const UnauthorizedException(
          'Your account does not have permission to access student monitoring data.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<StudentMonitoringDetail?> getStudentDetails(
    String studentId, {
    String? internshipId,
  }) async {
    final client = _client;
    if (client == null) {
      return MockStudentMonitoringData.getDetails(studentId);
    }

    await AuthService.requireAuthenticatedClient(client: client);

    try {
      var query = client.from('internships').select('''
        id,
        internship_title,
        title,
        status,
        start_date,
        end_date,
        company_name,
        mode,
        progress,
        description,
        student_id,
        created_at,
        updated_at,
        industries (
          id,
          name,
          address,
          contact_email,
          contact_phone
        ),
        students (
          id,
          roll_number,
          department,
          batch_year,
          user_id,
          created_at,
          updated_at,
          profiles:user_id (
            id,
            full_name,
            email,
            department,
            branch,
            phone,
            phone_number,
            address,
            avatar_url,
            is_active,
            created_at,
            updated_at
          )
        ),
        itrs (
          id,
          status,
          content,
          project_title,
          project_description,
          work_done,
          technologies_used,
          key_learnings,
          challenges_faced,
          document_path,
          project_zip_path,
          project_ppt_path,
          project_presentation_path,
          presentation_path,
          submitted_at,
          reviewed_at,
          verified_at,
          reviewer_name,
          remarks,
          created_at,
          updated_at
        ),
        certificates (
          id,
          file_path,
          status,
          created_at,
          updated_at
        ),
        approval_reviews (
          id,
          status,
          review_stage,
          remarks,
          created_at
        )
      ''');

      if (internshipId != null && internshipId.isNotEmpty) {
        query = query.eq('id', internshipId);
      } else {
        query = query.eq('student_id', studentId);
      }

      final response = await query.maybeSingle();

      if (response != null) {
        final map = Map<String, dynamic>.from(response);

        final student = map['students'] is Map
            ? Map<String, dynamic>.from(map['students'] as Map)
            : <String, dynamic>{};

        final profile = student['profiles'] is Map
            ? Map<String, dynamic>.from(student['profiles'] as Map)
            : <String, dynamic>{};

        final industry = map['industries'] is Map
            ? Map<String, dynamic>.from(map['industries'] as Map)
            : <String, dynamic>{};

        // Extract ITR map
        Map<String, dynamic>? itrMap;
        if (map['itrs'] is List && (map['itrs'] as List).isNotEmpty) {
          itrMap = Map<String, dynamic>.from((map['itrs'] as List).first as Map);
        } else if (map['itrs'] is Map) {
          itrMap = Map<String, dynamic>.from(map['itrs'] as Map);
        }

        // Extract Certificate map
        Map<String, dynamic>? certMap;
        if (map['certificates'] is List && (map['certificates'] as List).isNotEmpty) {
          certMap = Map<String, dynamic>.from((map['certificates'] as List).first as Map);
        } else if (map['certificates'] is Map) {
          certMap = Map<String, dynamic>.from(map['certificates'] as Map);
        }

        // Extract Approval Reviews
        final reviews = <StudentApprovalReviewItem>[];
        if (map['approval_reviews'] is List) {
          for (final r in map['approval_reviews'] as List) {
            final rMap = Map<String, dynamic>.from(r as Map);
            reviews.add(
              StudentApprovalReviewItem(
                id: rMap['id'] as String? ?? '',
                reviewStage: rMap['review_stage'] as String? ?? 'faculty',
                status: rMap['status'] as String? ?? 'pending',
                remarks: rMap['remarks'] as String?,
                createdAt: rMap['created_at'] != null
                    ? DateTime.tryParse(rMap['created_at'].toString())
                    : null,
              ),
            );
          }
        }

        return StudentMonitoringDetail(
          studentId: studentId,
          userId: student['user_id'] as String?,
          studentName: profile['full_name'] as String? ?? 'Unknown Student',
          studentEmail: profile['email'] as String? ?? 'N/A',
          rollNumber: student['roll_number'] as String?,
          department: student['department'] as String? ?? profile['department'] as String?,
          branch: profile['branch'] as String?,
          batchYear: student['batch_year'] is int
              ? student['batch_year'] as int
              : int.tryParse(student['batch_year']?.toString() ?? ''),
          phone: profile['phone'] as String? ?? profile['phone_number'] as String?,
          address: profile['address'] as String?,
          avatarUrl: profile['avatar_url'] as String?,
          isActive: profile['is_active'] as bool? ?? true,
          profileCreatedAt: profile['created_at'] != null
              ? DateTime.tryParse(profile['created_at'].toString())
              : null,
          profileUpdatedAt: profile['updated_at'] != null
              ? DateTime.tryParse(profile['updated_at'].toString())
              : null,
          internshipId: map['id'] as String?,
          internshipTitle: map['internship_title'] as String? ?? map['title'] as String?,
          companyName: map['company_name'] as String? ?? industry['name'] as String?,
          internshipMode: map['mode'] as String?,
          startDate: map['start_date'] != null
              ? DateTime.tryParse(map['start_date'].toString())
              : null,
          endDate: map['end_date'] != null
              ? DateTime.tryParse(map['end_date'].toString())
              : null,
          internshipStatus: map['status'] as String?,
          progress: map['progress'] is num ? (map['progress'] as num).toInt() : 0,
          description: map['description'] as String?,
          industryName: industry['name'] as String?,
          industryAddress: industry['address'] as String?,
          industryEmail: industry['contact_email'] as String?,
          industryPhone: industry['contact_phone'] as String?,
          itrId: itrMap?['id'] as String?,
          itrStatus: itrMap?['status'] as String?,
          itrContent: itrMap?['content'] as String?,
          itrProjectTitle: itrMap?['project_title'] as String?,
          itrProjectDescription: itrMap?['project_description'] as String?,
          itrWorkDone: itrMap?['work_done'] as String?,
          itrTechnologiesUsed: itrMap?['technologies_used'] as String?,
          itrKeyLearnings: itrMap?['key_learnings'] as String?,
          itrChallengesFaced: itrMap?['challenges_faced'] as String?,
          itrDocumentPath: itrMap?['document_path'] as String?,
          itrProjectZipPath: itrMap?['project_zip_path'] as String?,
          itrProjectPptPath: itrMap?['project_ppt_path'] as String?,
          itrPresentationPath: itrMap?['project_presentation_path'] as String? ??
              itrMap?['presentation_path'] as String?,
          itrSubmittedAt: itrMap?['submitted_at'] != null
              ? DateTime.tryParse(itrMap!['submitted_at'].toString())
              : (itrMap?['created_at'] != null
                  ? DateTime.tryParse(itrMap!['created_at'].toString())
                  : null),
          itrReviewedAt: itrMap?['reviewed_at'] != null
              ? DateTime.tryParse(itrMap!['reviewed_at'].toString())
              : null,
          itrVerifiedAt: itrMap?['verified_at'] != null
              ? DateTime.tryParse(itrMap!['verified_at'].toString())
              : null,
          itrReviewerName: itrMap?['reviewer_name'] as String?,
          itrRemarks: itrMap?['remarks'] as String?,
          certificateId: certMap?['id'] as String?,
          certificateFilePath: certMap?['file_path'] as String?,
          certificateStatus: certMap?['status'] as String?,
          certificateCreatedAt: certMap?['created_at'] != null
              ? DateTime.tryParse(certMap!['created_at'].toString())
              : null,
          certificateUpdatedAt: certMap?['updated_at'] != null
              ? DateTime.tryParse(certMap!['updated_at'].toString())
              : null,
          approvalReviews: reviews,
        );
      }

      // If no internship found, fallback to loading student profile directly
      final studentRes = await client.from('students').select('''
        id,
        roll_number,
        department,
        batch_year,
        user_id,
        created_at,
        updated_at,
        profiles:user_id (
          id,
          full_name,
          email,
          department,
          branch,
          phone,
          phone_number,
          address,
          avatar_url,
          is_active,
          created_at,
          updated_at
        )
      ''').eq('id', studentId).maybeSingle();

      if (studentRes != null) {
        final sMap = Map<String, dynamic>.from(studentRes);
        final profile = sMap['profiles'] is Map
            ? Map<String, dynamic>.from(sMap['profiles'] as Map)
            : <String, dynamic>{};

        return StudentMonitoringDetail(
          studentId: studentId,
          userId: sMap['user_id'] as String?,
          studentName: profile['full_name'] as String? ?? 'Unknown Student',
          studentEmail: profile['email'] as String? ?? 'N/A',
          rollNumber: sMap['roll_number'] as String?,
          department: sMap['department'] as String? ?? profile['department'] as String?,
          branch: profile['branch'] as String?,
          batchYear: sMap['batch_year'] is int
              ? sMap['batch_year'] as int
              : int.tryParse(sMap['batch_year']?.toString() ?? ''),
          phone: profile['phone'] as String? ?? profile['phone_number'] as String?,
          address: profile['address'] as String?,
          avatarUrl: profile['avatar_url'] as String?,
          isActive: profile['is_active'] as bool? ?? true,
          profileCreatedAt: profile['created_at'] != null
              ? DateTime.tryParse(profile['created_at'].toString())
              : null,
          profileUpdatedAt: profile['updated_at'] != null
              ? DateTime.tryParse(profile['updated_at'].toString())
              : null,
        );
      }

      return null;
    } on PostgrestException catch (e) {
      if (e.code == '42501' || e.message.toLowerCase().contains('permission denied')) {
        throw const UnauthorizedException(
          'Your account does not have permission to access student monitoring data.',
        );
      }
      rethrow;
    }
  }

  @override
  Future<String?> getFileUrl({
    required String bucket,
    required String path,
  }) async {
    final client = _client;
    if (client == null) return null;
    if (path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    try {
      final signedUrl = await client.storage.from(bucket).createSignedUrl(path, 3600);
      return signedUrl;
    } catch (_) {
      try {
        return client.storage.from(bucket).getPublicUrl(path);
      } catch (_) {
        return null;
      }
    }
  }
}
