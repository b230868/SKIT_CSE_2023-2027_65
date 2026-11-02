import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/evaluation_model.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_repository.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';
import 'package:prashikshan/features/itr/data/models/itr_model.dart';
import 'package:prashikshan/features/itr/data/repositories/mock_itr_repository.dart';
import 'package:prashikshan/features/itr/data/services/itr_service.dart';

void main() {
  group('System & User Acceptance Testing (E2E Workflow: Industry & ITR Lifecycle)', () {
    late MockIndustryRepository industryRepo;
    late IndustryService industryService;
    late MockItrRepository itrRepo;
    late ItrService itrService;

    setUp(() {
      industryRepo = MockIndustryRepository(
        companyName: 'TechNova Solutions',
        hasVerifiedCompany: true,
      );
      industryService = IndustryService(repository: industryRepo);

      itrRepo = MockItrRepository();
      itrService = ItrService(itrRepo);
    });

    test('E2E Lifecycle: Internship -> Attendance -> ITR Submission -> Review -> Analytics', () async {
      // Step 1: Industry Supervisor opens dashboard and views active interns
      final initialDashboard = await industryService.getDashboardData();
      expect(initialDashboard.industryName, 'TechNova Solutions');
      expect(initialDashboard.activeInterns, greaterThanOrEqualTo(1));

      final interns = await industryService.getIndustryInternships();
      final targetIntern = interns.firstWhere((i) => i.id == '1');
      expect(targetIntern.studentName, 'Rahul Sharma');

      // Step 2: Supervisor marks daily attendance for the intern
      final today = DateTime.now();
      await industryService.markAttendance(
        internshipId: targetIntern.id,
        studentId: targetIntern.studentId ?? 'student-1',
        date: today,
        status: 'present',
        remarks: 'Active contribution on sprint tasks',
      );

      final attendance = await industryService.getAttendanceRecords(targetIntern.id);
      expect(attendance.any((a) => a.status == 'present'), isTrue);

      // Step 3: Student completes internship work and submits ITR
      final itrToSubmit = ItrModel(
        id: 'itr-001',
        internshipId: targetIntern.id,
        studentId: targetIntern.studentId ?? 'student-1',
        studentName: targetIntern.studentName,
        internshipTitle: targetIntern.internshipTitle,
        companyName: targetIntern.companyName ?? 'TechNova Solutions',
        status: 'submitted',
        submittedAt: DateTime.now(),
        content: 'Final internship report documenting complete architecture.',
        workDone: 'Designed UI modules, integration tests, and Supabase RPCs.',
        technologiesUsed: 'Flutter, Dart, Supabase, PostgreSQL',
        keyLearnings: 'Enterprise Clean Architecture and multi-role testing.',
        challengesFaced: 'Managing cross-platform date pickers and RLS policies.',
      );

      await itrService.submitItr(itrToSubmit);
      final submittedItr = await itrService.getItrById('itr-001');
      expect(submittedItr, isNotNull);
      expect(submittedItr!.status, 'submitted');

      // Step 4: Industry Supervisor conducts evaluation and verifies certificate
      final evaluation = EvaluationModel(
        id: 'eval-e2e',
        itrId: submittedItr.id,
        internshipId: submittedItr.internshipId,
        studentId: submittedItr.studentId,
        evaluatorId: 'eval-user-1',
        evaluatorName: 'Technical Director',
        technicalScore: 23.5, // 94%
        workQualityScore: 24.0,
        punctualityScore: 23.5,
        presentationScore: 24.0, // Total = 95.0
        remarks: 'Exemplary initiative and robust code structure.',
        evaluatedAt: DateTime.now(),
        certificateStatus: 'verified',
      );

      expect(evaluation.totalScore, 95.0);
      expect(evaluation.grade, 'A+');

      await itrService.saveEvaluation(evaluation);
      await itrService.reviewItr(
        itrId: submittedItr.id,
        status: 'approved',
        remarks: 'Approved with Distinction.',
        reviewerName: 'Technical Director',
      );

      final approvedItr = await itrService.getItrById('itr-001');
      expect(approvedItr, isNotNull);
      expect(approvedItr!.status, 'approved');

      // Step 5: Verify certificate link attachment
      await itrService.updateCertificateStatus(
        itrId: approvedItr.id,
        status: 'verified',
        certificateUrl: 'https://storage.college.edu/certificates/rahul_internship.pdf',
      );

      final certifiedItr = await itrService.getItrById('itr-001');
      expect(certifiedItr, isNotNull);
      expect(certifiedItr!.certificateUrl, contains('rahul_internship.pdf'));

      // Step 6: Verify Industry Analytics and Reports reflects completed progress
      final analytics = await industryService.getAnalyticsData();
      expect(analytics.totalInterns, greaterThanOrEqualTo(3));
      expect(analytics.industryName, 'TechNova Solutions');
    });

    test('Usability & Validation: Error handling on missing fields and invalid operations', () async {
      // Non-existent ITR lookup returns null
      final missingItr = await itrService.getItrById('invalid-itr-id');
      expect(missingItr, isNull);

      // Rejection review flow with feedback remarks
      await itrService.reviewItr(
        itrId: 'itr-002',
        status: 'rejected',
        remarks: 'Please re-upload presentation slides and format certificate.',
        reviewerName: 'Staff Reviewer',
      );

      final rejected = await itrService.getItrById('itr-002');
      expect(rejected, isNotNull);
      expect(rejected!.status, 'rejected');
      expect(rejected.remarks, contains('Please re-upload'));
    });
  });
}
