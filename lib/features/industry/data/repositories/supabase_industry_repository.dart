import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../internship/models/internship.dart';
import '../models/industry_attendance_model.dart';
import '../models/industry_dashboard_data.dart';
import '../models/industry_internship_model.dart';
import 'industry_repository.dart';

class SupabaseIndustryRepository implements IndustryRepository {
  SupabaseIndustryRepository({SupabaseClient? client}) : _customClient = client;

  final SupabaseClient? _customClient;

  SupabaseClient get _client {
    final client = _customClient;
    if (client != null) return client;
    try {
      return Supabase.instance.client;
    } catch (_) {
      throw StateError('User is not authenticated.');
    }
  }

  /// Resolves the canonical `industry_id` for the authenticated industry supervisor.
  Future<String?> _getIndustryId() async {
    final user = _client.auth.currentUser;
    if (user == null) {
      throw StateError('User is not authenticated.');
    }

    // 1. Primary lookup: industry_users mapping table (schema verified)
    final row = await _client
        .from('industry_users')
        .select('industry_id')
        .eq('user_id', user.id)
        .maybeSingle();

    if (row != null && row['industry_id'] != null) {
      return row['industry_id'].toString();
    }

    // 2. Direct lookup: check if an organization exists with id = user.id
    final ind = await _client
        .from('industries')
        .select('id')
        .eq('id', user.id)
        .maybeSingle();

    if (ind != null && ind['id'] != null) {
      return ind['id'].toString();
    }

    return null;
  }

  /// Asserts that a target internship belongs to the supervisor's authorized company.
  /// Throws StateError / Unauthorized access if the relationship does not match.
  Future<String> _requireAuthorizedInternship(String internshipId) async {
    final industryId = await _getIndustryId();
    if (industryId == null) {
      throw StateError(
        'Unauthorized: No verified company association for this supervisor.',
      );
    }

    final row = await _client
        .from('internships')
        .select('id')
        .eq('id', internshipId)
        .eq('industry_id', industryId)
        .maybeSingle();

    if (row == null) {
      throw StateError(
        'Unauthorized: Internship $internshipId does not belong to your company.',
      );
    }

    return industryId;
  }

