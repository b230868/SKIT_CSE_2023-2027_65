import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/industry_dashboard_data.dart';
import 'package:prashikshan/features/industry/data/models/industry_internship_model.dart';
import 'package:prashikshan/features/industry/data/repositories/industry_repository.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_repository.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_dashboard_screen.dart';

class FailingIndustryRepository implements IndustryRepository {
  bool shouldFail = true;

  @override
  Future<List<IndustryInternshipModel>> getIndustryInternships() async {
    if (shouldFail) {
      throw Exception('Database connection timed out.');
    }
    return const [];
  }

  @override
  Future<IndustryDashboardData> getDashboardData() async {
    if (shouldFail) {
      throw Exception('Database connection timed out.');
    }
    return IndustryDashboardData.empty('Recovered Corp');
  }
}

void main() {
  group('IndustryDashboardScreen Widget Tests', () {
    testWidgets('renders organization header, stat cards, and quick actions', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final mockRepo = MockIndustryRepository();
      final service = IndustryService(repository: mockRepo);

      await tester.pumpWidget(
        MaterialApp(home: IndustryDashboardScreen(service: service)),
      );

      // Initial loading state
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Pump async future completion
      await tester.pumpAndSettle();

      // Verify header and company title
      expect(find.text('Industry Dashboard'), findsOneWidget);
      expect(find.text('TechNova Solutions'), findsOneWidget);
      expect(find.text('Internship Partner Portal'), findsOneWidget);

      // Verify stat cards
      expect(find.text('Active Interns'), findsOneWidget);
      expect(find.text('18'), findsOneWidget);
      expect(find.text('ITR Pending'), findsOneWidget);
      expect(find.text('5'), findsOneWidget);
      expect(find.text('Evaluations Due'), findsOneWidget);
      expect(find.text('8'), findsOneWidget);
      expect(find.text('Completed'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);

      // Verify quick action items
      expect(find.text('Manage Internships'), findsOneWidget);
      expect(find.text('Review Student ITRs'), findsOneWidget);
      expect(find.text('View Reports & Analytics'), findsOneWidget);

      // Verify recent intern list preview
      expect(find.text('Recent Interns'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
    });

    testWidgets('renders empty state when no active internships exist', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final emptyRepo = MockIndustryRepository(
        internships: const [],
        dashboardData: const IndustryDashboardData(
          industryName: 'Empty Partner Labs',
          totalInterns: 0,
          activeInterns: 0,
          completedInternships: 0,
          pendingItrs: 0,
          submittedItrs: 0,
          pendingEvaluations: 0,
          completedEvaluations: 0,
        ),
      );
      final service = IndustryService(repository: emptyRepo);

      await tester.pumpWidget(
        MaterialApp(home: IndustryDashboardScreen(service: service)),
      );

      await tester.pumpAndSettle();

      expect(find.text('Empty Partner Labs'), findsOneWidget);
      expect(find.text('0'), findsWidgets);
      expect(find.text('No active internships found.'), findsOneWidget);
    });

    testWidgets('renders error state and retries on failure', (tester) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final failingRepo = FailingIndustryRepository();
      final service = IndustryService(repository: failingRepo);

      await tester.pumpWidget(
        MaterialApp(home: IndustryDashboardScreen(service: service)),
      );

      await tester.pumpAndSettle();

      // Error state display
      expect(find.textContaining('Unable to load dashboard.'), findsOneWidget);
      expect(find.textContaining('Database connection timed out.'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      // Fix failure and tap retry
      failingRepo.shouldFail = false;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Recovered Corp'), findsOneWidget);
      expect(find.text('No active internships found.'), findsOneWidget);
    });

    testWidgets('triggers callback when all quick action cards and view all are clicked', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(800, 1400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      int? navigatedTab;
      final mockRepo = MockIndustryRepository();
      final service = IndustryService(repository: mockRepo);

      await tester.pumpWidget(
        MaterialApp(
          home: IndustryDashboardScreen(
            service: service,
            onNavigateToTab: (tabIndex) => navigatedTab = tabIndex,
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Tap on 'Manage Internships' quick action card -> tab 1
      await tester.tap(find.text('Manage Internships'));
      await tester.pump();
      expect(navigatedTab, equals(1));

      // Tap on 'Review Student ITRs' quick action card -> tab 2
      await tester.tap(find.text('Review Student ITRs'));
      await tester.pump();
      expect(navigatedTab, equals(2));

      // Tap on 'View Reports & Analytics' quick action card -> tab 3
      await tester.tap(find.text('View Reports & Analytics'));
      await tester.pump();
      expect(navigatedTab, equals(3));

      // Tap on 'View All' text button -> tab 1
      await tester.tap(find.text('View All'));
      await tester.pump();
      expect(navigatedTab, equals(1));
    });
  });
}
