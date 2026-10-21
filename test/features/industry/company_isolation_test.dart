import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/industry_evaluation_model.dart';
import 'package:prashikshan/features/industry/data/models/industry_internship_model.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_evaluation_repository.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_repository.dart';
import 'package:prashikshan/features/industry/data/services/industry_evaluation_service.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_dashboard_screen.dart';
import 'package:prashikshan/features/industry/presentation/screens/internship_management_screen.dart';

void main() {
  group('Company-Level Strict Data Isolation Tests', () {
    // 1. Define distinct data for Company A (TechNova Solutions) and Company B (DataCorp India)
    const companyAInternships = [
      IndustryInternshipModel(
        id: 'internship-A1',
        studentName: 'Rahul Sharma (Company A)',
        internshipTitle: 'Mobile App Developer Intern',
        status: 'active',
        progress: 60.0,
        itrStatus: 'submitted',
        evaluationStatus: 'pending',
        studentId: 'student-A1',
        companyName: 'TechNova Solutions',
      ),
      IndustryInternshipModel(
        id: 'internship-A2',
        studentName: 'Aman Verma (Company A)',
        internshipTitle: 'Cloud Infrastructure Intern',
        status: 'completed',
        progress: 100.0,
        itrStatus: 'approved',
        evaluationStatus: 'verified',
        studentId: 'student-A2',
        companyName: 'TechNova Solutions',
      ),
    ];

    const companyBInternships = [
      IndustryInternshipModel(
        id: 'internship-B1',
        studentName: 'Priya Singh (Company B)',
        internshipTitle: 'Data Analyst Intern',
        status: 'active',
        progress: 45.0,
        itrStatus: 'draft',
        evaluationStatus: 'pending',
        studentId: 'student-B1',
        companyName: 'DataCorp India',
      ),
      IndustryInternshipModel(
        id: 'internship-B2',
        studentName: 'Vikram Patel (Company B)',
        internshipTitle: 'BI Engineer Intern',
        status: 'completed',
        progress: 100.0,
        itrStatus: 'approved',
        evaluationStatus: 'verified',
        studentId: 'student-B2',
        companyName: 'DataCorp India',
      ),
    ];

    final allMultiCompanyInternships = [
      ...companyAInternships,
      ...companyBInternships,
    ];

    final allMultiCompanyEvaluations = [
      IndustryEvaluationModel(
        id: 'eval-A1',
        internshipId: 'internship-A1',
        studentId: 'student-A1',
        studentName: 'Rahul Sharma (Company A)',
        internshipTitle: 'Mobile App Developer Intern',
        companyName: 'TechNova Solutions',
        technicalSkillsScore: 18,
        workQualityScore: 18,
        attendanceScore: 18,
        initiativeScore: 18,
        communicationScore: 18,
        totalScore: 90,
        grade: 'A+',
        status: 'pending',
        feedback: 'Great performance at TechNova',
        remarks: 'Company A supervisor notes',
        evaluationDate: DateTime(2026, 10, 1),
      ),
      IndustryEvaluationModel(
        id: 'eval-B1',
        internshipId: 'internship-B1',
        studentId: 'student-B1',
        studentName: 'Priya Singh (Company B)',
        internshipTitle: 'Data Analyst Intern',
        companyName: 'DataCorp India',
        technicalSkillsScore: 15,
        workQualityScore: 16,
        attendanceScore: 17,
        initiativeScore: 16,
        communicationScore: 16,
        totalScore: 80,
        grade: 'A',
        status: 'pending',
        feedback: 'Good analytics performance at DataCorp',
        remarks: 'Company B supervisor notes',
        evaluationDate: DateTime(2026, 10, 2),
      ),
    ];

    test(
      '1. Company A supervisor sees only Company A interns and metrics',
      () async {
        final repoA = MockIndustryRepository(
          internships: allMultiCompanyInternships,
          companyName: 'TechNova Solutions',
        );
        final serviceA = IndustryService(repository: repoA);

        final internsA = await serviceA.getIndustryInternships();
        expect(internsA.length, equals(2));
        expect(
          internsA.every((i) => i.companyName == 'TechNova Solutions'),
          isTrue,
        );
        expect(
          internsA.any((i) => i.studentName.contains('Company B')),
          isFalse,
        );

        final dashboardA = await serviceA.getDashboardData();
        expect(dashboardA.industryName, equals('TechNova Solutions'));
        expect(dashboardA.totalInterns, equals(2));
        expect(dashboardA.activeInterns, equals(1));
        expect(dashboardA.completedInternships, equals(1));
      },
    );

    test(
      '2. Company B supervisor sees only Company B interns and metrics',
      () async {
        final repoB = MockIndustryRepository(
          internships: allMultiCompanyInternships,
          companyName: 'DataCorp India',
        );
        final serviceB = IndustryService(repository: repoB);

        final internsB = await serviceB.getIndustryInternships();
        expect(internsB.length, equals(2));
        expect(
          internsB.every((i) => i.companyName == 'DataCorp India'),
          isTrue,
        );
        expect(
          internsB.any((i) => i.studentName.contains('Company A')),
          isFalse,
        );

        final dashboardB = await serviceB.getDashboardData();
        expect(dashboardB.industryName, equals('DataCorp India'));
        expect(dashboardB.totalInterns, equals(2));
        expect(dashboardB.activeInterns, equals(1));
        expect(dashboardB.completedInternships, equals(1));
      },
    );

    test('3. Company A supervisor cannot read attendance records for Company B intern', () async {
      final repoA = MockIndustryRepository(
        internships: allMultiCompanyInternships,
        companyName: 'TechNova Solutions',
      );
      final serviceA = IndustryService(repository: repoA);

      // Attempting to query attendance for Company B's intern ('internship-B1')
      expect(
        () => serviceA.getAttendanceRecords('internship-B1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Unauthorized'),
          ),
        ),
      );
    });

    test(
      '4. Company A supervisor cannot mark attendance for Company B intern',
      () async {
        final repoA = MockIndustryRepository(
          internships: allMultiCompanyInternships,
          companyName: 'TechNova Solutions',
        );
        final serviceA = IndustryService(repository: repoA);

        // Attempting to mark attendance for Company B's intern
        expect(
          () => serviceA.markAttendance(
            internshipId: 'internship-B1',
            studentId: 'student-B1',
            date: DateTime.now(),
            status: 'present',
          ),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Unauthorized'),
            ),
          ),
        );
      },
    );

    test('5. Company A supervisor cannot open or verify Company B intern documents', () async {
      final repoA = MockIndustryRepository(
        internships: allMultiCompanyInternships,
        companyName: 'TechNova Solutions',
      );
      final serviceA = IndustryService(repository: repoA);

      // Attempting to get documents for Company B's intern
      expect(
        () => serviceA.getStudentDocuments('internship-B1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Unauthorized'),
          ),
        ),
      );

      // Attempting to verify or update offer letter/certificate for Company B's intern
      expect(
        () => serviceA.verifyOfferLetter(internshipId: 'internship-B1'),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Unauthorized'),
          ),
        ),
      );
    });

    test('6. Company A supervisor cannot submit or read evaluations for Company B intern', () async {
      final evalRepoA = MockIndustryEvaluationRepository(
        evaluations: allMultiCompanyEvaluations,
        companyName: 'TechNova Solutions',
      );
      final evalServiceA = IndustryEvaluationService(repository: evalRepoA);

      final evaluationsA = await evalServiceA.getEvaluations();
      expect(evaluationsA.length, equals(1));
      expect(evaluationsA.first.companyName, equals('TechNova Solutions'));

      // Attempting to get Company B's evaluation returns null or throws unauthorized
      final evalB = await evalServiceA.getEvaluationByInternshipId(
        'internship-B1',
      );
      expect(evalB, isNull);

      // Attempting to save evaluation for Company B's intern fails
      final unauthorizedEval = IndustryEvaluationModel(
        id: 'eval-hack',
        internshipId: 'internship-B1',
        studentId: 'student-B1',
        studentName: 'Priya Singh (Company B)',
        internshipTitle: 'Data Analyst Intern',
        companyName: 'DataCorp India',
        technicalSkillsScore: 20,
        workQualityScore: 20,
        attendanceScore: 20,
        initiativeScore: 20,
        communicationScore: 20,
        totalScore: 100,
        grade: 'A+',
        status: 'verified',
        feedback: 'Tampered evaluation attempt',
        remarks: 'Should be rejected',
        evaluationDate: DateTime.now(),
      );

      expect(
        () => evalServiceA.saveEvaluation(
          internshipId: unauthorizedEval.internshipId,
          studentId: unauthorizedEval.studentId,
          studentName: unauthorizedEval.studentName,
          internshipTitle: unauthorizedEval.internshipTitle,
          companyName: unauthorizedEval.companyName,
          evaluationId: unauthorizedEval.id,
          technicalSkillsScore: unauthorizedEval.technicalSkillsScore,
          workQualityScore: unauthorizedEval.workQualityScore,
          attendanceScore: unauthorizedEval.attendanceScore,
          initiativeScore: unauthorizedEval.initiativeScore,
          communicationScore: unauthorizedEval.communicationScore,
          status: unauthorizedEval.status,
          feedback: unauthorizedEval.feedback,
          remarks: unauthorizedEval.remarks,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Unauthorized'),
          ),
        ),
      );
    });

    test('7. Supervisor without verified company association sees empty state and cannot modify records', () async {
      final unverifiedRepo = MockIndustryRepository(
        internships: allMultiCompanyInternships,
        companyName: 'Unassigned Company',
        hasVerifiedCompany: false,
      );
      final unverifiedService = IndustryService(repository: unverifiedRepo);

      final interns = await unverifiedService.getIndustryInternships();
      expect(interns, isEmpty);

      final dashboard = await unverifiedService.getDashboardData();
      expect(dashboard.totalInterns, equals(0));
      expect(dashboard.industryName, equals('Unassigned Organization'));

      // All action attempts fail with StateError
      expect(
        () => unverifiedService.markAttendance(
          internshipId: 'internship-A1',
          studentId: 'student-A1',
          date: DateTime.now(),
          status: 'present',
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            contains('Unauthorized'),
          ),
        ),
      );
    });

    testWidgets(
      '8. IndustryDashboardScreen displays company pending banner if unverified',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final unassignedRepo = MockIndustryRepository(
          internships: allMultiCompanyInternships,
          companyName: 'Unassigned Company',
          hasVerifiedCompany: false,
        );
        final unassignedService = IndustryService(repository: unassignedRepo);

        await tester.pumpWidget(
          MaterialApp(
            home: IndustryDashboardScreen(service: unassignedService),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Company Assignment Pending'), findsOneWidget);
        expect(
          find.textContaining('No verified company association is linked'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '9. InternshipManagementScreen renders only Company A interns for Company A supervisor',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final repoA = MockIndustryRepository(
          internships: allMultiCompanyInternships,
          companyName: 'TechNova Solutions',
        );
        final serviceA = IndustryService(repository: repoA);

        await tester.pumpWidget(
          MaterialApp(home: InternshipManagementScreen(service: serviceA)),
        );
        await tester.pumpAndSettle();

        // Should display Company A interns
        expect(find.text('Rahul Sharma (Company A)'), findsOneWidget);
        expect(find.text('Aman Verma (Company A)'), findsOneWidget);

        // Must NOT display Company B interns anywhere in list
        expect(find.text('Priya Singh (Company B)'), findsNothing);
        expect(find.text('Vikram Patel (Company B)'), findsNothing);
      },
    );
  });
}
