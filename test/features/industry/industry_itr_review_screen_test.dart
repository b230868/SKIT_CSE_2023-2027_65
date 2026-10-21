import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_itr_review_screen.dart';
import 'package:prashikshan/features/itr/data/models/itr_model.dart';
import 'package:prashikshan/features/itr/data/repositories/mock_itr_repository.dart';
import 'package:prashikshan/features/itr/data/services/itr_service.dart';

void main() {
  group('IndustryItrReviewScreen Widget Tests', () {
    testWidgets(
      'renders review details, evaluation rubric, certificate status, and approves ITR',
      (tester) async {
        tester.view.physicalSize = const Size(800, 2000);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        final mockRepo = MockItrRepository();
        final itrService = ItrService(mockRepo);

        final sampleItr = ItrModel(
          id: 'itr-001',
          internshipId: 'internship-001',
          studentId: 'student-001',
          studentName: 'Rahul Sharma',
          internshipTitle: 'Software Development Intern',
          companyName: 'TechNova Solutions',
          status: 'submitted',
          content: 'Implemented cloud microservices and Flutter screens',
          workDone: 'Designed architecture and completed modules',
          technologiesUsed: 'Flutter, Dart, Supabase',
          keyLearnings: 'State lifecycle and offline caching',
          challengesFaced: 'Network latency optimization',
          projectZipPath: 'mock/project.zip',
          presentationPath: 'mock/slides.pptx',
          submittedAt: DateTime(2026, 8, 28),
        );

        await tester.pumpWidget(
          MaterialApp(
            home: IndustryItrReviewScreen(
              itr: sampleItr,
              itrService: itrService,
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Verify student details
        expect(find.text('Review Student ITR'), findsOneWidget);
        expect(find.text('Rahul Sharma'), findsOneWidget);
        expect(find.text('Software Development Intern'), findsOneWidget);
        expect(find.text('SUBMITTED'), findsOneWidget);

        // Verify deliverables section
        expect(find.text('Attached Deliverables'), findsOneWidget);
        expect(find.text('Project Source Code (ZIP)'), findsOneWidget);
        expect(find.text('Project Presentation (PPT)'), findsOneWidget);

        // Verify Evaluation Rubric
        expect(
          find.text('Mentor Evaluation Rubric (100 Marks)'),
          findsOneWidget,
        );
        expect(find.text('1. Technical Competency (25)'), findsOneWidget);
        expect(
          find.text('2. Work Quality & Deliverables (25)'),
          findsOneWidget,
        );
        expect(
          find.text('3. Punctuality & Communication (25)'),
          findsOneWidget,
        );
        expect(
          find.text('4. Project Viva & Presentation (25)'),
          findsOneWidget,
        );

        // Verify Certificate Verification section
        expect(find.text('Certificate Verification'), findsOneWidget);
        expect(find.text('Certificate Status:'), findsOneWidget);

        // Scroll and ensure button is visible
        final approveButton = find.widgetWithText(
          FilledButton,
          'Approve & Evaluate (80/100 - Grade A)',
        );
        await tester.ensureVisible(approveButton);
        await tester.pumpAndSettle();

        await tester.tap(approveButton);
        await tester.pumpAndSettle();

        // Verify repository updated
        final updated = await mockRepo.getItrById('itr-001');
        expect(updated!.status, equals('approved'));
        expect(updated.evaluationScore, equals(80.0));
        expect(updated.evaluationGrade, equals('A'));
      },
    );
  });
}
