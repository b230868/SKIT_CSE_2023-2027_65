import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_itr_review_screen.dart';
import 'package:prashikshan/features/itr/data/models/itr_model.dart';
import 'package:prashikshan/features/itr/data/repositories/mock_itr_repository.dart';
import 'package:prashikshan/features/itr/data/services/itr_service.dart';

void main() {
  testWidgets(
    'IndustryItrReviewScreen validates remarks on change request and saves approval',
    (WidgetTester tester) async {
      final mockRepo = MockItrRepository();
      final service = ItrService(mockRepo);

      final itr = ItrModel(
        id: 'itr-001',
        internshipId: 'internship-001',
        studentId: 'student-001',
        studentName: 'Rahul Sharma',
        internshipTitle: 'Software Development Intern',
        companyName: 'Demo Company',
        status: 'submitted',
        content: 'Completed project milestone.',
        workDone: 'Built Flutter UI and test modules.',
        technologiesUsed: 'Flutter, Dart, PostgreSQL',
        keyLearnings: 'Mobile architectures and integration.',
        challengesFaced: 'API edge cases.',
        submittedAt: DateTime(2026, 8, 28),
      );

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: IndustryItrReviewScreen(itr: itr, itrService: service),
        ),
      );

      await tester.pumpAndSettle();

      // Verify Title & Student header
      expect(find.text('Review Student ITR'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);

      // Verify sections
      expect(find.text('Work Completed'), findsOneWidget);
      expect(find.text('Built Flutter UI and test modules.'), findsOneWidget);
      expect(find.text('Technologies & Tools Used'), findsOneWidget);
      expect(find.text('Flutter, Dart, PostgreSQL'), findsOneWidget);

      // Verify action buttons
      expect(find.text('Approve ITR'), findsOneWidget);
      expect(find.text('Request Changes / Resubmission'), findsOneWidget);
      expect(find.text('Reject ITR'), findsOneWidget);

      // Tap "Request Changes / Resubmission" with empty remarks -> SnackBar validation appears
      await tester.ensureVisible(find.text('Request Changes / Resubmission'));
      await tester.tap(find.text('Request Changes / Resubmission'));
      await tester.pumpAndSettle();

      expect(find.textContaining('Please provide remarks'), findsOneWidget);

      // Tap "Approve ITR"
      await tester.ensureVisible(find.text('Approve ITR'));
      await tester.tap(find.text('Approve ITR'));
      await tester.pumpAndSettle();

      // Verify status updated in mock repository
      final updated = await service.getItrById('itr-001');
      expect(updated, isNotNull);
      expect(updated!.status, equals('approved'));
    },
  );
}
