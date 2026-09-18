import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/student_monitoring_screen.dart';

void main() {
  testWidgets('student monitoring screen displays student data',
      (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: StudentMonitoringScreen(),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Student Monitoring'), findsOneWidget);
    expect(find.text('Demo Student 1'), findsOneWidget);
    expect(find.text('Demo Student 2'), findsOneWidget);
    expect(
      find.textContaining('Software Development Internship'),
      findsOneWidget,
    );
    expect(
      find.textContaining('Data Analytics Internship'),
      findsOneWidget,
    );
  });
}