import 'dart:math' as math;

enum OpportunityType {
  internship('internship', 'Internship'),
  fullTime('full_time', 'Full-time Job'),
  internshipPpo('internship_ppo', 'Internship + PPO'),
  campusRecruitment('campus_recruitment', 'Campus Recruitment'),
  other('other', 'Other');

  final String value;
  final String label;

  const OpportunityType(this.value, this.label);

  static OpportunityType fromString(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    return OpportunityType.values.firstWhere(
      (t) => t.value == v,
      orElse: () => OpportunityType.campusRecruitment,
    );
  }
}

enum NoticeStatus {
  open('open', 'Open'),
  upcoming('upcoming', 'Upcoming'),
  closed('closed', 'Closed');

  final String value;
  final String label;

  const NoticeStatus(this.value, this.label);

  static NoticeStatus fromString(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    return NoticeStatus.values.firstWhere(
      (s) => s.value == v,
      orElse: () => NoticeStatus.open,
    );
  }
}

enum QueryStatus {
  open('open', 'Open'),
  answered('answered', 'Answered'),
  closed('closed', 'Closed');

  final String value;
  final String label;

  const QueryStatus(this.value, this.label);

  static QueryStatus fromString(String? raw) {
    final v = (raw ?? '').trim().toLowerCase();
    return QueryStatus.values.firstWhere(
      (s) => s.value == v,
      orElse: () => QueryStatus.open,
    );
  }
}

class QueryCategories {
  static const List<String> all = [
    'Placement Notice',
    'Internship',
    'Eligibility',
    'NOC',
    'Application Process',
    'Recruitment Drive',
    'Placement Rules',
    'General',
  ];
}

class NoticeAttachment {
  final String id;
  final String noticeId;
  final String fileName;
  final String filePath;
  final String fileType; // pdf | image | doc | other
  final String? mimeType;
  final int? fileSize;
  final DateTime createdAt;

  const NoticeAttachment({
    required this.id,
    required this.noticeId,
    required this.fileName,
    required this.filePath,
    required this.fileType,
    this.mimeType,
    this.fileSize,
    required this.createdAt,
  });

  bool get isImage =>
      fileType == 'image' ||
      RegExp(r'\.(png|jpe?g|webp|gif)$', caseSensitive: false).hasMatch(fileName);

  bool get isPdf =>
      fileType == 'pdf' ||
      fileName.toLowerCase().endsWith('.pdf');

