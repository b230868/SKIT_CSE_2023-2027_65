import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/industry_evaluation_model.dart';
import 'package:prashikshan/features/industry/data/repositories/industry_evaluation_repository_provider.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_evaluation_repository.dart';
import 'package:prashikshan/features/industry/data/services/industry_evaluation_service.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_evaluation_form_screen.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_evaluation_list_screen.dart';

void main() {
  late MockIndustryEvaluationRepository mockRepo;
  late IndustryEvaluationService service;

  setUp(() {
    mockRepo = MockIndustryEvaluationRepository();
    IndustryEvaluationRepositoryProvider.setInstance(mockRepo);
    service = IndustryEvaluationService(repository: mockRepo);
  });

  tearDown(() {
    IndustryEvaluationRepositoryProvider.reset();
  });

  testWidgets(
    'IndustryEvaluationListScreen displays evaluations and filter chips',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: IndustryEvaluationListScreen(evaluationService: service),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      // Verify title and search
      expect(find.text('Intern Evaluations & Verification'), findsOneWidget);
      expect(find.byType(TextField), findsOneWidget);

      // Verify Filter Chips
      expect(find.text('All'), findsOneWidget);
      expect(find.text('Pending'), findsOneWidget);
      expect(find.text('In Progress'), findsOneWidget);
      expect(find.text('Verified'), findsOneWidget);

      // Verify items in list
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Priya Singh'), findsOneWidget);
      expect(find.text('Aman Verma'), findsOneWidget);

      // Tap on 'Verified' filter
      await tester.tap(find.text('Verified'));
      await tester.pumpAndSettle();

      expect(find.text('Aman Verma'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsNothing);
    },
  );

  testWidgets(
    'IndustryEvaluationFormScreen allows criterion scoring and recalculates total & grade',
    (WidgetTester tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      const evaluation = IndustryEvaluationModel(
        id: 'eval-test',
        internshipId: 'int-test',
        studentId: 'stud-test',
        studentName: 'Vikram Seth',
        internshipTitle: 'Backend Architecture Intern',
        companyName: 'TechNova Solutions',
        technicalSkillsScore: 10,
        workQualityScore: 10,
        attendanceScore: 10,
        initiativeScore: 10,
        communicationScore: 10,
        totalScore: 50,
        grade: 'C',
        status: 'pending',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: IndustryEvaluationFormScreen(
            evaluation: evaluation,
            evaluationService: service,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Verify header information
      expect(find.text('Vikram Seth'), findsOneWidget);
      expect(find.text('Backend Architecture Intern'), findsOneWidget);

      // Initial total score and grade
      expect(find.text('50.0 / 100'), findsOneWidget);
      expect(find.text('C'), findsOneWidget);

      // Verify all 5 criteria sliders exist
      expect(find.byType(Slider), findsNWidgets(5));
      expect(find.text('1. Technical Competence'), findsOneWidget);
      expect(find.text('2. Quality of Deliverables'), findsOneWidget);
      expect(find.text('3. Attendance & Punctuality'), findsOneWidget);
      expect(find.text('4. Problem Solving & Initiative'), findsOneWidget);
      expect(find.text('5. Teamwork & Communication'), findsOneWidget);

      // Verify buttons
      expect(find.text('Save Draft'), findsOneWidget);
      expect(find.text('Verify & Submit'), findsOneWidget);

      // Tap 'Verify & Submit'
      await tester.ensureVisible(find.text('Verify & Submit'));
      await tester.tap(find.text('Verify & Submit'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // Verify saved state in repository
      final saved = await service.getEvaluationByInternshipId('int-test');
      expect(saved, isNotNull);
      expect(saved!.status, equals('verified'));
    },
  );
}
