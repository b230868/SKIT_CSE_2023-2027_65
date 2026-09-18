import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/tp_dashboard_screen.dart';
import 'package:flutter/material.dart';
void main() {
  testWidgets('T&P dashboard displays correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: TpDashboardScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('T&P Dashboard'), findsOneWidget);
    expect(find.text('T&P Overview'), findsOneWidget);
    expect(find.text('Pending Approvals'), findsOneWidget);
    expect(find.text('Approved Internships'), findsOneWidget);
    expect(find.text('Rejected Applications'), findsOneWidget);
    expect(find.text('Students Requiring Review'), findsOneWidget);
  });
}