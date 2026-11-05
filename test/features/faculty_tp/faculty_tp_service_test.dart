import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/data/models/company_assignment_model.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/faculty_dashboard_repository.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/mock_company_assignment_repository.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/mock_student_monitoring_repository.dart';
import 'package:prashikshan/features/faculty_tp/data/services/faculty_dashboard_service.dart';
import 'package:prashikshan/features/faculty_tp/data/services/student_monitoring_service.dart';
import 'package:prashikshan/features/faculty_tp/domain/entities/dashboard_statistics.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_review_stage.dart';

class FakeFacultyDashboardRepository implements FacultyDashboardRepository {
  DashboardStatistics stats = const DashboardStatistics(
    pendingApprovals: 5,
    approvedInternships: 20,
    rejectedApplications: 2,
    studentsRequiringReview: 4,
  );

  @override
  Future<DashboardStatistics> getDashboardStatistics({
    ApprovalReviewStage? stage,
  }) async {
    if (stage == ApprovalReviewStage.tpAdmin) {
      return const DashboardStatistics(
        pendingApprovals: 3,
        approvedInternships: 22,
        rejectedApplications: 1,
        studentsRequiringReview: 2,
      );
    }
    return stats;
  }
}

void main() {
  group('Faculty & T&P Dashboard Unit Tests', () {
    late FakeFacultyDashboardRepository fakeRepo;
    late FacultyDashboardService dashboardService;

    setUp(() {
      fakeRepo = FakeFacultyDashboardRepository();
      dashboardService = FacultyDashboardService(repository: fakeRepo);
    });

    test('loadStatistics returns correct faculty dashboard metrics', () async {
      final stats = await dashboardService.loadStatistics();

      expect(stats.pendingApprovals, equals(5));
      expect(stats.approvedInternships, equals(20));
      expect(stats.rejectedApplications, equals(2));
      expect(stats.studentsRequiringReview, equals(4));
    });

    test('loadStatistics supports T&P stage filtering', () async {
      final stats = await dashboardService.loadStatistics(
        stage: ApprovalReviewStage.tpAdmin,
      );

      expect(stats.pendingApprovals, equals(3));
      expect(stats.approvedInternships, equals(22));
      expect(stats.rejectedApplications, equals(1));
      expect(stats.studentsRequiringReview, equals(2));
    });

    test('DashboardStatistics object properties are correctly formatted', () {
      const stats = DashboardStatistics(
        pendingApprovals: 12,
        approvedInternships: 45,
        rejectedApplications: 3,
        studentsRequiringReview: 8,
      );

      expect(stats.pendingApprovals, 12);
      expect(stats.approvedInternships, 45);
      expect(stats.rejectedApplications, 3);
      expect(stats.studentsRequiringReview, 8);
    });
  });

  group('Student Monitoring Service & Repository Tests', () {
    late MockStudentMonitoringRepository mockRepo;
    late StudentMonitoringService monitoringService;

    setUp(() {
      mockRepo = MockStudentMonitoringRepository();
      monitoringService = StudentMonitoringService(repository: mockRepo);
    });

    test('loadStudents returns student list with valid fields', () async {
      final students = await monitoringService.loadStudents();

      expect(students, isNotEmpty);
      final first = students.first;
      expect(first.studentId, isNotEmpty);
      expect(first.studentName, isNotEmpty);
      expect(first.internshipId, isNotEmpty);
      expect(first.applicationStatus, isNotNull);
    });

    test('loadStudentDetails returns detailed profile for valid student', () async {
      final students = await monitoringService.loadStudents();
      final target = students.first;

      final details = await monitoringService.loadStudentDetails(
        target.studentId,
        internshipId: target.internshipId,
      );

      expect(details, isNotNull);
      expect(details!.studentId, equals(target.studentId));
      expect(details.studentName, isNotEmpty);
    });

    test('loadStudentDetails returns details for student-002', () async {
      final details = await monitoringService.loadStudentDetails('student-002');
      expect(details, isNotNull);
      expect(details!.studentId, equals('student-002'));
      expect(details.studentName, equals('Demo Student 2'));
      expect(details.department, equals('Information Technology'));
    });

    test('verifyStudentDocument processes verification without error', () async {
      expect(
        () => monitoringService.verifyStudentDocument(
          documentId: 'doc-123',
          status: 'verified',
          remarks: 'Approved by faculty mentor',
        ),
        returnsNormally,
      );
    });

    test('verifyStudentDocument handles rejection with reason', () async {
      expect(
        () => monitoringService.verifyStudentDocument(
          documentId: 'doc-456',
          status: 'rejected',
          rejectionReason: 'Signature missing on internship offer letter',
        ),
        returnsNormally,
      );
    });

    test('getFileUrl resolves storage file path', () async {
      final url = await monitoringService.getFileUrl(
        bucket: 'documents',
        path: 'internship_letters/letter_01.pdf',
      );

      expect(url, isNotNull);
      expect(url, contains('letter_01.pdf'));
    });
  });

  group('Company Assignment Model & Repository Tests', () {
    late MockCompanyAssignmentRepository assignmentRepo;

    setUp(() {
      assignmentRepo = MockCompanyAssignmentRepository();
    });

    test('getVerifiedCompanies returns list of verified companies', () async {
      final companies = await assignmentRepo.getVerifiedCompanies();
      expect(companies, isNotEmpty);
      expect(companies.first, isA<VerifiedCompany>());
      expect(companies.first.name, isNotEmpty);
    });

    test('getIndustrySupervisors returns supervisor assignments', () async {
      final supervisors = await assignmentRepo.getIndustrySupervisors();
      expect(supervisors, isNotEmpty);
      expect(supervisors.first, isA<CompanyAssignmentUser>());
      expect(supervisors.first.email, isNotEmpty);
    });

    test('assignSupervisorToCompany updates assignment state', () async {
      final supervisorsBefore = await assignmentRepo.getIndustrySupervisors();
      final unassigned = supervisorsBefore.firstWhere((s) => !s.isAssigned);

      await assignmentRepo.assignSupervisorToCompany(
        supervisorUserId: unassigned.id,
        industryId: 'comp-111',
      );

      final supervisorsAfter = await assignmentRepo.getIndustrySupervisors();
      final updated = supervisorsAfter.firstWhere((s) => s.id == unassigned.id);
      expect(updated.isAssigned, isTrue);
      expect(updated.assignedIndustryId, equals('comp-111'));
    });
  });
}
