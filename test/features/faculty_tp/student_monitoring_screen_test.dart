import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/student_monitoring_screen.dart';

void main() {
  testWidgets('student monitoring screen displays student data', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StudentMonitoringScreen()));

    await tester.pumpAndSettle();

    expect(find.text('Student Monitoring'), findsOneWidget);
    expect(find.text('Demo Student 1'), findsOneWidget);
    expect(
      find.textContaining('Software Development Internship'),
      findsOneWidget,
    );

    await tester.scrollUntilVisible(
      find.text('Demo Student 2'),
      200,
      scrollable: find.byType(Scrollable),
    );

    expect(find.text('Demo Student 2'), findsOneWidget);
    expect(
      find.textContaining('Data Analytics Internship'),
      findsOneWidget,
    );
  });

  testWidgets('Faculty sees student documents, Industry verification status, and can approve/reject separately', (tester) async {
    tester.view.physicalSize = const Size(800, 2000);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentMonitoringScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify student documents section header
    expect(
      find.text('Student Documents (Offer Letters & Certificates)'),
      findsAtLeastNWidgets(1),
    );

    // Verify document tile rendered
    expect(find.text('Rahul_TechNova_OfferLetter.pdf'), findsOneWidget);

    // Verify Industry verification status is displayed distinctly
    expect(find.text('Industry Verification: '), findsAtLeastNWidgets(1));
    expect(find.text('VERIFIED'), findsAtLeastNWidgets(1));
    expect(find.text('(Rajesh Varma (Tech Lead))'), findsAtLeastNWidgets(1));

    // Verify Faculty verification status is displayed separately as PENDING
    expect(find.text('Faculty Verification: '), findsAtLeastNWidgets(1));
    expect(find.text('PENDING'), findsAtLeastNWidgets(1));

    // Tap Faculty Reject button
    await tester.tap(find.text('Reject').first);
    await tester.pumpAndSettle();

    expect(find.text('Faculty Reject Document'), findsOneWidget);

    // Attempt to submit rejection without reason
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();
    expect(find.text('Rejection reason is mandatory'), findsOneWidget);

    // Enter reason and submit
    await tester.enterText(
      find.byType(TextFormField).first,
      'Need official university signature',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Reject'));
    await tester.pumpAndSettle();

    // Verify SnackBar and updated status
    expect(find.text('Document rejected by Faculty.'), findsOneWidget);
    expect(find.text('REJECTED'), findsAtLeastNWidgets(1));
  });
}
