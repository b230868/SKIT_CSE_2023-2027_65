import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/approval/data/repositories/mock_approval_repository.dart';
import 'package:prashikshan/features/approval/data/services/approval_repository_provider.dart';
import 'package:prashikshan/features/approval/presentation/screens/faculty_approval_dashboard_screen.dart';
import 'package:prashikshan/features/approval/presentation/screens/tp_approval_dashboard_screen.dart';

void main() {
  setUp(() {
    ApprovalRepositoryProvider.setRepository(MockApprovalRepository());
  });

  tearDown(() {
    ApprovalRepositoryProvider.reset();
  });

  testWidgets(
    'FacultyApprovalDashboardScreen displays statistics and action button',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FacultyApprovalDashboardScreen()),
      );

      await tester.pumpAndSettle();

      expect(find.text('Faculty Approval Dashboard'), findsOneWidget);
      expect(find.text('Approval Overview'), findsOneWidget);
      expect(find.text('Pending Approvals'), findsOneWidget);
      expect(find.text('View Approval Requests'), findsOneWidget);
    },
  );

  testWidgets(
    'TpApprovalDashboardScreen displays statistics and action button',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: TpApprovalDashboardScreen()),
      );

      await tester.pumpAndSettle();

      expect(find.text('T&P Approval Dashboard'), findsOneWidget);
      expect(find.text('T&P Approval Overview'), findsOneWidget);
      expect(find.text('Pending Approvals'), findsOneWidget);
      expect(find.text('View T&P Approval Requests'), findsOneWidget);
    },
  );

  testWidgets(
    'FacultyApprovalDashboardScreen tapping stat card navigates with filter',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: FacultyApprovalDashboardScreen()),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.widgetWithText(ListTile, 'Pending Approvals'));
      await tester.pumpAndSettle();

      expect(find.text('Faculty Approval Requests'), findsOneWidget);
      expect(find.widgetWithText(ListTile, 'Demo Student 1'), findsOneWidget);
    },
  );
}
