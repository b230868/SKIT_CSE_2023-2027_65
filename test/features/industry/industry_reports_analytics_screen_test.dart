import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_repository.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_reports_analytics_screen.dart';

void main() {
  testWidgets(
    'IndustryReportsAnalyticsScreen renders KPIs, charts, and export summary dialog without ITR submission',
    (WidgetTester tester) async {
      final mockRepo = MockIndustryRepository();
      final service = IndustryService(repository: mockRepo);

      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);

      await tester.pumpWidget(
        MaterialApp(
          home: IndustryReportsAnalyticsScreen(industryService: service),
        ),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      await tester.pumpAndSettle();

      // Verify Title & Partner Card
      expect(find.text('Industry Reports & Analytics'), findsOneWidget);
      expect(find.text('TechNova Solutions'), findsOneWidget);

      // Verify KPI Cards
      expect(find.text('Total Interns'), findsOneWidget);
      expect(find.text('24'), findsWidgets);
      expect(find.text('Active Interns'), findsOneWidget);
      expect(find.text('18'), findsWidgets);
      expect(find.text('Average Score'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('6'), findsWidgets);

      // Verify Charts: Progress bar chart and Evaluation & Document status chart
      expect(find.byType(BarChart), findsOneWidget);
      expect(find.byType(PieChart), findsOneWidget);
      expect(find.text('Evaluation & Document Status'), findsOneWidget);

      // Strict verification: NO ITR Submission metrics on IndustryReportsAnalyticsScreen
      expect(find.text('ITR Submission & Review Status'), findsNothing);
      expect(find.textContaining('ITR Submission'), findsNothing);
      expect(find.text('Pending ITRs'), findsNothing);
      expect(find.text('Submitted ITRs'), findsNothing);
      expect(find.text('Approved ITRs'), findsNothing);

      // Verify Export Button
      expect(find.text('Export Analytics Summary'), findsOneWidget);

      // Tap Export button opens AlertDialog
      await tester.tap(find.text('Export Analytics Summary'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Export Analytics Summary'), findsWidgets);
      expect(find.text('Copy to Clipboard'), findsOneWidget);

      // Export summary dialog should not contain ITR metrics
      expect(find.textContaining('--- ITR REVIEW METRICS ---'), findsNothing);
      expect(
        find.textContaining('--- ATTENDANCE & EVALUATION METRICS ---'),
        findsOneWidget,
      );
      expect(
        find.textContaining('--- DOCUMENT VERIFICATION METRICS ---'),
        findsOneWidget,
      );

      // Close dialog
      await tester.tap(find.text('Close'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
    },
  );
}