  @override
  Future<List<IndustryInternshipModel>> getIndustryInternships() async {
    final industryId = await _getIndustryId();

    if (industryId == null) {
      return [];
    }

    // Query internships scoped strictly by industry_id
    final res = await _client
        .from('internships')
        .select('''
          id,
          student_id,
          internship_title,
          title,
          company_name,
          start_date,
          end_date,
          status,
          progress,
          students (
            roll_number,
            profiles (
              id,
              full_name,
              enrollment_no,
              branch
            )
          )
        ''')
        .eq('industry_id', industryId)
        .order('created_at', ascending: false);

    final internshipList = (res as List)
        .map((raw) => Map<String, dynamic>.from(raw as Map))
        .toList();

    if (internshipList.isEmpty) {
      return [];
    }

    final internshipIds = internshipList
        .map((e) => e['id'].toString())
        .toList();

    final Map<String, String> latestItrStatus = {};
    final Map<String, String> latestEvaluationStatus = {};
    final Map<String, double> latestProgress = {};
    final Map<String, String> offerLetterStatuses = {};
    final Map<String, String> offerLetterUrls = {};
    final Map<String, String> certificateStatuses = {};
    final Map<String, String> certificateUrls = {};
    final Map<String, double> attendanceRates = {};

    try {
      final evalRows = await _client
          .from('evaluations')
          .select('internship_id, status, created_at')
          .inFilter('internship_id', internshipIds)
          .order('created_at', ascending: false);

      for (final row in (evalRows as List)) {
        final id = row['internship_id']?.toString();
        if (id != null && !latestEvaluationStatus.containsKey(id)) {
          latestEvaluationStatus[id] = row['status']?.toString() ?? 'pending';
        }
      }
    } catch (_) {}

    try {
      final docRows = await _client
          .from('internship_documents')
          .select('internship_id, document_type, file_url, created_at')
          .inFilter('internship_id', internshipIds)
          .order('created_at', ascending: false);

      for (final row in (docRows as List)) {
        final id = row['internship_id']?.toString();
        final type = row['document_type']?.toString();
        final url = row['file_url']?.toString();
        if (id != null) {
          if (type == 'offer_letter' && !offerLetterStatuses.containsKey(id)) {
            offerLetterStatuses[id] = 'issued';
            if (url != null) offerLetterUrls[id] = url;
          } else if (type == 'completion_certificate' &&
              !certificateStatuses.containsKey(id)) {
            certificateStatuses[id] = 'issued';
            if (url != null) certificateUrls[id] = url;
          }
        }
      }
    } catch (_) {}

    try {
      final attRows = await _client
          .from('attendance')
          .select('internship_id, status')
          .inFilter('internship_id', internshipIds);

      final Map<String, int> totalCount = {};
      final Map<String, int> presentCount = {};
      for (final row in (attRows as List)) {
        final id = row['internship_id']?.toString();
        if (id != null) {
          totalCount[id] = (totalCount[id] ?? 0) + 1;
          if (row['status']?.toString().toLowerCase() == 'present') {
            presentCount[id] = (presentCount[id] ?? 0) + 1;
          }
        }
      }
      for (final id in totalCount.keys) {
        final tot = totalCount[id] ?? 0;
        final pres = presentCount[id] ?? 0;
        attendanceRates[id] = tot > 0 ? (pres / tot) * 100 : 0.0;
      }
    } catch (_) {}

    try {
      final progressRows = await _client
          .from('internship_progress_updates')
          .select('internship_id, progress_percentage, created_at')
          .inFilter('internship_id', internshipIds)
          .order('created_at', ascending: false);

      for (final row in (progressRows as List)) {
        final id = row['internship_id']?.toString();
        if (id != null && !latestProgress.containsKey(id)) {
          latestProgress[id] =
              (row['progress_percentage'] as num?)?.toDouble() ?? 0.0;
        }
      }
    } catch (_) {}

    final result = <IndustryInternshipModel>[];

    for (final internship in internshipList) {
      final student = internship['students'] as Map<String, dynamic>?;
      final profile = student?['profiles'] as Map<String, dynamic>?;
      final internshipId = internship['id'].toString();

      final evalStatus = latestEvaluationStatus[internshipId] ?? 'pending';
      final progress =
          ((internship['progress'] as num?)?.toDouble() ??
                  latestProgress[internshipId] ??
                  0.0)
              .clamp(0.0, 100.0)
              .toDouble();

      final studentIdVal =
          internship['student_id']?.toString() ?? profile?['id']?.toString();
      final rollNoVal =
          student?['roll_number']?.toString() ??
          profile?['enrollment_no']?.toString();
      final branchVal = profile?['branch']?.toString();
      final startDateVal = internship['start_date'] != null
          ? DateTime.tryParse(internship['start_date'].toString())
          : null;
      final endDateVal = internship['end_date'] != null
          ? DateTime.tryParse(internship['end_date'].toString())
          : null;

      result.add(
        IndustryInternshipModel(
          id: internshipId,
          studentName:
              profile?['full_name']?.toString() ??
              internship['company_name']?.toString() ??
              'Student',
          internshipTitle:
              internship['internship_title']?.toString() ??
              internship['title']?.toString() ??
              'Internship',
          status: internship['status']?.toString() ?? 'planned',
          progress: progress,
          itrStatus: latestItrStatus[internshipId] ?? 'draft',
          evaluationStatus: evalStatus,
          studentId: studentIdVal,
          studentRollNo: rollNoVal,
          branch: branchVal,
          startDate: startDateVal,
          endDate: endDateVal,
          companyName: internship['company_name']?.toString(),
          attendanceRate: attendanceRates[internshipId],
          offerLetterStatus: offerLetterStatuses[internshipId] ?? 'pending',
          offerLetterUrl: offerLetterUrls[internshipId],
          certificateStatus: certificateStatuses[internshipId] ?? 'pending',
          certificateUrl: certificateUrls[internshipId],
        ),
      );
    }

    return result;
  }

