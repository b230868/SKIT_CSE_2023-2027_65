import '../../../internship/models/internship.dart';
import '../../../itr/data/repositories/itr_repository.dart';
import '../../../itr/data/repositories/itr_repository_provider.dart';
import '../models/industry_attendance_model.dart';
import '../models/industry_dashboard_data.dart';
import '../models/industry_evaluation_model.dart';
import '../models/industry_internship_model.dart';
import '../repositories/industry_evaluation_repository_provider.dart';
import '../repositories/industry_repository.dart';
import '../repositories/industry_repository_provider.dart';

class IndustryService {
  final IndustryRepository _repository;
  final ItrRepository? itrRepository;

  IndustryService({IndustryRepository? repository, this.itrRepository})
    : _repository = repository ?? industryRepository;

  ItrRepository get _effectiveItrRepo =>
      itrRepository ?? ItrRepositoryProvider.instance;

  Future<List<IndustryInternshipModel>> getIndustryInternships() {
    return _repository.getIndustryInternships();
  }

  Future<IndustryDashboardData> getDashboardData() {
    return _repository.getDashboardData();
  }

  // Attendance APIs
  Future<List<IndustryAttendanceRecord>> getAttendanceRecords(
    String internshipId,
  ) {
    return _repository.getAttendanceRecords(internshipId);
  }

  Future<void> markAttendance({
    required String internshipId,
    required String studentId,
    required DateTime date,
    required String status,
    String? remarks,
  }) {
    return _repository.markAttendance(
      internshipId: internshipId,
      studentId: studentId,
      date: date,
      status: status,
      remarks: remarks,
    );
  }

  // Document APIs
  Future<void> issueOfferLetter({
    required String internshipId,
    required String fileUrl,
  }) {
    return _repository.updateOfferLetter(
      internshipId: internshipId,
      status: 'issued',
      fileUrl: fileUrl,
    );
  }

  Future<void> verifyOfferLetter({required String internshipId}) {
    return _repository.updateOfferLetter(
      internshipId: internshipId,
      status: 'verified',
    );
  }

  Future<void> issueCertificate({
    required String internshipId,
    required String fileUrl,
  }) {
    return _repository.updateCertificate(
      internshipId: internshipId,
      status: 'issued',
      fileUrl: fileUrl,
    );
  }

  Future<void> verifyCertificate({required String internshipId}) {
    return _repository.updateCertificate(
      internshipId: internshipId,
      status: 'verified',
    );
  }

  // Student-Uploaded Document Verification APIs
  Future<List<InternshipDocument>> getStudentDocuments(String internshipId) {
    return _repository.getStudentDocuments(internshipId);
  }

  Future<void> verifyStudentDocument({
    required String documentId,
    required String status,
    String? rejectionReason,
    String? remarks,
  }) {
    return _repository.verifyStudentDocument(
      documentId: documentId,
      status: status,
      rejectionReason: rejectionReason,
      remarks: remarks,
    );
  }

  /// Calculates real-time analytics data derived dynamically from available
  /// repository records. Does not invent or hardcode scores or distributions.
  Future<IndustryAnalyticsData> getAnalyticsData() async {
    final dashboard = await getDashboardData();
    final internships = await getIndustryInternships();

    // 1. Calculate actual progress bands directly from real internship records
    final progressBands = <String, int>{
      '0-25%': 0,
      '26-50%': 0,
      '51-75%': 0,
      '76-100%': 0,
    };
    for (final item in internships) {
      final p = item.progress;
      if (p <= 25) {
        progressBands['0-25%'] = (progressBands['0-25%'] ?? 0) + 1;
      } else if (p <= 50) {
        progressBands['26-50%'] = (progressBands['26-50%'] ?? 0) + 1;
      } else if (p <= 75) {
        progressBands['51-75%'] = (progressBands['51-75%'] ?? 0) + 1;
      } else {
        progressBands['76-100%'] = (progressBands['76-100%'] ?? 0) + 1;
      }
    }

    // 2. Compute evaluation score average and grade distribution from industry evaluations
    double averageScore = 0.0;
    final gradeDistribution = <String, int>{
      'A+': 0,
      'A': 0,
      'B+': 0,
      'B': 0,
      'C': 0,
      'D': 0,
      'F': 0,
    };
    int evaluatedCount = 0;
    double totalScoreSum = 0.0;

    // First try industry evaluation repository
    try {
      final evaluations = await IndustryEvaluationRepositoryProvider.instance
          .getEvaluations();
      for (final eval in evaluations) {
        if (eval.totalScore > 0) {
          totalScoreSum += eval.totalScore;
          evaluatedCount++;
        }
        final grade = eval.grade.toUpperCase();
        if (gradeDistribution.containsKey(grade)) {
          gradeDistribution[grade] = (gradeDistribution[grade] ?? 0) + 1;
        }
      }
    } catch (_) {
      // Fallback: If evaluation repo throws, compute from ITR repo if available for legacy continuity
      try {
        final itrs = await _effectiveItrRepo.getIndustryItrs();
        for (final itr in itrs) {
          if (itr.evaluationScore != null && itr.evaluationScore! > 0) {
            totalScoreSum += itr.evaluationScore!;
            evaluatedCount++;
          }
          final grade = itr.evaluationGrade?.toUpperCase();
          if (grade != null && gradeDistribution.containsKey(grade)) {
            gradeDistribution[grade] = (gradeDistribution[grade] ?? 0) + 1;
          }
        }
      } catch (_) {}
    }

    if (evaluatedCount > 0) {
      averageScore = double.parse(
        (totalScoreSum / evaluatedCount).toStringAsFixed(1),
      );
    }

    // 3. Compute overall company attendance rate across interns
    double attendanceRate = 0.0;
    final internsWithAtt = internships
        .where((i) => i.attendanceRate != null)
        .toList();
    if (internsWithAtt.isNotEmpty) {
      final sumRate = internsWithAtt.fold<double>(
        0.0,
        (acc, i) => acc + (i.attendanceRate ?? 0.0),
      );
      attendanceRate = double.parse(
        (sumRate / internsWithAtt.length).toStringAsFixed(1),
      );
    }

    return IndustryAnalyticsData(
      industryName: dashboard.industryName,
      totalInterns: dashboard.totalInterns,
      activeInterns: dashboard.activeInterns,
      completedInternships: dashboard.completedInternships,
      pendingAttendance: dashboard.pendingAttendance,
      attendanceRate: attendanceRate,
      pendingEvaluations: dashboard.pendingEvaluations,
      completedEvaluations: dashboard.completedEvaluations,
      pendingCertificates: dashboard.pendingCertificates,
      issuedCertificates: dashboard.issuedCertificates,
      pendingOfferLetters: dashboard.pendingOfferLetters,
      issuedOfferLetters: dashboard.issuedOfferLetters,
      averageScore: averageScore,
      gradeDistribution: gradeDistribution,
      progressBands: progressBands,
      pendingItrs: dashboard.pendingItrs,
      submittedItrs: dashboard.submittedItrs,
    );
  }
}
