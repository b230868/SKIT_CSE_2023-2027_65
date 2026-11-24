import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../models/placement_models.dart';
import 'placement_repository.dart';

class SupabasePlacementRepository implements PlacementRepository {
  static const String _bucket = 'placement-notices';
  final SupabaseClient? _providedClient;

  SupabasePlacementRepository({SupabaseClient? client}) : _providedClient = client;

  SupabaseClient get _client => _providedClient ?? Supabase.instance.client;

  Future<SupabaseClient> _authedClient() async {
    return AuthService.requireAuthenticatedClient(client: _providedClient);
  }

  String _contentTypeFor(String? ext) {
    switch ((ext ?? '').toLowerCase()) {
      case 'pdf':
        return 'application/pdf';
      case 'png':
        return 'image/png';
      case 'jpg':
      case 'jpeg':
        return 'image/jpeg';
      case 'webp':
        return 'image/webp';
      case 'doc':
        return 'application/msword';
      case 'docx':
        return 'application/vnd.openxmlformats-officedocument.wordprocessingml.document';
      default:
        return 'application/octet-stream';
    }
  }

  String _fileTypeFor(String? ext) {
    final e = (ext ?? '').toLowerCase();
    if (e == 'pdf') return 'pdf';
    if (['png', 'jpg', 'jpeg', 'webp', 'gif'].contains(e)) return 'image';
    if (['doc', 'docx'].contains(e)) return 'doc';
    return 'other';
  }

  String _defaultTitle(String companyName, OpportunityType type) {
    return '${companyName.trim()} - ${type.label}';
  }

  Future<String?> _resolveCurrentBranch(SupabaseClient client) async {
    final uid = client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final prof = await client
          .from('profiles')
          .select('branch, department')
          .eq('id', uid)
          .maybeSingle();
      final b = prof?['branch']?.toString().trim();
      if (b != null && b.isNotEmpty) return b;
      final d = prof?['department']?.toString().trim();
      if (d != null && d.isNotEmpty) return d;
    } catch (_) {}

    try {
      final stud = await client
          .from('students')
          .select('department')
          .eq('user_id', uid)
          .maybeSingle();
      final sd = stud?['department']?.toString().trim();
      if (sd != null && sd.isNotEmpty) return sd;
    } catch (_) {}