  @override
  Future<IndustryDashboardData> getDashboardData() async {
    final industryId = await _getIndustryId();

    if (industryId == null) {
      return IndustryDashboardData.empty();
    }

    String industryName = 'Industry Partner';
    try {
      final res = await _client
          .from('industries')
          .select('name')
          .eq('id', industryId)
          .maybeSingle();

      if (res != null && res['name'] != null) {
        industryName = res['name'].toString();
      }
    } catch (_) {}

    // Derive dashboard metrics from actual repository internships
    final internships = await getIndustryInternships();

    final active = internships.where((i) => i.status == 'active').length;
    final completed = internships.where((i) => i.status == 'completed').length;
    final pendingEval = internships
        .where((i) => ['pending', 'in_progress'].contains(i.evaluationStatus))
        .length;
    final completedEval = internships
        .where(
          (i) => [
            'verified',
            'completed',
            'approved',
          ].contains(i.evaluationStatus),
        )
        .length;

    final issuedCerts = internships
        .where(
          (i) =>
              i.certificateStatus == 'issued' ||
              i.certificateStatus == 'verified',
        )
        .length;
    final pendingCerts = internships
        .where(
          (i) => i.certificateStatus == 'pending' && i.status == 'completed',
        )
        .length;
    final issuedOffers = internships
        .where(
          (i) =>
              i.offerLetterStatus == 'issued' ||
              i.offerLetterStatus == 'verified',
        )
        .length;
    final pendingOffers = internships
        .where((i) => i.offerLetterStatus == 'pending')
        .length;

    // Check today's pending attendance among active interns
    int pendingAtt = 0;
    try {
      final todayStr = DateTime.now().toIso8601String().substring(0, 10);
      final activeIds = internships
          .where((i) => i.status == 'active')
          .map((i) => i.id)
          .toList();
      if (activeIds.isNotEmpty) {
        final markedToday = await _client
            .from('attendance')
            .select('internship_id')
            .inFilter('internship_id', activeIds)
            .eq('date', todayStr);
        final markedSet = (markedToday as List)
            .map((r) => r['internship_id'].toString())
            .toSet();
        pendingAtt = activeIds.where((id) => !markedSet.contains(id)).length;
      }
    } catch (_) {
      pendingAtt = 0;
    }

    return IndustryDashboardData(
      industryName: industryName,
      totalInterns: internships.length,
      activeInterns: active,
      completedInternships: completed,
      pendingAttendance: pendingAtt,
      pendingEvaluations: pendingEval,
      completedEvaluations: completedEval,
      pendingCertificates: pendingCerts,
      issuedCertificates: issuedCerts,
      pendingOfferLetters: pendingOffers,
      issuedOfferLetters: issuedOffers,
      pendingItrs: 0,
      submittedItrs: 0,
    );
  }

