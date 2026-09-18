import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/faculty_dashboard_screen.dart';
import 'package:flutter/material.dart';
void main() {
  testWidgets('Faculty dashboard displays correctly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: FacultyDashboardScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Faculty & T&P Dashboard'), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Pending Approvals'), findsOneWidget);
    expect(find.text('Approved Internships'), findsOneWidget);
    expect(find.text('Rejected Applications'), findsOneWidget);
    expect(find.text('Students Requiring Review'), findsOneWidget);
  });
}