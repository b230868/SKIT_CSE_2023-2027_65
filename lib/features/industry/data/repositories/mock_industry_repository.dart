import '../../../internship/models/internship.dart';
import '../models/industry_attendance_model.dart';
import '../models/industry_dashboard_data.dart';
import '../models/industry_internship_model.dart';
import 'industry_repository.dart';

class MockIndustryRepository implements IndustryRepository {
  final List<IndustryInternshipModel> _allInternships;
  final IndustryDashboardData? _customDashboardData;
  final String? companyName;
  final bool hasVerifiedCompany;
  final Map<String, List<IndustryAttendanceRecord>> _attendanceRecords = {};

  MockIndustryRepository({
    List<IndustryInternshipModel>? internships,
    IndustryDashboardData? dashboardData,
    this.companyName,
    this.hasVerifiedCompany = true,
  }) : _allInternships = internships != null
           ? List.of(internships)
           : [
               const IndustryInternshipModel(
                 id: '1',
                 studentName: 'Rahul Sharma',
                 internshipTitle: 'Software Development Intern',
                 status: 'active',
                 progress: 65,
                 itrStatus: 'submitted',
                 evaluationStatus: 'pending',
                 studentId: 'student-1',
                 studentRollNo: 'CS2026-042',
                 branch: 'Computer Science',
                 companyName: 'TechNova Solutions',
                 attendanceRate: 92.0,
                 offerLetterStatus: 'issued',
                 certificateStatus: 'pending',
               ),
               const IndustryInternshipModel(
                 id: '2',
                 studentName: 'Priya Singh',
                 internshipTitle: 'Data Analytics Intern',
                 status: 'active',
                 progress: 80,
                 itrStatus: 'under_review',
                 evaluationStatus: 'in_progress',
                 studentId: 'student-2',
                 studentRollNo: 'DA2026-015',
                 branch: 'Data Science',
                 companyName: 'TechNova Solutions',
                 attendanceRate: 88.0,
                 offerLetterStatus: 'verified',
                 certificateStatus: 'pending',
               ),
               const IndustryInternshipModel(
                 id: '3',
                 studentName: 'Aman Verma',
                 internshipTitle: 'Flutter Development Intern',
                 status: 'completed',
                 progress: 100,
                 itrStatus: 'approved',
                 evaluationStatus: 'verified',
                 studentId: 'student-3',
                 studentRollNo: 'CS2026-088',
                 branch: 'Computer Science',
                 companyName: 'TechNova Solutions',
                 attendanceRate: 96.0,
                 offerLetterStatus: 'verified',
                 certificateStatus: 'issued',
               ),
             ],
       _customDashboardData = dashboardData {
    // Seed initial attendance records for testing
    _attendanceRecords['1'] = [
      IndustryAttendanceRecord(
        id: 'att-1',
        internshipId: '1',
        studentId: 'student-1',
        studentName: 'Rahul Sharma',
        date: DateTime.now().subtract(const Duration(days: 1)),
        status: 'present',
        markedBy: 'supervisor-1',
        markedByName: 'Supervisor',
        markedAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
      IndustryAttendanceRecord(
        id: 'att-2',
        internshipId: '1',
        studentId: 'student-1',
        studentName: 'Rahul Sharma',
        date: DateTime.now().subtract(const Duration(days: 2)),
        status: 'present',
        markedBy: 'supervisor-1',
        markedByName: 'Supervisor',
        markedAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];
  }

  /// Returns only the internships assigned to the authorized company.
  List<IndustryInternshipModel> get _authorizedInternships {
    if (!hasVerifiedCompany) return [];
    if (companyName != null && companyName!.trim().isNotEmpty) {
      return _allInternships
          .where(
            (i) =>
                (i.companyName?.trim().toLowerCase() ?? '') ==
                companyName!.trim().toLowerCase(),
          )
          .toList();
    }
    return _allInternships;
  }

  void _assertInternshipAuthorized(String internshipId) {
    if (!hasVerifiedCompany) {
      throw StateError(
        'Unauthorized: No verified company association for this supervisor.',
      );
    }
    final isAuthorized = _authorizedInternships.any(
      (i) => i.id == internshipId,
    );
    if (!isAuthorized) {
      throw StateError(
        'Unauthorized: Internship $internshipId is not assigned to ${companyName ?? "your company"}.',
      );
    }
  }

  @override
  Future<List<IndustryInternshipModel>> getIndustryInternships() async {
    await Future.delayed(const Duration(milliseconds: 20));
    return List.unmodifiable(_authorizedInternships);
  }

  @override
  Future<IndustryDashboardData> getDashboardData() async {
    await Future.delayed(const Duration(milliseconds: 20));
    if (!hasVerifiedCompany) {
      return IndustryDashboardData.empty('Unassigned Organization');
    }
    if (_customDashboardData != null) {
      return _customDashboardData;
    }
    // If no specific company was requested and no custom dashboard was injected,
    // preserve the default mock dashboard metrics for standard test fixtures
    if (companyName == null) {
      return const IndustryDashboardData(
        industryName: 'TechNova Solutions',
        totalInterns: 24,
        activeInterns: 18,
        completedInternships: 6,
        pendingAttendance: 4,
        pendingEvaluations: 8,
        completedEvaluations: 16,
        pendingCertificates: 6,
        issuedCertificates: 6,
        pendingOfferLetters: 2,
        issuedOfferLetters: 22,
        pendingItrs: 5,
        submittedItrs: 19,
      );
    }
    final interns = _authorizedInternships;
    final active = interns.where((i) => i.status == 'active').length;
    final completed = interns.where((i) => i.status == 'completed').length;
    final pendingEval = interns
        .where((i) => ['pending', 'in_progress'].contains(i.evaluationStatus))
        .length;
    final completedEval = interns
        .where(
          (i) => [
            'verified',
            'completed',
            'approved',
          ].contains(i.evaluationStatus),
        )
        .length;
    final issuedCerts = interns
        .where(
          (i) =>
              i.certificateStatus == 'issued' ||
              i.certificateStatus == 'verified',
        )
        .length;
    final pendingCerts = interns
        .where(
          (i) => i.certificateStatus == 'pending' && i.status == 'completed',
        )
        .length;
    final issuedOffers = interns
        .where(
          (i) =>
              i.offerLetterStatus == 'issued' ||
              i.offerLetterStatus == 'verified',
        )
        .length;
    final pendingOffers = interns
        .where((i) => i.offerLetterStatus == 'pending')
        .length;

    return IndustryDashboardData(
      industryName: companyName ?? 'TechNova Solutions',
      totalInterns: interns.length,
      activeInterns: active,
      completedInternships: completed,
      pendingAttendance: 0,
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
    await Future.delayed(const Duration(milliseconds: 20));
    _assertInternshipAuthorized(internshipId);
    return List.unmodifiable(_attendanceRecords[internshipId] ?? []);
  }

  @override
  Future<void> markAttendance({
    required String internshipId,
    required String studentId,
    required DateTime date,
    required String status,
    String? remarks,
  }) async {
    await Future.delayed(const Duration(milliseconds: 20));
    _assertInternshipAuthorized(internshipId);

    final list = _attendanceRecords.putIfAbsent(internshipId, () => []);
    // Prevent duplicates for the same student & date
    final existingIdx = list.indexWhere(
      (r) =>
          r.studentId == studentId &&
          r.date.year == date.year &&
          r.date.month == date.month &&
          r.date.day == date.day,
    );
    final rec = IndustryAttendanceRecord(
      id: existingIdx >= 0
          ? list[existingIdx].id
          : 'att-${DateTime.now().millisecondsSinceEpoch}',
      internshipId: internshipId,
      studentId: studentId,
      date: date,
      status: status,
      markedBy: 'industry-supervisor',
      markedByName: 'Industry Supervisor',
      markedAt: DateTime.now(),
      remarks: remarks,
    );
    if (existingIdx >= 0) {
      list[existingIdx] = rec;
    } else {
      list.insert(0, rec);
    }
  }

  @override
  Future<void> updateOfferLetter({
    required String internshipId,
    required String status,
    String? fileUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 20));
    _assertInternshipAuthorized(internshipId);

    final idx = _allInternships.indexWhere((i) => i.id == internshipId);
    if (idx >= 0) {
      _allInternships[idx] = _allInternships[idx].copyWith(
        offerLetterStatus: status,
        offerLetterUrl: fileUrl ?? _allInternships[idx].offerLetterUrl,
      );
    }
  }

  @override
  Future<void> updateCertificate({
    required String internshipId,
    required String status,
    String? fileUrl,
  }) async {
    await Future.delayed(const Duration(milliseconds: 20));
    _assertInternshipAuthorized(internshipId);

    final idx = _allInternships.indexWhere((i) => i.id == internshipId);
    if (idx >= 0) {
      _allInternships[idx] = _allInternships[idx].copyWith(
        certificateStatus: status,
        certificateUrl: fileUrl ?? _allInternships[idx].certificateUrl,
      );
    }
  }

  final Map<String, List<InternshipDocument>> _studentDocuments = {};

  @override
  Future<List<InternshipDocument>> getStudentDocuments(
    String internshipId,
  ) async {
    await Future.delayed(const Duration(milliseconds: 20));
    _assertInternshipAuthorized(internshipId);

    final existing = _studentDocuments[internshipId];
    if (existing != null) return List.unmodifiable(existing);

    // Provide default initial documents for demo/testing
    final intern = _allInternships.cast<IndustryInternshipModel?>().firstWhere(
      (i) => i?.id == internshipId,
      orElse: () => null,
    );

    final initialDocs = [
      InternshipDocument(
        id: 'doc-$internshipId-offer',
        internshipId: internshipId,
        studentId: intern?.studentId ?? 'student-1',
        studentName: intern?.studentName ?? 'Student',
        docType: 'offer_letter',
        fileName: '${intern?.studentName ?? "Student"}_OfferLetter.pdf',
        filePath: 'mock/offer_letter.pdf',
        fileUrl:
            intern?.offerLetterUrl ??
            'https://storage.prashikshan.edu/offer_letters/$internshipId.pdf',
        status: intern?.offerLetterStatus == 'verified'
            ? 'verified'
            : 'pending',
        facultyStatus: 'pending',
        createdAt: DateTime.now().subtract(const Duration(days: 10)),
      ),
      InternshipDocument(
        id: 'doc-$internshipId-cert',
        internshipId: internshipId,
        studentId: intern?.studentId ?? 'student-1',
        studentName: intern?.studentName ?? 'Student',
        docType: 'certificate',
        fileName: '${intern?.studentName ?? "Student"}_Certificate.pdf',
        filePath: 'mock/certificate.pdf',
        fileUrl:
            intern?.certificateUrl ??
            'https://storage.prashikshan.edu/certificates/$internshipId.pdf',
        status: intern?.certificateStatus == 'verified'
            ? 'verified'
            : 'pending',
        facultyStatus: 'pending',
        createdAt: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    _studentDocuments[internshipId] = initialDocs;
    return List.unmodifiable(initialDocs);
  }

  @override
  Future<void> verifyStudentDocument({
    required String documentId,
    required String status,
    String? rejectionReason,
    String? remarks,
  }) async {
    await Future.delayed(const Duration(milliseconds: 20));

    // Find which internship owns this document and assert authorization
    String? ownerInternshipId;
    for (final entry in _studentDocuments.entries) {
      if (entry.value.any((d) => d.id == documentId)) {
        ownerInternshipId = entry.key;
        break;
      }
    }

    if (ownerInternshipId != null) {
      _assertInternshipAuthorized(ownerInternshipId);
    } else {
      if (!hasVerifiedCompany) {
        throw StateError(
          'Unauthorized: No verified company association for this supervisor.',
        );
      }
    }

    for (final list in _studentDocuments.values) {
      final idx = list.indexWhere((d) => d.id == documentId);
      if (idx >= 0) {
        list[idx] = list[idx].copyWith(
          status: status,
          rejectionReason: status == 'rejected' ? rejectionReason : null,
          remarks: remarks,
          verifiedBy: 'industry-supervisor-1',
          verifiedByName: 'Industry Supervisor',
          verifiedAt: DateTime.now(),
        );
        break;
      }
    }
  }
}
