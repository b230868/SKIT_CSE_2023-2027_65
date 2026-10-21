import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/industry_internship_model.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_repository.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_internship_details_screen.dart';

void main() {
  testWidgets(
    'IndustryInternshipDetailsScreen verifies and rejects student uploaded documents',
    (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockRepo = MockIndustryRepository();
      final service = IndustryService(repository: mockRepo);

      final testInternship = const IndustryInternshipModel(
        id: '1',
        studentName: 'Rahul Sharma',
        studentRollNo: 'CS2026-042',
        branch: 'Computer Science',
        internshipTitle: 'Software Development Intern',
        companyName: 'TechNova Solutions',
        startDate: null,
        endDate: null,
        status: 'active',
        progress: 65,
        itrStatus: 'submitted',
        evaluationStatus: 'pending',
      );

      await tester.pumpWidget(
        MaterialApp(
          home: IndustryInternshipDetailsScreen(
            internship: testInternship,
            industryService: service,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Verify title and headers render
      expect(find.text('Internship Details'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);

      // Scroll down to Student-Uploaded Documents section
      await tester.scrollUntilVisible(
        find.text('Student-Uploaded Documents'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Student-Uploaded Documents'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.text('Student Offer Letter'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Student Offer Letter'), findsOneWidget);

      // Verify action buttons exist for the document
      expect(find.text('Preview / Download'), findsAtLeastNWidgets(1));
      expect(find.text('Verify'), findsAtLeastNWidgets(1));
      expect(find.text('Reject'), findsAtLeastNWidgets(1));

      // Tap Reject on the first document to verify mandatory rejection reason validation
      await tester.tap(find.text('Reject').first);
      await tester.pumpAndSettle();

      expect(
        find.text('A mandatory rejection reason is required:'),
        findsOneWidget,
      );
      expect(find.text('Reject Document'), findsOneWidget);

      // Attempt to submit rejection without reason
      await tester.tap(find.text('Reject Document'));
      await tester.pumpAndSettle();
      expect(
        find.text('Please provide a reason for rejection.'),
        findsOneWidget,
      );

      // Enter rejection reason and submit
      await tester.enterText(
        find.byType(TextFormField).first,
        'Invalid company seal on offer letter',
      );
      await tester.tap(find.text('Reject Document'));
      await tester.pumpAndSettle();

      // Verify status updated to REJECTED
      expect(find.text('REJECTED'), findsOneWidget);
      expect(find.textContaining('Invalid company seal'), findsOneWidget);
    },
  );
}
