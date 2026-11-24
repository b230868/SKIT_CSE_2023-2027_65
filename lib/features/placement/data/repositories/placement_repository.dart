import 'package:file_picker/file_picker.dart';

import '../models/placement_models.dart';

abstract interface class PlacementRepository {
  Future<List<String>> getAvailableBranches();
  Future<List<CompanyOption>> getCompanies();
  Future<TpPlacementSummary> getDashboardSummary();

  // Notices
  Future<List<PlacementNotice>> getNotices({
    bool studentView = false,
    String? studentBranch,
  });
  Future<PlacementNotice?> getNoticeById(String noticeId);
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
  });
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
  });
  Future<void> updateNoticeStatus(String noticeId, NoticeStatus status);
  Future<void> deleteNotice(String noticeId);
  Future<void> markNoticeRead(String noticeId);
  Future<String?> getAttachmentUrl(String filePath, {String bucket = 'placement-notices'});

  // FAQs
  Future<List<TpFaq>> getFaqs({bool includeInactive = false});
  Future<TpFaq> upsertFaq({
    String? id,
    required String category,
    required String question,
    required String answer,
    List<String> keywords = const [],
    List<String> targetBranches = const [],
    bool isAllBranches = true,
    bool isActive = true,
  });
  Future<void> deleteFaq(String faqId);
  Future<void> markFaqHelpful(String faqId);

  // Student Queries
  Future<List<StudentQuery>> getQueries({bool tpView = false});
  Future<StudentQuery> createQuery({
    String? noticeId,
    String? companyName,
    required String category,
    required String question,
  });
  Future<StudentQueryReply> addQueryReply({
    required String queryId,
    required String message,
    required String senderRole,
  });
  Future<void> updateQueryStatus(String queryId, QueryStatus status);
  Future<void> markQueryRead({required String queryId, required bool isTp});

  // NOC Requests (unified formal noc_requests + existing internship_documents NOCs)
  Future<List<NocRequest>> getNocRequests({bool tpView = false});
  Future<NocRequest> submitNocRequest({
    String? internshipId,
    String? noticeId,
    required String companyName,
    String? opportunityTitle,
    String? studentRemarks,
    PlatformFile? attachment,
  });
  Future<void> reviewNocRequest({
    required NocRequest request,
    required String status, // approved | rejected
    String? tpRemarks,
    String? rejectionReason,
  });
}
