import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../internship/models/internship.dart';
import '../models/student_monitoring_detail.dart';
import '../models/student_monitoring_item.dart';
import 'student_monitoring_repository.dart';

class SupabaseStudentMonitoringRepository
    extends StudentMonitoringRepository {
  final SupabaseClient? _providedClient;

  SupabaseStudentMonitoringRepository({SupabaseClient? client})
    : _providedClient = client;

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
      throw StateError('Supabase client is not initialized.');
    }

    await AuthService.requireAuthenticatedClient(client: client);

    try {
      final response = await client
          .from('internships')
          .select('''
        id,
        internship_title,
        title,
        status,
        company_name,
        progress,
        student_id,
        created_at,
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
      ''')
          .order('created_at', ascending: false);

      final items = <StudentMonitoringItem>[];
      final internshipList = response as List;
      if (internshipList.isEmpty) return [];

      final studentIds = internshipList
          .map((e) => (e as Map)['student_id']?.toString())
          .whereType<String>()
          .toSet()
          .toList();

      final Map<String, Map<String, dynamic>> profilesMap = {};
      final Map<String, Map<String, dynamic>> studentsByKey = {};

      if (studentIds.isNotEmpty) {
        try {
          final studs = await client
              .from('students')
              .select('id, roll_number, department, batch_year, user_id')
              .or(
                studentIds
                    .expand((id) => ['id.eq.$id', 'user_id.eq.$id'])
                    .join(','),
              );
          for (final s in (studs as List)) {
            final row = Map<String, dynamic>.from(s as Map);
            final sid = row['id']?.toString();
            final uid = row['user_id']?.toString();
            if (sid != null) studentsByKey[sid] = row;
            if (uid != null) studentsByKey[uid] = row;
          }
        } catch (_) {}

        final profileLookupIds = <String>{
          ...studentIds,
          ...studentsByKey.values
              .map((s) => s['user_id']?.toString())
              .whereType<String>(),
        }.toList();

        if (profileLookupIds.isNotEmpty) {
          try {
            final profs = await client
                .from('profiles')
                .select(
                  'id, full_name, email, department, branch, phone, phone_number, address, avatar_url, enrollment_no',
                )
                .inFilter('id', profileLookupIds);
            for (final p in (profs as List)) {
              final row = Map<String, dynamic>.from(p as Map);
              final id = row['id']?.toString();
              if (id != null) profilesMap[id] = row;
            }
          } catch (_) {}
        }
      }

      final internshipIds =
          internshipList.map((e) => (e as Map)['id']?.toString() ?? '').toList();

      final Map<String, Map<String, dynamic>> evaluationsMap = {};
      final Map<String, double> attendanceRateMap = {};
      final Map<String, List<InternshipDocument>> docsMap = {};
      final Set<String> helperProfileIds = {};

      try {
        final evalRows = await client
            .from('evaluations')
            .select(
              'internship_id, total_score, score, marks, grade, status, feedback, remarks, evaluator_id, submitted_at',
            )
            .inFilter('internship_id', internshipIds)
            .order('created_at', ascending: false);

        for (final row in (evalRows as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          final id = map['internship_id']?.toString();
          if (id != null && !evaluationsMap.containsKey(id)) {
            evaluationsMap[id] = map;
            final eid = map['evaluator_id']?.toString();
            if (eid != null && eid.isNotEmpty) helperProfileIds.add(eid);
          }
        }
      } catch (_) {}

      try {
        final attRows = await client
            .from('attendance')
            .select('internship_id, status')
            .inFilter('internship_id', internshipIds);

        final Map<String, int> totDays = {};
        final Map<String, int> presDays = {};
        for (final row in (attRows as List)) {
          final id = row['internship_id']?.toString();
          if (id != null) {
            totDays[id] = (totDays[id] ?? 0) + 1;
            if (row['status']?.toString().toLowerCase() == 'present') {
              presDays[id] = (presDays[id] ?? 0) + 1;
            }
          }
        }
        for (final id in totDays.keys) {
          final tot = totDays[id] ?? 0;
          final pres = presDays[id] ?? 0;
          attendanceRateMap[id] = tot > 0 ? (pres / tot) * 100 : 0.0;
        }
      } catch (_) {}

      final List<Map<String, dynamic>> rawDocRows = [];
      try {
        final docRows = await client
            .from('internship_documents')
            .select('*')
            .inFilter('internship_id', internshipIds)
            .order('created_at', ascending: false);

        for (final row in (docRows as List)) {
          final map = Map<String, dynamic>.from(row as Map);
          rawDocRows.add(map);
          final vBy = map['verified_by']?.toString();
          final fvBy = map['faculty_verified_by']?.toString();
          if (vBy != null && vBy.isNotEmpty) helperProfileIds.add(vBy);
          if (fvBy != null && fvBy.isNotEmpty) helperProfileIds.add(fvBy);
        }
      } catch (_) {}

      final Map<String, String> helperProfileNames = {};
      if (helperProfileIds.isNotEmpty) {
        try {
          final helperRows = await client
              .from('profiles')
              .select('id, full_name')
              .inFilter('id', helperProfileIds.toList());
          for (final row in (helperRows as List)) {
            final id = row['id']?.toString();
            final name = row['full_name']?.toString();
            if (id != null && name != null && name.isNotEmpty) {
              helperProfileNames[id] = name;
            }
          }
        } catch (_) {}
      }

      for (final map in rawDocRows) {
        final internshipId = map['internship_id']?.toString() ?? '';
        final vBy = map['verified_by']?.toString();
        final fvBy = map['faculty_verified_by']?.toString();
        if (map['verified_by_name'] == null && vBy != null) {
          map['verified_by_name'] = helperProfileNames[vBy];
        }
        if (map['faculty_verified_by_name'] == null && fvBy != null) {
          map['faculty_verified_by_name'] = helperProfileNames[fvBy];
        }
        final filePath = map['file_path']?.toString() ?? '';
        if ((map['file_url'] == null ||
                map['file_url'].toString().trim().isEmpty) &&
            filePath.isNotEmpty) {
          map['file_url'] = await getFileUrl(
            bucket: 'internship-docs',
            path: filePath,
          );
        }
        final doc = InternshipDocument.fromMap(map);
        docsMap.putIfAbsent(internshipId, () => []).add(doc);
      }

      for (final item in internshipList) {
        final map = Map<String, dynamic>.from(item as Map);
        final studentId = map['student_id']?.toString() ?? '';

        final student = studentsByKey[studentId] ?? <String, dynamic>{};
        final userId = student['user_id']?.toString();
        final profile =
            profilesMap[studentId] ??
            (userId != null ? profilesMap[userId] : null) ??
            <String, dynamic>{};

        final studentName =
            profile['full_name'] as String? ?? 'Unknown Student';
        final internshipTitle =
            map['internship_title'] as String? ??
            map['title'] as String? ??
            'Untitled Internship';
        final internshipId = map['id'] as String? ?? '';

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

        final bool hasPendingReview =
            reviews.any(
              (r) => (r['status'] as String?)?.toLowerCase() == 'pending',
            ) ||
            (map['status'] as String?)?.toLowerCase() == 'pending';

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
        if (map['certificates'] is List &&
            (map['certificates'] as List).isNotEmpty) {
          final cert = (map['certificates'] as List).first as Map;
          final filePath = cert['file_path'] as String?;
          hasCertificate = filePath != null && filePath.trim().isNotEmpty;
          certStatus = cert['status'] as String?;
        } else if (map['certificates'] is Map) {
          final filePath = (map['certificates'] as Map)['file_path'] as String?;
          hasCertificate = filePath != null && filePath.trim().isNotEmpty;
          certStatus = (map['certificates'] as Map)['status'] as String?;
        }

        final evalRow = evaluationsMap[internshipId];
        final rawScore =
            evalRow?['total_score'] ?? evalRow?['score'] ?? evalRow?['marks'];
        final double? companyScore = rawScore is num
            ? rawScore.toDouble()
            : double.tryParse(rawScore?.toString() ?? '');
        final evaluatorId = evalRow?['evaluator_id']?.toString();

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
            rollNumber:
                student['roll_number'] as String? ??
                profile['enrollment_no'] as String?,
            department:
                student['department'] as String? ??
                profile['department'] as String? ??
                profile['branch'] as String?,
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
            companyEvaluationScore: companyScore,
            companyEvaluationGrade: evalRow?['grade']?.toString(),
            attendanceRate: attendanceRateMap[internshipId],
            companyRemarks:
                evalRow?['remarks']?.toString() ??
                evalRow?['feedback']?.toString(),
            companyEvaluatorName:
                evaluatorId != null ? helperProfileNames[evaluatorId] : null,
            documents: docsMap[internshipId] ?? const [],
          ),
        );
      }

      return items;
    } on PostgrestException catch (e) {
      if (e.code == '42501' ||
          e.message.toLowerCase().contains('permission denied')) {
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
      throw StateError('Supabase client is not initialized.');
    }

    await AuthService.requireAuthenticatedClient(client: client);

    try {
      Map<String, dynamic> preloadedStudent = {};
      if (internshipId == null || internshipId.isEmpty) {
        try {
          final s = await client
              .from('students')
              .select('id, roll_number, department, batch_year, user_id, created_at, updated_at')
              .or('id.eq.$studentId,user_id.eq.$studentId')
              .maybeSingle();
          if (s != null) preloadedStudent = Map<String, dynamic>.from(s);
        } catch (_) {}
      }

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
        final candidateIds = <String>{
          studentId,
          if (preloadedStudent['id'] != null) preloadedStudent['id'].toString(),
          if (preloadedStudent['user_id'] != null)
            preloadedStudent['user_id'].toString(),
        }.toList();
        query = query.inFilter('student_id', candidateIds);
      }

      final response = await query
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response != null) {
        final map = Map<String, dynamic>.from(response);
        final effectiveStudentId = map['student_id']?.toString() ?? studentId;

        Map<String, dynamic> profile = {};
        Map<String, dynamic> student = preloadedStudent;

        if (student.isEmpty) {
          try {
            final s = await client
                .from('students')
                .select('id, roll_number, department, batch_year, user_id, created_at, updated_at')
                .or('user_id.eq.$effectiveStudentId,id.eq.$effectiveStudentId,id.eq.$studentId')
                .maybeSingle();
            if (s != null) student = Map<String, dynamic>.from(s);
          } catch (_) {}
        }

        final profileId =
            student['user_id']?.toString() ?? effectiveStudentId;
        try {
          final p = await client
              .from('profiles')
              .select('id, full_name, email, department, branch, phone, phone_number, address, avatar_url, is_active, created_at, updated_at, enrollment_no')
              .eq('id', profileId)
              .maybeSingle();
          if (p != null) profile = Map<String, dynamic>.from(p);
        } catch (_) {}

        final industry = map['industries'] is Map
            ? Map<String, dynamic>.from(map['industries'] as Map)
            : <String, dynamic>{};

        // Extract ITR map
        Map<String, dynamic>? itrMap;
        if (map['itrs'] is List && (map['itrs'] as List).isNotEmpty) {
          itrMap = Map<String, dynamic>.from(
            (map['itrs'] as List).first as Map,
          );
        } else if (map['itrs'] is Map) {
          itrMap = Map<String, dynamic>.from(map['itrs'] as Map);
        }

        // Extract Certificate map
        Map<String, dynamic>? certMap;
        if (map['certificates'] is List &&
            (map['certificates'] as List).isNotEmpty) {
          certMap = Map<String, dynamic>.from(
            (map['certificates'] as List).first as Map,
          );
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
          department:
              student['department'] as String? ??
              profile['department'] as String?,
          branch: profile['branch'] as String?,
          batchYear: student['batch_year'] is int
              ? student['batch_year'] as int
              : int.tryParse(student['batch_year']?.toString() ?? ''),
          phone:
              profile['phone'] as String? ?? profile['phone_number'] as String?,
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
          internshipTitle:
              map['internship_title'] as String? ?? map['title'] as String?,
          companyName:
              map['company_name'] as String? ?? industry['name'] as String?,
          internshipMode: map['mode'] as String?,
          startDate: map['start_date'] != null
              ? DateTime.tryParse(map['start_date'].toString())
              : null,
          endDate: map['end_date'] != null
              ? DateTime.tryParse(map['end_date'].toString())
              : null,
          internshipStatus: map['status'] as String?,
          progress: map['progress'] is num
              ? (map['progress'] as num).toInt()
              : 0,
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
          itrPresentationPath:
              itrMap?['project_presentation_path'] as String? ??
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
      Map<String, dynamic> sMap = {};
      try {
        final studentRes = await client
            .from('students')
            .select('id, roll_number, department, batch_year, user_id, created_at, updated_at')
            .or('id.eq.$studentId,user_id.eq.$studentId')
            .maybeSingle();
        if (studentRes != null) sMap = Map<String, dynamic>.from(studentRes);
      } catch (_) {}

      final effectiveUid = sMap['user_id']?.toString() ?? studentId;
      Map<String, dynamic> profile = {};
      try {
        final profRes = await client
            .from('profiles')
            .select('id, full_name, email, department, branch, phone, phone_number, address, avatar_url, is_active, created_at, updated_at, enrollment_no')
            .eq('id', effectiveUid)
            .maybeSingle();
        if (profRes != null) profile = Map<String, dynamic>.from(profRes);
      } catch (_) {}

      if (sMap.isNotEmpty || profile.isNotEmpty) {
        return StudentMonitoringDetail(
          studentId: studentId,
          userId: sMap['user_id'] as String? ?? profile['id'] as String?,
          studentName: profile['full_name'] as String? ?? 'Unknown Student',
          studentEmail: profile['email'] as String? ?? 'N/A',
          rollNumber: sMap['roll_number'] as String? ?? profile['enrollment_no'] as String?,
          department:
              sMap['department'] as String? ?? profile['department'] as String?,
          branch: profile['branch'] as String?,
          batchYear: sMap['batch_year'] is int
              ? sMap['batch_year'] as int
              : int.tryParse(sMap['batch_year']?.toString() ?? ''),
          phone:
              profile['phone'] as String? ?? profile['phone_number'] as String?,
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
      if (e.code == '42501' ||
          e.message.toLowerCase().contains('permission denied')) {
        throw const UnauthorizedException(
          'Your account does not have permission to access student details.',
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
      final signedUrl = await client.storage
          .from(bucket)
          .createSignedUrl(path, 3600);
      return signedUrl;
    } catch (_) {
      try {
        return client.storage.from(bucket).getPublicUrl(path);
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
    final client = _client;
    if (client == null) {
      throw StateError('Supabase is not initialized.');
    }

    await AuthService.requireAuthenticatedClient(client: client);
    final currentUserId = client.auth.currentUser?.id;
    String? verifierName;
    if (currentUserId != null) {
      try {
        final prof = await client
            .from('profiles')
            .select('full_name')
            .eq('id', currentUserId)
            .maybeSingle();
        verifierName = prof?['full_name']?.toString();
      } catch (_) {}
    }

    final normalizedStatus =
        (status == 'approved' || status == 'verified') ? 'approved' : 'rejected';

    await client
        .from('internship_documents')
        .update({
          'faculty_status': normalizedStatus,
          'faculty_rejection_reason':
              normalizedStatus == 'rejected' ? rejectionReason : null,
          'faculty_remarks': remarks,
          'faculty_verified_by': currentUserId,
          if (verifierName != null && verifierName.isNotEmpty)
            'faculty_verified_by_name': verifierName,
          'faculty_verified_at': DateTime.now().toIso8601String(),
        })
        .eq('id', documentId);
  }
}
