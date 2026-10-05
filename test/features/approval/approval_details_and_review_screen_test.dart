import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/approval/data/models/approval_request_model.dart';
import 'package:prashikshan/features/approval/data/repositories/mock_approval_repository.dart';
import 'package:prashikshan/features/approval/data/services/approval_repository_provider.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_review_stage.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_status.dart';
import 'package:prashikshan/features/approval/presentation/screens/approval_details_screen.dart';
import 'package:prashikshan/features/approval/presentation/screens/faculty_review_screen.dart';
import 'package:prashikshan/features/approval/presentation/screens/tp_review_screen.dart';

void main() {
  const sampleRequest = ApprovalRequestModel(
    internshipId: 'internship-001',
    studentId: 'student-001',
    studentName: 'Demo Student 1',
    rollNumber: 'PRK001',
    internshipTitle: 'Software Development Internship',
    industryId: 'industry-001',
    industryName: 'Demo Technology Ltd.',
    internshipStatus: 'pending',
    approvalStatus: ApprovalStatus.pending,
  );

  setUp(() {
    ApprovalRepositoryProvider.setRepository(MockApprovalRepository());
  });

  tearDown(() {
    ApprovalRepositoryProvider.reset();
  });

  testWidgets('ApprovalDetailsScreen displays student and internship details', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ApprovalDetailsScreen(
          request: sampleRequest,
          stage: ApprovalReviewStage.faculty,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Approval Details'), findsOneWidget);
    expect(find.text('Student Information'), findsOneWidget);
    expect(find.text('Demo Student 1'), findsOneWidget);
    expect(find.text('Software Development Internship'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('Open Faculty Review'), 200);
    expect(find.text('Open Faculty Review'), findsOneWidget);
  });

  testWidgets('FacultyReviewScreen displays form and blocks rejection without remarks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FacultyReviewScreen(
          request: sampleRequest,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Faculty Review'), findsOneWidget);
    expect(find.text('Submit Faculty Review'), findsOneWidget);

    // Select Rejected from dropdown
    await tester.tap(find.byType(DropdownButtonFormField<ApprovalStatus>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rejected').last);
    await tester.pumpAndSettle();

    // Tap submit without remarks
    await tester.tap(find.text('Submit Faculty Review'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter remarks for rejection.'), findsOneWidget);
  });

  testWidgets('TpReviewScreen displays form and requires rejection remarks', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TpReviewScreen(
          request: sampleRequest,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('T&P Review'), findsOneWidget);
    expect(find.text('Submit T&P Decision'), findsOneWidget);

    // Select Rejected from dropdown
    await tester.tap(find.byType(DropdownButtonFormField<ApprovalStatus>));
    await tester.pumpAndSettle();

    await tester.tap(find.text('Rejected').last);
    await tester.pumpAndSettle();

    // Tap submit without remarks
    await tester.tap(find.text('Submit T&P Decision'));
    await tester.pumpAndSettle();

    expect(find.text('Please enter rejection remarks.'), findsOneWidget);
  });
}
