import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_repository.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_reports_screen.dart';

void main() {
  group('IndustryReportsScreen Widget Tests', () {
    testWidgets(
      'renders reports, company metrics, and exports summary without ITR submission',
      (tester) async {
        final industryRepo = MockIndustryRepository();
        final industryService = IndustryService(repository: industryRepo);

        await tester.pumpWidget(
          MaterialApp(
            home: IndustryReportsScreen(industryService: industryService),
          ),
        );

        // Loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        await tester.pumpAndSettle();

        // Verify title & company
        expect(find.text('Reports & Analytics'), findsOneWidget);
        expect(find.text('TechNova Solutions'), findsOneWidget);

        // Verify metrics
        expect(find.text('Total Interns'), findsOneWidget);
        expect(find.text('24'), findsOneWidget);
        expect(find.text('Active Now'), findsOneWidget);
        expect(find.text('18'), findsOneWidget);
        expect(find.text('Attendance Pending'), findsOneWidget);
        expect(find.text('Evaluations'), findsOneWidget);

        // Strict verification: NO "ITR Submission" anywhere on IndustryReportsScreen
        expect(find.text('ITR Submissions'), findsNothing);
        expect(find.textContaining('ITR Submission'), findsNothing);

        // Verify PieChart is rendered
        expect(find.byType(PieChart), findsOneWidget);
        expect(find.text('Internship Status Distribution'), findsOneWidget);

        // Verify export icon button
        final exportButton = find.byIcon(Icons.share);
        expect(exportButton, findsOneWidget);

        await tester.tap(exportButton);
        await tester.pump();

        // Verify SnackBar confirmation
        expect(
          find.text('Comprehensive report summary copied to clipboard!'),
          findsOneWidget,
        );
      },
    );
  });
}
