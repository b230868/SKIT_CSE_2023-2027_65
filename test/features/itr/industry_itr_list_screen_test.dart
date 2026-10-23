import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_itr_list_screen.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_itr_review_screen.dart';
import 'package:prashikshan/features/itr/data/repositories/mock_itr_repository.dart';
import 'package:prashikshan/features/itr/data/services/itr_service.dart';

void main() {
  testWidgets(
    'IndustryItrListScreen displays list of student ITRs and navigates to review',
    (WidgetTester tester) async {
      final mockRepo = MockItrRepository();
      final service = ItrService(mockRepo);

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(home: IndustryItrListScreen(itrService: service)),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      // Verify Title
      expect(find.text('Review Student ITRs'), findsOneWidget);

      // Verify student records
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Software Development Intern'), findsOneWidget);
      expect(find.text('Priya Singh'), findsOneWidget);
      expect(find.text('Aman Verma'), findsOneWidget);

      // Tap on an ITR card navigates to review screen
      await tester.tap(find.text('Rahul Sharma'));
      await tester.pumpAndSettle();

      expect(find.byType(IndustryItrReviewScreen), findsOneWidget);
      expect(find.text('Review Student ITR'), findsOneWidget);
      expect(find.text('Approve ITR'), findsOneWidget);
      expect(find.text('Request Changes / Resubmission'), findsOneWidget);
      expect(find.text('Reject ITR'), findsOneWidget);
    },
  );
}