  @override
  Future<List<IndustryAttendanceRecord>> getAttendanceRecords(
    String internshipId,
  ) async {
    // Validate server-side company authorization
    await _requireAuthorizedInternship(internshipId);

    try {
      final rows = await _client
          .from('attendance')
          .select('''
            id,
            internship_id,
            student_id,
            date,
            status,
            marked_by,
            remarks,
            created_at,
            profiles:marked_by (
              full_name
            )
          ''')
          .eq('internship_id', internshipId)
          .order('date', ascending: false);

      return (rows as List).map((raw) {
        final map = Map<String, dynamic>.from(raw as Map);
        final profile = map['profiles'] as Map<String, dynamic>?;
        return IndustryAttendanceRecord(
          id: map['id']?.toString() ?? '',
          internshipId: map['internship_id']?.toString() ?? '',
          studentId: map['student_id']?.toString() ?? '',
          date: map['date'] != null
              ? (DateTime.tryParse(map['date'].toString()) ?? DateTime.now())
              : DateTime.now(),
          status: map['status']?.toString() ?? 'present',
          markedBy: map['marked_by']?.toString(),
          markedByName: profile?['full_name']?.toString(),
          markedAt: map['created_at'] != null
              ? DateTime.tryParse(map['created_at'].toString())
              : null,
          remarks: map['remarks']?.toString(),
        );
      }).toList();
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> markAttendance({
    required String internshipId,
    required String studentId,
    required DateTime date,
    required String status,
    String? remarks,
  }) async {
    // Validate server-side company authorization
    await _requireAuthorizedInternship(internshipId);

    final user = _client.auth.currentUser;
    final dateStr =
        '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

    final payload = {
      'internship_id': internshipId,
      'student_id': studentId,
      'date': dateStr,
      'status': status.toLowerCase(),
      'marked_by': user?.id,
      'remarks': remarks,
    };

    // Upsert on unique (internship_id, date) constraint to prevent duplicates
    await _client
        .from('attendance')
        .upsert(payload, onConflict: 'internship_id,date');
  }

  @override
  Future<void> updateOfferLetter({
    required String internshipId,
    required String status,
    String? fileUrl,
  }) async {
    await _requireAuthorizedInternship(internshipId);

    if (fileUrl != null && fileUrl.isNotEmpty) {
      await _client.from('internship_documents').upsert({
        'internship_id': internshipId,
        'document_type': 'offer_letter',
        'file_url': fileUrl,
      });
    }
  }

  @override
  Future<void> updateCertificate({
    required String internshipId,
    required String status,
    String? fileUrl,
  }) async {
    await _requireAuthorizedInternship(internshipId);

    if (fileUrl != null && fileUrl.isNotEmpty) {
      await _client.from('internship_documents').upsert({
        'internship_id': internshipId,
        'document_type': 'completion_certificate',
        'file_url': fileUrl,
      });
    }
  }

  @override
  Future<List<InternshipDocument>> getStudentDocuments(
    String internshipId,
  ) async {
    // Validate server-side company authorization
    await _requireAuthorizedInternship(internshipId);

    try {
      final rows = await _client
          .from('internship_documents')
          .select('''
            id,
            internship_id,
            student_id,
            document_type,
            file_name,
            file_path,
            file_url,
            status,
            rejection_reason,
            remarks,
            verified_by,
            verified_at,
            faculty_status,
            faculty_rejection_reason,
            faculty_remarks,
            faculty_verified_by,
            faculty_verified_at,
            created_at,
            profiles:verified_by (
              full_name
            ),
            faculty_profiles:faculty_verified_by (
              full_name
            )
          ''')
          .eq('internship_id', internshipId)
          .order('created_at', ascending: false);

      final list = <InternshipDocument>[];
      for (final raw in (rows as List)) {
        final map = Map<String, dynamic>.from(raw as Map);
        final reviewerProfile = map['profiles'] as Map<String, dynamic>?;
        final facultyProfile = map['faculty_profiles'] as Map<String, dynamic>?;

        String? signedUrl;
        final filePath = map['file_path']?.toString();
        if (filePath != null && filePath.isNotEmpty) {
          try {
            signedUrl = await _client.storage
                .from('internship-docs')
                .createSignedUrl(filePath, 3600);
          } catch (_) {
            signedUrl = map['file_url']?.toString();
          }
        } else {
          signedUrl = map['file_url']?.toString();
        }

        list.add(
          InternshipDocument(
            id: map['id']?.toString() ?? '',
            internshipId: map['internship_id']?.toString() ?? '',
            studentId: map['student_id']?.toString(),
            docType:
                map['document_type']?.toString() ??
                map['doc_type']?.toString() ??
                'other',
            fileName: map['file_name']?.toString() ?? 'Document',
            filePath: filePath ?? '',
            fileUrl: signedUrl,
            status: map['status']?.toString() ?? 'pending',
            rejectionReason: map['rejection_reason']?.toString(),
            remarks: map['remarks']?.toString(),
            verifiedBy: map['verified_by']?.toString(),
            verifiedByName: reviewerProfile?['full_name']?.toString(),
            verifiedAt: map['verified_at'] != null
                ? DateTime.tryParse(map['verified_at'].toString())
                : null,
            facultyStatus: map['faculty_status']?.toString() ?? 'pending',
            facultyRejectionReason: map['faculty_rejection_reason']?.toString(),
            facultyRemarks: map['faculty_remarks']?.toString(),
            facultyVerifiedBy: map['faculty_verified_by']?.toString(),
            facultyVerifiedByName: facultyProfile?['full_name']?.toString(),
            facultyVerifiedAt: map['faculty_verified_at'] != null
                ? DateTime.tryParse(map['faculty_verified_at'].toString())
                : null,
            createdAt: map['created_at'] != null
                ? (DateTime.tryParse(map['created_at'].toString()) ??
                          DateTime.now())
                      .toLocal()
                : DateTime.now(),
          ),
        );
      }
      return list;
    } catch (_) {
      return [];
    }
  }

  @override
  Future<void> verifyStudentDocument({
    required String documentId,
    required String status,
    String? rejectionReason,
    String? remarks,
  }) async {
    final user = _client.auth.currentUser;

    // Verify document belongs to an internship assigned to this supervisor's company
    final docRow = await _client
        .from('internship_documents')
        .select('internship_id')
        .eq('id', documentId)
        .maybeSingle();

    if (docRow == null) {
      throw StateError('Document not found.');
    }

    final internshipId = docRow['internship_id']?.toString() ?? '';
    await _requireAuthorizedInternship(internshipId);

    await _client
        .from('internship_documents')
        .update({
          'status': status,
          'rejection_reason': status == 'rejected' ? rejectionReason : null,
          'remarks': remarks,
          'verified_by': user?.id,
          'verified_at': DateTime.now().toIso8601String(),
        })
        .eq('id', documentId);
  }
}
