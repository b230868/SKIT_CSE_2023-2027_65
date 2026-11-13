import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../../core/network/api_client.dart';
import '../../../internship/models/internship.dart';
import '../models/student_monitoring_detail.dart';
import '../models/student_monitoring_item.dart';
import 'student_monitoring_repository.dart';

class BackendStudentMonitoringRepository
    extends StudentMonitoringRepository {
  final ApiClient _apiClient;

  BackendStudentMonitoringRepository({ApiClient? apiClient})
    : _apiClient = apiClient ?? ApiClient();

  @override
  Future<List<StudentMonitoringItem>> getStudents() async {
    try {
      final response = await _apiClient.get('/monitoring/students');

      final List<dynamic> list;
      if (response is Map && response['data'] is List) {
        list = response['data'] as List;
      } else if (response is List) {
        list = response;
      } else {
        list = [];
      }

      return list.map((item) {
        final map = Map<String, dynamic>.from(item as Map);
        final rawDocs = map['documents'] is List ? map['documents'] as List : const [];
        final docs = rawDocs
            .whereType<Map>()
            .map((d) => InternshipDocument.fromMap(Map<String, dynamic>.from(d)))
            .toList();
        final rawScore = map['companyEvaluationScore'];
        final rawAtt = map['attendanceRate'];
        return StudentMonitoringItem(
          studentId: map['studentId'] as String? ?? '',
          studentName: map['studentName'] as String? ?? 'Unknown Student',
          internshipId: map['internshipId'] as String? ?? '',
          internshipTitle:
              map['internshipTitle'] as String? ?? 'Untitled Internship',
          applicationStatus: map['applicationStatus'] as String? ?? 'pending',
          studentEmail: map['studentEmail'] as String?,
          rollNumber: map['rollNumber'] as String?,
          department: map['department'] as String?,
          batchYear: map['batchYear'] as int?,
          companyName: map['companyName'] as String?,
          internshipStatus: map['internshipStatus'] as String?,
          itrStatus: map['itrStatus'] as String?,
          hasCertificate: map['hasCertificate'] as bool? ?? false,
          certificateStatus: map['certificateStatus'] as String?,
          progress: map['progress'] as int? ?? 0,
          hasPendingApprovals: map['hasPendingApprovals'] as bool? ?? false,
          companyEvaluationScore:
              rawScore is num ? rawScore.toDouble() : double.tryParse('$rawScore'),
          companyEvaluationGrade: map['companyEvaluationGrade'] as String?,
          attendanceRate:
              rawAtt is num ? rawAtt.toDouble() : double.tryParse('$rawAtt'),
          companyRemarks: map['companyRemarks'] as String?,
          companyEvaluatorName: map['companyEvaluatorName'] as String?,
          documents: docs,
        );
      }).toList();
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw const UnauthenticatedException(
          'Please sign in to access student monitoring data.',
        );
      } else if (e.statusCode == 403) {
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
    try {
      final endpoint = internshipId != null && internshipId.isNotEmpty
          ? '/monitoring/students/$studentId?internshipId=$internshipId'
          : '/monitoring/students/$studentId';
      final response = await _apiClient.get(endpoint);
      if (response is Map && response['data'] is Map) {
        final map = Map<String, dynamic>.from(response['data'] as Map);
        final rawReviews = map['approvalReviews'] is List
            ? map['approvalReviews'] as List
            : const [];
        final approvalReviews = rawReviews
            .whereType<Map>()
            .map((r) {
              final rm = Map<String, dynamic>.from(r);
              return StudentApprovalReviewItem(
                id: rm['id']?.toString() ?? '',
                reviewStage: rm['reviewStage']?.toString() ?? 'faculty',
                status: rm['status']?.toString() ?? 'pending',
                remarks: rm['remarks']?.toString(),
                createdAt: rm['createdAt'] != null
                    ? DateTime.tryParse(rm['createdAt'].toString())
                    : null,
              );
            })
            .toList();

        return StudentMonitoringDetail(
          studentId: map['studentId'] as String? ?? studentId,
          userId: map['userId'] as String?,
          studentName: map['studentName'] as String? ?? 'Unknown Student',
          studentEmail: map['studentEmail'] as String? ?? 'N/A',
          rollNumber: map['rollNumber'] as String?,
          department: map['department'] as String?,
          branch: map['branch'] as String?,
          batchYear: map['batchYear'] as int?,
          phone: map['phone'] as String?,
          address: map['address'] as String?,
          avatarUrl: map['avatarUrl'] as String?,
          internshipId: map['internshipId'] as String? ?? internshipId,
          internshipTitle: map['internshipTitle'] as String?,
          companyName: map['companyName'] as String?,
          internshipMode: map['internshipMode'] as String?,
          startDate: map['startDate'] != null
              ? DateTime.tryParse(map['startDate'].toString())
              : null,
          endDate: map['endDate'] != null
              ? DateTime.tryParse(map['endDate'].toString())
              : null,
          internshipStatus: map['internshipStatus'] as String?,
          progress: map['progress'] as int? ?? 0,
          description: map['description'] as String?,
          industryName: map['industryName'] as String?,
          industryAddress: map['industryAddress'] as String?,
          industryEmail: map['industryEmail'] as String?,
          industryPhone: map['industryPhone'] as String?,
          itrId: map['itrId'] as String?,
          itrStatus: map['itrStatus'] as String?,
          itrContent: map['itrContent'] as String?,
          itrProjectTitle: map['itrProjectTitle'] as String?,
          itrProjectDescription: map['itrProjectDescription'] as String?,
          itrWorkDone: map['itrWorkDone'] as String?,
          itrTechnologiesUsed: map['itrTechnologiesUsed'] as String?,
          itrKeyLearnings: map['itrKeyLearnings'] as String?,
          itrChallengesFaced: map['itrChallengesFaced'] as String?,
          itrDocumentPath: map['itrDocumentPath'] as String?,
          itrProjectZipPath: map['itrProjectZipPath'] as String?,
          itrPresentationPath: map['itrPresentationPath'] as String?,
          itrSubmittedAt: map['itrSubmittedAt'] != null
              ? DateTime.tryParse(map['itrSubmittedAt'].toString())
              : null,
          itrReviewedAt: map['itrReviewedAt'] != null
              ? DateTime.tryParse(map['itrReviewedAt'].toString())
              : null,
          itrVerifiedAt: map['itrVerifiedAt'] != null
              ? DateTime.tryParse(map['itrVerifiedAt'].toString())
              : null,
          itrReviewerName: map['itrReviewerName'] as String?,
          itrRemarks: map['itrRemarks'] as String?,
          certificateId: map['certificateId'] as String?,
          certificateFilePath: map['certificateFilePath'] as String?,
          certificateStatus: map['certificateStatus'] as String?,
          approvalReviews: approvalReviews,
        );
      }
      return null;
    } on ApiException catch (e) {
      if (e.statusCode == 401) {
        throw const UnauthenticatedException(
          'Please sign in to access student monitoring data.',
        );
      } else if (e.statusCode == 403) {
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
    if (path.trim().isEmpty) return null;
    if (path.startsWith('http://') || path.startsWith('https://')) {
      return path;
    }
    try {
      final client = Supabase.instance.client;
      return await client.storage.from(bucket).createSignedUrl(path, 3600);
    } catch (_) {
      try {
        return Supabase.instance.client.storage.from(bucket).getPublicUrl(path);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<void> verifyStudentDocument({
    required String documentId,
    required String status,
    String? rejectionReason,
    String? remarks,
  }) async {
    await _apiClient.patch(
      '/monitoring/documents/$documentId',
      body: {
        'status': status,
        'rejectionReason': rejectionReason,
        'remarks': remarks,
      },
    );
  }
}
