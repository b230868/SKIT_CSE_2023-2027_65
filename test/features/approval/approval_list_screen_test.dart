import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/approval/data/repositories/mock_approval_repository.dart';
import 'package:prashikshan/features/approval/data/services/approval_repository_provider.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_review_stage.dart';
import 'package:prashikshan/features/approval/presentation/screens/approval_list_screen.dart';

void main() {
  setUp(() {
    ApprovalRepositoryProvider.setRepository(MockApprovalRepository());
  });

  tearDown(() {
    ApprovalRepositoryProvider.reset();
  });

  testWidgets('ApprovalListScreen displays requests and search bar', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ApprovalListScreen(
          title: 'Faculty Approval Requests',
          stage: ApprovalReviewStage.faculty,
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Faculty Approval Requests'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    expect(find.text('Demo Student 1'), findsOneWidget);
  });

  testWidgets('ApprovalListScreen filters by search query', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ApprovalListScreen(
          title: 'Faculty Approval Requests',
          stage: ApprovalReviewStage.faculty,
        ),
      ),
    );

    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'Demo Student 2');
    await tester.pumpAndSettle();

    expect(find.widgetWithText(ListTile, 'Demo Student 2'), findsOneWidget);
    expect(find.widgetWithText(ListTile, 'Demo Student 1'), findsNothing);
  });
}
