import '../../../../core/auth/auth_service.dart';
import '../../../../core/network/api_client.dart';
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
          internshipStatus: map['internshipStatus'] as String?,
          progress: map['progress'] as int? ?? 0,
          description: map['description'] as String?,
          itrId: map['itrId'] as String?,
          itrStatus: map['itrStatus'] as String?,
          itrContent: map['itrContent'] as String?,
          itrProjectTitle: map['itrProjectTitle'] as String?,
          itrWorkDone: map['itrWorkDone'] as String?,
          itrTechnologiesUsed: map['itrTechnologiesUsed'] as String?,
          itrKeyLearnings: map['itrKeyLearnings'] as String?,
          itrChallengesFaced: map['itrChallengesFaced'] as String?,
          itrDocumentPath: map['itrDocumentPath'] as String?,
          certificateId: map['certificateId'] as String?,
          certificateFilePath: map['certificateFilePath'] as String?,
          certificateStatus: map['certificateStatus'] as String?,
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
    return '${_apiClient.baseUrl}/files/$bucket/$path';
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
