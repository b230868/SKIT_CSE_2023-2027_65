import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
<<<<<<< HEAD
import 'package:prashikshan/features/faculty_tp/presentation/screens/faculty_dashboard_screen.dart';

void main() {
  testWidgets('Faculty dashboard displays correctly', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: FacultyDashboardScreen()));

    await tester.pumpAndSettle();

    expect(find.text('Faculty & T&P Dashboard'), findsOneWidget);

    expect(find.text('Overview'), findsOneWidget);

    expect(find.text('Pending Approvals'), findsOneWidget);

    expect(find.text('Approved Internships'), findsOneWidget);

    expect(find.text('Rejected Applications'), findsOneWidget);

    expect(find.text('Students Requiring Review'), findsOneWidget);
=======
import 'package:prashikshan/main.dart';

void main() {
  testWidgets('Prashikshan app uses the configured home', (tester) async {
    await tester.pumpWidget(
      const PrashikshanApp(home: Scaffold(body: Text('Test home'))),
    );

    expect(find.text('Test home'), findsOneWidget);
>>>>>>> origin/main
  });
}