  factory NoticeAttachment.fromMap(Map<String, dynamic> m) {
    return NoticeAttachment(
      id: m['id']?.toString() ?? '',
      noticeId: m['notice_id']?.toString() ?? '',
      fileName: m['file_name']?.toString() ?? 'Attachment',
      filePath: m['file_path']?.toString() ?? '',
      fileType: m['file_type']?.toString() ?? 'pdf',
      mimeType: m['mime_type']?.toString(),
      fileSize: (m['file_size'] as num?)?.toInt(),
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class PlacementNotice {
  final String id;
  final String? industryId;
  final String companyName;
  final OpportunityType opportunityType;
  final String title;
  final String? description;
  final String? eligibility;
  final String? recruitmentProcess;
  final String? additionalNotes;
  final String? applicationLink;
  final DateTime? applicationDeadline;
  final DateTime? recruitmentDate;
  final bool isAllBranches;
  final List<String> targetBranches;
  final NoticeStatus status;
  final bool notifyStudents;
  final String? createdBy;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<NoticeAttachment> attachments;
  final bool isRead;

  const PlacementNotice({
    required this.id,
    this.industryId,
    required this.companyName,
    required this.opportunityType,
    required this.title,
    this.description,
    this.eligibility,
    this.recruitmentProcess,
    this.additionalNotes,
    this.applicationLink,
    this.applicationDeadline,
    this.recruitmentDate,
    required this.isAllBranches,
    required this.targetBranches,
    required this.status,
    this.notifyStudents = true,
    this.createdBy,
    required this.createdAt,
    required this.updatedAt,
    this.attachments = const [],
    this.isRead = false,
  });

  bool get isClosed =>
      status == NoticeStatus.closed ||
      (applicationDeadline != null && applicationDeadline!.isBefore(DateTime.now()));

  bool get isClosingSoon {
    if (isClosed || applicationDeadline == null) return false;
    final remaining = applicationDeadline!.difference(DateTime.now());
    return !remaining.isNegative && remaining.inHours <= 72;
  }

  bool get isNew {
    if (isRead || isClosed) return false;
    return DateTime.now().difference(createdAt).inHours <= 72;
  }

  String get effectiveBadgeLabel {
    if (isClosed) return 'Closed';
    if (isClosingSoon) return 'Closing Soon';
    if (status == NoticeStatus.upcoming) return 'Upcoming';
    if (isNew) return 'New';
    return 'Open';
  }

  String get branchesDisplay {
    if (isAllBranches || targetBranches.isEmpty) return 'All Branches';
    return targetBranches.join(', ');
  }

  PlacementNotice copyWith({
    bool? isRead,
    NoticeStatus? status,
    List<NoticeAttachment>? attachments,
  }) {
    return PlacementNotice(
      id: id,
      industryId: industryId,
      companyName: companyName,
      opportunityType: opportunityType,
      title: title,
      description: description,
      eligibility: eligibility,
      recruitmentProcess: recruitmentProcess,
      additionalNotes: additionalNotes,
      applicationLink: applicationLink,
      applicationDeadline: applicationDeadline,
      recruitmentDate: recruitmentDate,
      isAllBranches: isAllBranches,
      targetBranches: targetBranches,
      status: status ?? this.status,
      notifyStudents: notifyStudents,
      createdBy: createdBy,
      createdAt: createdAt,
      updatedAt: updatedAt,
      attachments: attachments ?? this.attachments,
      isRead: isRead ?? this.isRead,
    );
  }

  factory PlacementNotice.fromMap(
    Map<String, dynamic> m, {
    bool isRead = false,
    List<NoticeAttachment>? attachments,
  }) {
    final rawBranches = m['target_branches'];
    final branches = rawBranches is List
        ? rawBranches.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
        : <String>[];

    final rawAtt = m['placement_notice_attachments'] ?? m['attachments'];
    final parsedAttachments = attachments ??
        (rawAtt is List
            ? rawAtt
                .whereType<Map>()
                .map((a) => NoticeAttachment.fromMap(Map<String, dynamic>.from(a)))
                .toList()
            : <NoticeAttachment>[]);

    return PlacementNotice(
      id: m['id']?.toString() ?? '',
      industryId: m['industry_id']?.toString(),
      companyName: m['company_name']?.toString() ?? '',
      opportunityType: OpportunityType.fromString(m['opportunity_type']?.toString()),
      title: m['title']?.toString() ?? '',
      description: m['description']?.toString(),
      eligibility: m['eligibility']?.toString(),
      recruitmentProcess: m['recruitment_process']?.toString(),
      additionalNotes: m['additional_notes']?.toString(),
      applicationLink: m['application_link']?.toString(),
      applicationDeadline: m['application_deadline'] != null
          ? DateTime.tryParse(m['application_deadline'].toString())?.toLocal()
          : null,
      recruitmentDate: m['recruitment_date'] != null
          ? DateTime.tryParse(m['recruitment_date'].toString())?.toLocal()
          : null,
      isAllBranches: m['is_all_branches'] as bool? ?? branches.isEmpty,
      targetBranches: branches,
      status: NoticeStatus.fromString(m['status']?.toString()),
      notifyStudents: m['notify_students'] as bool? ?? true,
      createdBy: m['created_by']?.toString(),
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      updatedAt: m['updated_at'] != null
          ? DateTime.tryParse(m['updated_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      attachments: parsedAttachments,
      isRead: m['is_read'] as bool? ?? isRead,
    );
  }
}

class TpFaq {
  final String id;
  final String category;
  final String question;
  final String answer;
  final List<String> keywords;
  final List<String> targetBranches;
  final bool isAllBranches;
  final bool isActive;
  final int usageCount;
  final DateTime createdAt;

  const TpFaq({
    required this.id,
    required this.category,
    required this.question,
    required this.answer,
    this.keywords = const [],
    this.targetBranches = const [],
    this.isAllBranches = true,
    this.isActive = true,
    this.usageCount = 0,
    required this.createdAt,
  });

  factory TpFaq.fromMap(Map<String, dynamic> m) {
    final rawKeywords = m['keywords'];
    final rawBranches = m['target_branches'];
    return TpFaq(
      id: m['id']?.toString() ?? '',
      category: m['category']?.toString() ?? 'General',
      question: m['question']?.toString() ?? '',
      answer: m['answer']?.toString() ?? '',
      keywords: rawKeywords is List
          ? rawKeywords.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : const [],
      targetBranches: rawBranches is List
          ? rawBranches.map((e) => e.toString().trim()).where((e) => e.isNotEmpty).toList()
          : const [],
      isAllBranches: m['is_all_branches'] as bool? ?? true,
      isActive: m['is_active'] as bool? ?? true,
      usageCount: (m['usage_count'] as num?)?.toInt() ?? 0,
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class StudentQueryReply {
  final String id;
  final String queryId;
  final String senderId;
  final String senderRole;
  final String? senderName;
  final String message;
  final DateTime createdAt;

  const StudentQueryReply({
    required this.id,
    required this.queryId,
    required this.senderId,
    required this.senderRole,
    this.senderName,
    required this.message,
    required this.createdAt,
  });

  bool get isFromStaff {
    final r = senderRole.toLowerCase();
    return r.contains('tp') || r.contains('tnp') || r.contains('admin') || r.contains('faculty');
  }

  factory StudentQueryReply.fromMap(Map<String, dynamic> m) {
    final prof = m['profiles'] is Map ? Map<String, dynamic>.from(m['profiles'] as Map) : null;
    return StudentQueryReply(
      id: m['id']?.toString() ?? '',
      queryId: m['query_id']?.toString() ?? '',
      senderId: m['sender_id']?.toString() ?? '',
      senderRole: m['sender_role']?.toString() ?? 'student',
      senderName: m['sender_name']?.toString() ?? prof?['full_name']?.toString(),
      message: m['message']?.toString() ?? '',
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

class StudentQuery {
  final String id;
  final String studentId;
  final String? studentName;
  final String? studentRollNumber;
  final String? studentBranch;
  final String? noticeId;
  final String? noticeTitle;
  final String? companyName;
  final String category;
  final String question;
  final QueryStatus status;
  final bool hasUnreadReply;
  final bool isReadByTp;
  final DateTime? lastReplyAt;
  final DateTime createdAt;
  final List<StudentQueryReply> replies;

  const StudentQuery({
    required this.id,
    required this.studentId,
    this.studentName,
    this.studentRollNumber,
    this.studentBranch,
    this.noticeId,
    this.noticeTitle,
    this.companyName,
    required this.category,
    required this.question,
    required this.status,
    this.hasUnreadReply = false,
    this.isReadByTp = false,
    this.lastReplyAt,
    required this.createdAt,
    this.replies = const [],
  });

  factory StudentQuery.fromMap(
    Map<String, dynamic> m, {
    String? studentName,
    String? studentRollNumber,
    String? noticeTitle,
    List<StudentQueryReply>? replies,
  }) {
    final prof = m['profiles'] is Map ? Map<String, dynamic>.from(m['profiles'] as Map) : null;
    final notice = m['placement_notices'] is Map
        ? Map<String, dynamic>.from(m['placement_notices'] as Map)
        : null;
    final rawReplies = m['student_query_replies'] ?? m['replies'];
    final parsedReplies = replies ??
        (rawReplies is List
            ? rawReplies
                .whereType<Map>()
                .map((r) => StudentQueryReply.fromMap(Map<String, dynamic>.from(r)))
                .toList()
            : <StudentQueryReply>[]);
    parsedReplies.sort((a, b) => a.createdAt.compareTo(b.createdAt));

    return StudentQuery(
      id: m['id']?.toString() ?? '',
      studentId: m['student_id']?.toString() ?? '',
      studentName: studentName ?? m['student_name']?.toString() ?? prof?['full_name']?.toString(),
      studentRollNumber:
          studentRollNumber ?? m['student_roll_number']?.toString() ?? prof?['enrollment_no']?.toString(),
      studentBranch: m['student_branch']?.toString() ?? prof?['branch']?.toString(),
      noticeId: m['notice_id']?.toString(),
      noticeTitle: noticeTitle ?? m['notice_title']?.toString() ?? notice?['title']?.toString(),
      companyName: m['company_name']?.toString() ?? notice?['company_name']?.toString(),
      category: m['category']?.toString() ?? 'General',
      question: m['question']?.toString() ?? '',
      status: QueryStatus.fromString(m['status']?.toString()),
      hasUnreadReply: m['has_unread_reply'] as bool? ?? false,
      isReadByTp: m['is_read_by_tp'] as bool? ?? false,
      lastReplyAt: m['last_reply_at'] != null
          ? DateTime.tryParse(m['last_reply_at'].toString())?.toLocal()
          : null,
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      replies: parsedReplies,
    );
  }
}

/// Represents both formal `noc_requests` and existing `internship_documents` (`doc_type == 'noc'`)
/// so T&P preserves and manages all NOC workflows in one unified view.
class NocRequest {
  final String id;
  final String studentId;
  final String? studentName;
  final String? studentEmail;
  final String? rollNumber;
  final String? studentBranch;
  final String? internshipId;
  final String? noticeId;
  final String companyName;
  final String? opportunityTitle;
  final String? studentRemarks;
  final String? documentName;
  final String? documentPath;
  final String status; // pending | approved | rejected
  final String? tpRemarks;
  final String? rejectionReason;
  final DateTime? reviewedAt;
  final DateTime createdAt;
  final bool isLegacyDocument; // true if sourced from internship_documents(doc_type='noc')

  const NocRequest({
    required this.id,
    required this.studentId,
    this.studentName,
    this.studentEmail,
    this.rollNumber,
    this.studentBranch,
    this.internshipId,
    this.noticeId,
    required this.companyName,
    this.opportunityTitle,
    this.studentRemarks,
    this.documentName,
    this.documentPath,
    required this.status,
    this.tpRemarks,
    this.rejectionReason,
    this.reviewedAt,
    required this.createdAt,
    this.isLegacyDocument = false,
  });

  String get storageBucket => isLegacyDocument ? 'internship-docs' : 'placement-notices';

  factory NocRequest.fromMap(
    Map<String, dynamic> m, {
    String? studentName,
    String? studentEmail,
    String? rollNumber,
    String? studentBranch,
  }) {
    return NocRequest(
      id: m['id']?.toString() ?? '',
      studentId: m['student_id']?.toString() ?? '',
      studentName: studentName ?? m['student_name']?.toString(),
      studentEmail: studentEmail ?? m['student_email']?.toString(),
      rollNumber: rollNumber ?? m['effective_roll_number']?.toString() ?? m['roll_number']?.toString(),
      studentBranch: studentBranch ?? m['effective_branch']?.toString() ?? m['student_branch']?.toString(),
      internshipId: m['internship_id']?.toString(),
      noticeId: m['notice_id']?.toString(),
      companyName: m['company_name']?.toString() ?? 'Company',
      opportunityTitle: m['opportunity_title']?.toString() ?? m['notice_title']?.toString(),
      studentRemarks: m['student_remarks']?.toString(),
      documentName: m['document_name']?.toString(),
      documentPath: m['document_path']?.toString(),
      status: (m['status']?.toString() ?? 'pending').toLowerCase(),
      tpRemarks: m['tp_remarks']?.toString(),
      rejectionReason: m['rejection_reason']?.toString(),
      reviewedAt: m['reviewed_at'] != null
          ? DateTime.tryParse(m['reviewed_at'].toString())?.toLocal()
          : null,
      createdAt: m['created_at'] != null
          ? DateTime.tryParse(m['created_at'].toString())?.toLocal() ?? DateTime.now()
          : DateTime.now(),
      isLegacyDocument: false,
    );
  }
}

class TpPlacementSummary {
  final int activeOpportunities;
  final int newNotices;
  final int upcomingDrives;
  final int closingSoon;
  final int pendingNocRequests;
  final int unansweredQueries;
  final int activeFaqs;

  const TpPlacementSummary({
    this.activeOpportunities = 0,
    this.newNotices = 0,
    this.upcomingDrives = 0,
    this.closingSoon = 0,
    this.pendingNocRequests = 0,
    this.unansweredQueries = 0,
    this.activeFaqs = 0,
  });

  factory TpPlacementSummary.fromMap(Map<String, dynamic> m) {
    int toInt(dynamic v) => (v as num?)?.toInt() ?? 0;
    return TpPlacementSummary(
      activeOpportunities: toInt(m['active_opportunities']),
      newNotices: toInt(m['new_notices']),
      upcomingDrives: toInt(m['upcoming_drives']),
      closingSoon: toInt(m['closing_soon']),
      pendingNocRequests: toInt(m['pending_noc_requests']),
      unansweredQueries: toInt(m['unanswered_queries']),
      activeFaqs: toInt(m['active_faqs']),
    );
  }
}

class CompanyOption {
  final String id;
  final String name;

  const CompanyOption({required this.id, required this.name});
}

class BranchUtils {
  static String normalize(String? raw) {
    final clean = (raw ?? '').toLowerCase().trim().replaceAll(RegExp(r'\s+'), ' ');
    if (clean.isEmpty) return '';
    const aliases = <String, String>{
      'cse': 'cse',
      'cs': 'cse',
      'computer science': 'cse',
      'computer science & engineering': 'cse',
      'computer science and engineering': 'cse',
      'it': 'it',
      'information technology': 'it',
      'iot': 'iot',
      'internet of things': 'iot',
      'cse-iot': 'iot',
      'cse (iot)': 'iot',
      'ce': 'civil',
      'civil': 'civil',
      'civil engineering': 'civil',
      'me': 'mechanical',
      'mech': 'mechanical',
      'mechanical': 'mechanical',
      'mechanical engineering': 'mechanical',
      'ee': 'electrical',
      'electrical': 'electrical',
      'electrical engineering': 'electrical',
      'ece': 'ece',
      'ec': 'ece',
      'electronics': 'ece',
      'electronics & communication': 'ece',
      'electronics and communication engineering': 'ece',
      'ai': 'ai',
      'aiml': 'ai',
      'ai & ml': 'ai',
      'aids': 'ai',
    };
    return aliases[clean] ?? clean;
  }

  static bool matches(
    List<String> targetBranches,
    bool isAllBranches,
    String? studentBranch,
  ) {
    if (isAllBranches || targetBranches.isEmpty) return true;
    final normStudent = normalize(studentBranch);
    if (normStudent.isEmpty) return false;
    for (final b in targetBranches) {
      final lower = b.trim().toLowerCase();
      if (lower == 'all' || lower == 'all branches') return true;
      if (normalize(b) == normStudent) return true;
    }
    return false;
  }
}

/// Deterministic, fast client-side smart FAQ suggestion matcher using keywords,
/// category, branch relevance, and token overlap.
class FaqMatcher {
  static const _stopWords = {
    'the', 'is', 'are', 'for', 'and', 'can', 'how', 'what', 'when', 'where',
    'why', 'will', 'this', 'that', 'with', 'from', 'have', 'has', 'does',
    'kya', 'hai', 'liye', 'kaise', 'hoga', 'karna', 'mein', 'ko', 'ka', 'ki',
    'ke', 'se', 'please', 'tell', 'about', 'regarding',
  };

  static List<String> _tokenize(String input) {
    return input
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .split(RegExp(r'\s+'))
        .where((t) => t.length >= 2 && !_stopWords.contains(t))
        .toList();
  }

  static List<TpFaq> suggest(
    String queryText,
    List<TpFaq> faqs, {
    String? category,
    String? branch,
    int limit = 4,
  }) {
    final trimmed = queryText.trim().toLowerCase();
    if (trimmed.length < 3) return const [];

    final tokens = _tokenize(trimmed);
    final scored = <({TpFaq faq, double score})>[];

    for (final faq in faqs) {
      if (!faq.isActive) continue;
      if (branch != null &&
          branch.isNotEmpty &&
          !faq.isAllBranches &&
          !BranchUtils.matches(faq.targetBranches, faq.isAllBranches, branch)) {
        continue;
      }

      double score = 0;
      final q = faq.question.toLowerCase();
      final a = faq.answer.toLowerCase();
      final kws = faq.keywords.map((k) => k.toLowerCase()).toList();

      if (q.contains(trimmed)) score += 10;

      for (final token in tokens) {
        if (kws.any((k) => k == token || k.contains(token) || token.contains(k))) {
          score += 4.5;
        }
        if (q.contains(token)) {
          score += 3.0;
        } else if (a.contains(token)) {
          score += 1.5;
        } else if (token.length >= 4) {
          // Prefix / stem tolerance for multilingual or inflected terms (e.g. approve/approval)
          final prefix = token.substring(0, math.min(5, token.length));
          if (q.contains(prefix) || kws.any((k) => k.contains(prefix))) {
            score += 2.0;
          }
        }
      }

      if (category != null &&
          category.isNotEmpty &&
          faq.category.toLowerCase() == category.toLowerCase()) {
        score += 2.0;
      }

      if (score >= 2.5) {
        score += math.min(1.5, faq.usageCount * 0.1);
        scored.add((faq: faq, score: score));
      }
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.take(limit).map((e) => e.faq).toList();
  }
}