    final meta = client.auth.currentUser?.userMetadata ?? {};
    final mb = meta['branch']?.toString().trim();
    return (mb != null && mb.isNotEmpty) ? mb : null;
  }

  @override
  Future<List<String>> getAvailableBranches() async {
    final client = await _authedClient();
    final set = <String>{};

    try {
      final rpcRes = await client.rpc('get_available_branches');
      if (rpcRes is List) {
        for (final item in rpcRes) {
          final v = item?.toString().trim() ?? '';
          if (v.isNotEmpty) set.add(v);
        }
      }
    } catch (_) {}

    if (set.isEmpty) {
      try {
        final profs = await client.from('profiles').select('branch, department');
        for (final row in profs as List) {
          final b = row['branch']?.toString().trim();
          final d = row['department']?.toString().trim();
          if (b != null && b.isNotEmpty) set.add(b);
          if (d != null && d.isNotEmpty) set.add(d);
        }
      } catch (_) {}

      try {
        final studs = await client.from('students').select('department');
        for (final row in studs as List) {
          final d = row['department']?.toString().trim();
          if (d != null && d.isNotEmpty) set.add(d);
        }
      } catch (_) {}

      try {
        final notices = await client.from('placement_notices').select('target_branches');
        for (final row in notices as List) {
          final list = row['target_branches'];
          if (list is List) {
            for (final b in list) {
              final s = b?.toString().trim() ?? '';
              if (s.isNotEmpty) set.add(s);
            }
          }
        }
      } catch (_) {}
    }

    final sorted = set.toList()..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return sorted;
  }

  @override
  Future<List<CompanyOption>> getCompanies() async {
    final client = await _authedClient();
    final seen = <String, CompanyOption>{};

    try {
      final rows = await client
          .from('industries')
          .select('id, name')
          .order('name', ascending: true);
      for (final r in rows as List) {
        final name = r['name']?.toString().trim() ?? '';
        if (name.isNotEmpty) {
          seen[name.toLowerCase()] = CompanyOption(
            id: r['id'].toString(),
            name: name,
          );
        }
      }
    } catch (_) {}

    try {
      final noticeRows = await client
          .from('placement_notices')
          .select('company_name')
          .order('created_at', ascending: false)
          .limit(200);
      for (final r in noticeRows as List) {
        final name = r['company_name']?.toString().trim() ?? '';
        if (name.isNotEmpty && !seen.containsKey(name.toLowerCase())) {
          seen[name.toLowerCase()] = CompanyOption(id: '', name: name);
        }
      }
    } catch (_) {}

    final list = seen.values.toList()
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return list;
  }

  @override
  Future<TpPlacementSummary> getDashboardSummary() async {
    final client = await _authedClient();
    try {
      final res = await client.rpc('get_tp_dashboard_summary');
      if (res is Map) {
        return TpPlacementSummary.fromMap(Map<String, dynamic>.from(res));
      }
    } catch (_) {}

    // Fallback aggregation if RPC is unavailable
    final notices = await getNotices(studentView: false);
    final queries = await getQueries(tpView: true);
    final nocs = await getNocRequests(tpView: true);
    final faqs = await getFaqs(includeInactive: false);

    return TpPlacementSummary(
      activeOpportunities: notices.where((n) => !n.isClosed).length,
      newNotices: notices
          .where((n) => !n.isClosed && DateTime.now().difference(n.createdAt).inHours <= 48)
          .length,
      upcomingDrives: notices
          .where(
            (n) =>
                n.status == NoticeStatus.upcoming ||
                (n.recruitmentDate != null && n.recruitmentDate!.isAfter(DateTime.now())),
          )
          .length,
      closingSoon: notices.where((n) => n.isClosingSoon).length,
      pendingNocRequests: nocs.where((n) => n.status == 'pending').length,
      unansweredQueries: queries
          .where((q) => q.status == QueryStatus.open || (q.status != QueryStatus.closed && !q.isReadByTp))
          .length,
      activeFaqs: faqs.length,
    );
  }

  @override
  Future<List<PlacementNotice>> getNotices({
    bool studentView = false,
    String? studentBranch,
  }) async {
    final client = await _authedClient();
    final uid = client.auth.currentUser?.id;

    final rows = await client
        .from('placement_notices')
        .select('*, placement_notice_attachments(*)')
        .order('created_at', ascending: false);

    final readIds = <String>{};
    if (uid != null) {
      try {
        final reads = await client
            .from('placement_notice_reads')
            .select('notice_id')
            .eq('user_id', uid);
        for (final r in reads as List) {
          final nid = r['notice_id']?.toString();
          if (nid != null) readIds.add(nid);
        }
      } catch (_) {}
    }

    String? effectiveBranch = studentBranch;
    if (studentView && (effectiveBranch == null || effectiveBranch.trim().isEmpty)) {
      effectiveBranch = await _resolveCurrentBranch(client);
    }

    final list = <PlacementNotice>[];
    for (final r in rows as List) {
      final map = Map<String, dynamic>.from(r as Map);
      final id = map['id']?.toString() ?? '';
      final notice = PlacementNotice.fromMap(map, isRead: readIds.contains(id));

      if (studentView) {
        if (!BranchUtils.matches(
          notice.targetBranches,
          notice.isAllBranches,
          effectiveBranch,
        )) {
          continue;
        }
      }
      list.add(notice);
    }

    return list;
  }

  @override
  Future<PlacementNotice?> getNoticeById(String noticeId) async {
    final client = await _authedClient();
    final uid = client.auth.currentUser?.id;

    final row = await client
        .from('placement_notices')
        .select('*, placement_notice_attachments(*)')
        .eq('id', noticeId)
        .maybeSingle();

    if (row == null) return null;

    bool isRead = false;
    if (uid != null) {
      try {
        final readRow = await client
            .from('placement_notice_reads')
            .select('notice_id')
            .eq('notice_id', noticeId)
            .eq('user_id', uid)
            .maybeSingle();
        isRead = readRow != null;
      } catch (_) {}
    }

    return PlacementNotice.fromMap(Map<String, dynamic>.from(row), isRead: isRead);
  }

  Future<void> _uploadNoticeAttachments(
    SupabaseClient client,
    String noticeId,
    List<PlatformFile> files,
  ) async {
    final uid = client.auth.currentUser?.id;
    for (final file in files) {
      final bytes = await file.readAsBytes();
      final safeName = file.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      final storagePath =
          'notices/$noticeId/${DateTime.now().millisecondsSinceEpoch}_$safeName';

      await client.storage.from(_bucket).uploadBinary(
            storagePath,
            bytes,
            fileOptions: FileOptions(contentType: _contentTypeFor(file.extension)),
          );

      await client.from('placement_notice_attachments').insert({
        'notice_id': noticeId,
        'file_name': file.name,
        'file_path': storagePath,
        'file_type': _fileTypeFor(file.extension),
        'mime_type': _contentTypeFor(file.extension),
        'file_size': bytes.length,
        'uploaded_by': uid,
      });
    }
  }

  @override
  Future<PlacementNotice> createNotice({
    required String companyName,
    String? industryId,
    required OpportunityType opportunityType,
    String? title,
    String? description,
    String? eligibility,
    String? recruitmentProcess,
    String? additionalNotes,
    String? applicationLink,
    DateTime? applicationDeadline,
    DateTime? recruitmentDate,
    required bool isAllBranches,
    required List<String> targetBranches,
    required NoticeStatus status,
    bool notifyStudents = true,
    List<PlatformFile> attachments = const [],
  }) async {
    final client = await _authedClient();
    final uid = client.auth.currentUser?.id;

    final cleanTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : _defaultTitle(companyName, opportunityType);

    String? resolvedIndustryId = (industryId != null && industryId.trim().isNotEmpty)
        ? industryId.trim()
        : null;
    if (resolvedIndustryId == null) {
      try {
        final match = await client
            .from('industries')
            .select('id')
            .ilike('name', companyName.trim())
            .maybeSingle();
        resolvedIndustryId = match?['id']?.toString();
      } catch (_) {}
    }

    final payload = <String, dynamic>{
      'company_name': companyName.trim(),
      'industry_id': resolvedIndustryId,
      'opportunity_type': opportunityType.value,
      'title': cleanTitle,
      'description': description?.trim().isEmpty == true ? null : description?.trim(),
      'eligibility': eligibility?.trim().isEmpty == true ? null : eligibility?.trim(),
      'recruitment_process':
          recruitmentProcess?.trim().isEmpty == true ? null : recruitmentProcess?.trim(),
      'additional_notes':
          additionalNotes?.trim().isEmpty == true ? null : additionalNotes?.trim(),
      'application_link':
          applicationLink?.trim().isEmpty == true ? null : applicationLink?.trim(),
      'application_deadline': applicationDeadline?.toUtc().toIso8601String(),
      'recruitment_date': recruitmentDate?.toUtc().toIso8601String(),
      'is_all_branches': isAllBranches,
      'target_branches': isAllBranches ? <String>[] : targetBranches,
      'status': status.value,
      'notify_students': notifyStudents,
      'created_by': uid,
    };

    final inserted = await client
        .from('placement_notices')
        .insert(payload)
        .select()
        .single();

    final noticeId = inserted['id'].toString();

    if (attachments.isNotEmpty) {
      await _uploadNoticeAttachments(client, noticeId, attachments);
    }

    return (await getNoticeById(noticeId)) ??
        PlacementNotice.fromMap(Map<String, dynamic>.from(inserted));
  }

  @override
  Future<PlacementNotice> updateNotice({
    required String noticeId,
    required String companyName,
    String? industryId,
    required OpportunityType opportunityType,
    String? title,
    String? description,
    String? eligibility,
    String? recruitmentProcess,
    String? additionalNotes,
    String? applicationLink,
    DateTime? applicationDeadline,
    DateTime? recruitmentDate,
    required bool isAllBranches,
    required List<String> targetBranches,
    required NoticeStatus status,
    bool notifyStudents = true,
    List<PlatformFile> newAttachments = const [],
  }) async {
    final client = await _authedClient();
    final cleanTitle = (title != null && title.trim().isNotEmpty)
        ? title.trim()
        : _defaultTitle(companyName, opportunityType);

    final updated = await client
        .from('placement_notices')
        .update({
          'company_name': companyName.trim(),
          'industry_id': (industryId != null && industryId.isNotEmpty) ? industryId : null,
          'opportunity_type': opportunityType.value,
          'title': cleanTitle,
          'description': description?.trim().isEmpty == true ? null : description?.trim(),
          'eligibility': eligibility?.trim().isEmpty == true ? null : eligibility?.trim(),
          'recruitment_process':
              recruitmentProcess?.trim().isEmpty == true ? null : recruitmentProcess?.trim(),
          'additional_notes':
              additionalNotes?.trim().isEmpty == true ? null : additionalNotes?.trim(),
          'application_link':
              applicationLink?.trim().isEmpty == true ? null : applicationLink?.trim(),
          'application_deadline': applicationDeadline?.toUtc().toIso8601String(),
          'recruitment_date': recruitmentDate?.toUtc().toIso8601String(),
          'is_all_branches': isAllBranches,
          'target_branches': isAllBranches ? <String>[] : targetBranches,
          'status': status.value,
          'notify_students': notifyStudents,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', noticeId)
        .select()
        .single();

    if (newAttachments.isNotEmpty) {
      await _uploadNoticeAttachments(client, noticeId, newAttachments);
    }

    return (await getNoticeById(noticeId)) ??
        PlacementNotice.fromMap(Map<String, dynamic>.from(updated));
  }

  @override
  Future<void> updateNoticeStatus(String noticeId, NoticeStatus status) async {
    final client = await _authedClient();
    await client.from('placement_notices').update({
      'status': status.value,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', noticeId);
  }

  @override
  Future<void> deleteNotice(String noticeId) async {
    final client = await _authedClient();
    try {
      final attachments = await client
          .from('placement_notice_attachments')
          .select('file_path')
          .eq('notice_id', noticeId);
      final paths = (attachments as List)
          .map((e) => e['file_path']?.toString() ?? '')
          .where((p) => p.isNotEmpty)
          .toList();
      if (paths.isNotEmpty) {
        await client.storage.from(_bucket).remove(paths);
      }
    } catch (_) {}

    await client.from('placement_notices').delete().eq('id', noticeId);
  }

  @override
  Future<void> markNoticeRead(String noticeId) async {
    final client = await _authedClient();
    final uid = client.auth.currentUser?.id;
    if (uid == null) return;
    try {
      await client.from('placement_notice_reads').upsert({
        'notice_id': noticeId,
        'user_id': uid,
        'read_at': DateTime.now().toUtc().toIso8601String(),
      });
    } catch (_) {}
  }

  @override
  Future<String?> getAttachmentUrl(
    String filePath, {
    String bucket = _bucket,
  }) async {
    if (filePath.trim().isEmpty) return null;
    if (filePath.startsWith('http://') || filePath.startsWith('https://')) {
      return filePath;
    }
    try {
      return await _client.storage.from(bucket).createSignedUrl(filePath, 3600);
    } catch (_) {
      try {
        return _client.storage.from(bucket).getPublicUrl(filePath);
      } catch (_) {
        return null;
      }
    }
  }

  @override
  Future<List<TpFaq>> getFaqs({bool includeInactive = false}) async {
    final client = await _authedClient();
    var query = client.from('tp_faqs').select();
    if (!includeInactive) {
      query = query.eq('is_active', true);
    }
    final rows = await query
        .order('usage_count', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List)
        .map((r) => TpFaq.fromMap(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  @override
  Future<TpFaq> upsertFaq({
    String? id,
    required String category,
    required String question,
    required String answer,
    List<String> keywords = const [],
    List<String> targetBranches = const [],
    bool isAllBranches = true,
    bool isActive = true,
  }) async {
    final client = await _authedClient();
    final uid = client.auth.currentUser?.id;
    final payload = <String, dynamic>{
      'category': category.trim(),
      'question': question.trim(),
      'answer': answer.trim(),
      'keywords': keywords.where((k) => k.trim().isNotEmpty).toList(),
      'target_branches': isAllBranches ? <String>[] : targetBranches,
      'is_all_branches': isAllBranches,
      'is_active': isActive,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    if (id != null && id.isNotEmpty) {
      final updated = await client
          .from('tp_faqs')
          .update(payload)
          .eq('id', id)
          .select()
          .single();
      return TpFaq.fromMap(Map<String, dynamic>.from(updated));
    } else {
      payload['created_by'] = uid;
      final inserted = await client
          .from('tp_faqs')
          .insert(payload)
          .select()
          .single();
      return TpFaq.fromMap(Map<String, dynamic>.from(inserted));
    }
  }

  @override
  Future<void> deleteFaq(String faqId) async {
    final client = await _authedClient();
    await client.from('tp_faqs').delete().eq('id', faqId);
  }

  @override
  Future<void> markFaqHelpful(String faqId) async {
    final client = await _authedClient();
    try {
      await client.rpc('increment_faq_usage', params: {'p_faq_id': faqId});
    } catch (_) {}
  }

  @override
  Future<List<StudentQuery>> getQueries({bool tpView = false}) async {
    final client = await _authedClient();
    final uid = client.auth.currentUser?.id;

    var query = client.from('student_queries').select('''
      *,
      placement_notices ( title, company_name ),
      student_query_replies ( * )
    ''');

    if (!tpView && uid != null) {
      query = query.eq('student_id', uid);
    }

    final rows = await query.order('created_at', ascending: false);
    final rawList = (rows as List)
        .map((r) => Map<String, dynamic>.from(r as Map))
        .toList();

    final userIds = <String>{};
    for (final q in rawList) {
      final sid = q['student_id']?.toString();
      if (sid != null) userIds.add(sid);
      final reps = q['student_query_replies'];
      if (reps is List) {
        for (final rep in reps) {
          final rid = (rep as Map)['sender_id']?.toString();
          if (rid != null) userIds.add(rid);
        }
      }
    }

    final profileMap = <String, Map<String, dynamic>>{};
    if (userIds.isNotEmpty) {
      try {
        final profs = await client
            .from('profiles')
            .select('id, full_name, enrollment_no, branch')
            .inFilter('id', userIds.toList());
        for (final p in profs as List) {
          final m = Map<String, dynamic>.from(p as Map);
          final id = m['id']?.toString();
          if (id != null) profileMap[id] = m;
        }
      } catch (_) {}
    }

    return rawList.map((m) {
      final sid = m['student_id']?.toString() ?? '';
      final sProf = profileMap[sid];
      final rawReps = m['student_query_replies'] as List? ?? const [];
      final replies = rawReps.map((r) {
        final rm = Map<String, dynamic>.from(r as Map);
        final senderId = rm['sender_id']?.toString() ?? '';
        final senderProf = profileMap[senderId];
        return StudentQueryReply.fromMap({
          ...rm,
          'sender_name': senderProf?['full_name'],
        });
      }).toList()
        ..sort((a, b) => a.createdAt.compareTo(b.createdAt));

      return StudentQuery.fromMap(
        m,
        studentName: sProf?['full_name']?.toString(),
        studentRollNumber: sProf?['enrollment_no']?.toString(),
        replies: replies,
      );
    }).toList();
  }

  @override
  Future<StudentQuery> createQuery({
    String? noticeId,
    String? companyName,
    required String category,
    required String question,
  }) async {
    final client = await _authedClient();
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw const UnauthenticatedException();

    final branch = await _resolveCurrentBranch(client);
    String? resolvedCompany = companyName?.trim();
    if ((resolvedCompany == null || resolvedCompany.isEmpty) && noticeId != null) {
      try {
        final n = await client
            .from('placement_notices')
            .select('company_name')
            .eq('id', noticeId)
            .maybeSingle();
        resolvedCompany = n?['company_name']?.toString();
      } catch (_) {}
    }

    final inserted = await client
        .from('student_queries')
        .insert({
          'student_id': uid,
          'notice_id': (noticeId != null && noticeId.isNotEmpty) ? noticeId : null,
          'company_name':
              (resolvedCompany != null && resolvedCompany.isNotEmpty) ? resolvedCompany : null,
          'student_branch': branch,
          'category': category.trim(),
          'question': question.trim(),
          'status': 'open',
          'is_read_by_tp': false,
        })
        .select()
        .single();

    return StudentQuery.fromMap(Map<String, dynamic>.from(inserted));
  }

  @override
  Future<StudentQueryReply> addQueryReply({
    required String queryId,
    required String message,
    required String senderRole,
  }) async {
    final client = await _authedClient();
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw const UnauthenticatedException();

    final inserted = await client
        .from('student_query_replies')
        .insert({
          'query_id': queryId,
          'sender_id': uid,
          'sender_role': senderRole,
          'message': message.trim(),
        })
        .select()
        .single();

    return StudentQueryReply.fromMap(Map<String, dynamic>.from(inserted));
  }

  @override
  Future<void> updateQueryStatus(String queryId, QueryStatus status) async {
    final client = await _authedClient();
    await client.from('student_queries').update({
      'status': status.value,
      'is_read_by_tp': true,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', queryId);
  }

  @override
  Future<void> markQueryRead({required String queryId, required bool isTp}) async {
    final client = await _authedClient();
    try {
      await client
          .from('student_queries')
          .update(isTp ? {'is_read_by_tp': true} : {'has_unread_reply': false})
          .eq('id', queryId);
    } catch (_) {}
  }

  @override
  Future<List<NocRequest>> getNocRequests({bool tpView = false}) async {
    final client = await _authedClient();
    final uid = client.auth.currentUser?.id;

    var formalQuery = client
        .from('noc_requests')
        .select('*, placement_notices(title)');
    if (!tpView && uid != null) {
      formalQuery = formalQuery.eq('student_id', uid);
    }
    final formalRows = await formalQuery.order('created_at', ascending: false);

    // Also include existing NOC documents from internship_documents so existing workflow is preserved
    List<dynamic> docNocRows = const [];
    try {
      var docQuery = client
          .from('internship_documents')
          .select('*, internships(id, student_id, company_name, title, internship_title)')
          .eq('doc_type', 'noc');
      if (!tpView && uid != null) {
        docQuery = docQuery.eq('student_id', uid);
      }
      docNocRows = await docQuery.order('created_at', ascending: false);
    } catch (_) {}

    final studentIds = <String>{};
    for (final r in formalRows as List) {
      final sid = r['student_id']?.toString();
      if (sid != null) studentIds.add(sid);
    }
    for (final d in docNocRows) {
      final sid = d['student_id']?.toString();
      if (sid != null) studentIds.add(sid);
    }

    final profileById = <String, Map<String, dynamic>>{};
    if (studentIds.isNotEmpty) {
      try {
        final profs = await client
            .from('profiles')
            .select('id, full_name, email, enrollment_no, branch, department')
            .inFilter('id', studentIds.toList());
        for (final p in profs as List) {
          final m = Map<String, dynamic>.from(p as Map);
          final id = m['id']?.toString();
          if (id != null) profileById[id] = m;
        }
      } catch (_) {}
    }

    final results = <NocRequest>[];
    for (final r in formalRows) {
      final m = Map<String, dynamic>.from(r as Map);
      final sid = m['student_id']?.toString() ?? '';
      final prof = profileById[sid];
      results.add(
        NocRequest.fromMap(
          m,
          studentName: prof?['full_name']?.toString(),
          studentEmail: prof?['email']?.toString(),
          rollNumber: m['roll_number']?.toString() ?? prof?['enrollment_no']?.toString(),
          studentBranch:
              m['student_branch']?.toString() ??
              prof?['branch']?.toString() ??
              prof?['department']?.toString(),
        ),
      );
    }

    for (final d in docNocRows) {
      final m = Map<String, dynamic>.from(d as Map);
      final sid = m['student_id']?.toString() ?? '';
      final prof = profileById[sid];
      final intern = m['internships'] is Map
          ? Map<String, dynamic>.from(m['internships'] as Map)
          : const <String, dynamic>{};
      final rawFacStatus = (m['faculty_status']?.toString() ?? 'pending').toLowerCase();
      final normalizedStatus =
          rawFacStatus == 'verified' || rawFacStatus == 'approved'
              ? 'approved'
              : (rawFacStatus == 'rejected' ? 'rejected' : 'pending');

      results.add(
        NocRequest(
          id: m['id']?.toString() ?? '',
          studentId: sid,
          studentName: prof?['full_name']?.toString(),
          studentEmail: prof?['email']?.toString(),
          rollNumber: prof?['enrollment_no']?.toString(),
          studentBranch: prof?['branch']?.toString() ?? prof?['department']?.toString(),
          internshipId: m['internship_id']?.toString(),
          companyName: intern['company_name']?.toString() ?? 'Internship NOC',
          opportunityTitle:
              intern['internship_title']?.toString() ?? intern['title']?.toString(),
          documentName: m['file_name']?.toString(),
          documentPath: m['file_path']?.toString(),
          status: normalizedStatus,
          tpRemarks: m['faculty_remarks']?.toString(),
          rejectionReason: m['faculty_rejection_reason']?.toString(),
          reviewedAt: m['faculty_verified_at'] != null
              ? DateTime.tryParse(m['faculty_verified_at'].toString())?.toLocal()
              : null,
          createdAt: m['created_at'] != null
              ? DateTime.tryParse(m['created_at'].toString())?.toLocal() ?? DateTime.now()
              : DateTime.now(),
          isLegacyDocument: true,
        ),
      );
    }

    results.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return results;
  }

  @override
  Future<NocRequest> submitNocRequest({
    String? internshipId,
    String? noticeId,
    required String companyName,
    String? opportunityTitle,
    String? studentRemarks,
    PlatformFile? attachment,
  }) async {
    final client = await _authedClient();
    final uid = client.auth.currentUser?.id;
    if (uid == null) throw const UnauthenticatedException();

    String? branch = await _resolveCurrentBranch(client);
    String? roll;
    try {
      final prof = await client
          .from('profiles')
          .select('enrollment_no')
          .eq('id', uid)
          .maybeSingle();
      roll = prof?['enrollment_no']?.toString();
    } catch (_) {}

    String? docName;
    String? docPath;
    if (attachment != null) {
      final bytes = await attachment.readAsBytes();
      final safeName = attachment.name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
      docPath = 'noc/$uid/${DateTime.now().millisecondsSinceEpoch}_$safeName';
      docName = attachment.name;
      await client.storage.from(_bucket).uploadBinary(
            docPath,
            bytes,
            fileOptions: FileOptions(contentType: _contentTypeFor(attachment.extension)),
          );
    }

    final inserted = await client
        .from('noc_requests')
        .insert({
          'student_id': uid,
          'internship_id': (internshipId != null && internshipId.isNotEmpty) ? internshipId : null,
          'notice_id': (noticeId != null && noticeId.isNotEmpty) ? noticeId : null,
          'company_name': companyName.trim(),
          'opportunity_title':
              opportunityTitle?.trim().isEmpty == true ? null : opportunityTitle?.trim(),
          'student_branch': branch,
          'roll_number': roll,
          'student_remarks':
              studentRemarks?.trim().isEmpty == true ? null : studentRemarks?.trim(),
          'document_name': docName,
          'document_path': docPath,
          'status': 'pending',
        })
        .select()
        .single();

    return NocRequest.fromMap(Map<String, dynamic>.from(inserted));
  }

  @override
  Future<void> reviewNocRequest({
    required NocRequest request,
    required String status,
    String? tpRemarks,
    String? rejectionReason,
  }) async {
    final client = await _authedClient();
    final uid = client.auth.currentUser?.id;
    final cleanStatus = status == 'approved' ? 'approved' : 'rejected';
    final cleanRemarks = tpRemarks?.trim().isEmpty == true ? null : tpRemarks?.trim();
    final cleanReason =
        cleanStatus == 'rejected' ? (rejectionReason?.trim() ?? cleanRemarks) : null;

    if (request.isLegacyDocument) {
      String? verifierName;
      if (uid != null) {
        try {
          final prof = await client
              .from('profiles')
              .select('full_name')
              .eq('id', uid)
              .maybeSingle();
          verifierName = prof?['full_name']?.toString();
        } catch (_) {}
      }

      await client.from('internship_documents').update({
        'faculty_status': cleanStatus,
        'faculty_remarks': cleanRemarks,
        'faculty_rejection_reason': cleanReason,
        'faculty_verified_by': uid,
        if (verifierName != null && verifierName.isNotEmpty)
          'faculty_verified_by_name': verifierName,
        'faculty_verified_at': DateTime.now().toUtc().toIso8601String(),
      }).eq('id', request.id);
      return;
    }

    await client.from('noc_requests').update({
      'status': cleanStatus,
      'tp_remarks': cleanRemarks,
      'rejection_reason': cleanReason,
      'reviewed_by': uid,
      'reviewed_at': DateTime.now().toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    }).eq('id', request.id);
  }
}
