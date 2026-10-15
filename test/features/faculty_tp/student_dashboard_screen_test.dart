import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/student_dashboard_screen.dart';

void main() {
  testWidgets(
    'StudentDashboardScreen renders title and basic UI elements when unauthenticated',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: StudentDashboardScreen()),
      );

      await tester.pumpAndSettle();

      // Verify AppBar title and unauthenticated state
      expect(find.text('Student Dashboard'), findsOneWidget);
      expect(find.byIcon(Icons.account_circle), findsOneWidget);
      expect(find.byIcon(Icons.refresh), findsWidgets);
      expect(
        find.text('Please sign in to view your student dashboard.'),
        findsOneWidget,
      );
      expect(find.text('Retry'), findsOneWidget);
    },
  );
}
