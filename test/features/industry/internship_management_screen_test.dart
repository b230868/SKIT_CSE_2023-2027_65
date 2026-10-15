import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/industry/data/models/industry_dashboard_data.dart';
import 'package:prashikshan/features/industry/data/models/industry_internship_model.dart';
import 'package:prashikshan/features/industry/data/repositories/industry_repository.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_repository.dart';
import 'package:prashikshan/features/industry/data/services/industry_service.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_internship_details_screen.dart';
import 'package:prashikshan/features/industry/presentation/screens/internship_management_screen.dart';

class FailingInternshipRepository implements IndustryRepository {
  bool shouldFail = true;

  @override
  Future<List<IndustryInternshipModel>> getIndustryInternships() async {
    if (shouldFail) {
      throw Exception('Server returned 500 internal error');
    }
    return const [
      IndustryInternshipModel(
        id: 'rec-1',
        studentName: 'Recovered Student',
        internshipTitle: 'Systems Intern',
        status: 'active',
        progress: 50,
        itrStatus: 'submitted',
        evaluationStatus: 'verified',
      ),
    ];
  }

  @override
  Future<IndustryDashboardData> getDashboardData() async {
    return IndustryDashboardData.empty();
  }
}

void main() {
  group('InternshipManagementScreen Widget Tests', () {
    testWidgets('renders all internships and filters by search query', (
      tester,
    ) async {
      final mockRepo = MockIndustryRepository();
      final service = IndustryService(repository: mockRepo);

      await tester.pumpWidget(
        MaterialApp(home: InternshipManagementScreen(service: service)),
      );

      await tester.pumpAndSettle();

      // Verify header and initial list
      expect(find.text('Internship Management'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Priya Singh'), findsOneWidget);
      expect(find.text('Aman Verma'), findsOneWidget);

      // Search for 'Priya'
      await tester.enterText(find.byType(TextField), 'Priya');
      await tester.pumpAndSettle();

      // Only Priya Singh should remain
      expect(find.text('Priya Singh'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsNothing);
      expect(find.text('Aman Verma'), findsNothing);

      // Clear search
      await tester.tap(find.byIcon(Icons.clear));
      await tester.pumpAndSettle();

      expect(find.text('Rahul Sharma'), findsOneWidget);
      expect(find.text('Priya Singh'), findsOneWidget);
    });

    testWidgets('filters list when status ChoiceChip is selected', (
      tester,
    ) async {
      final mockRepo = MockIndustryRepository();
      final service = IndustryService(repository: mockRepo);

      await tester.pumpWidget(
        MaterialApp(home: InternshipManagementScreen(service: service)),
      );

      await tester.pumpAndSettle();

      // Tap on 'Completed' chip
      await tester.tap(find.widgetWithText(ChoiceChip, 'Completed'));
      await tester.pumpAndSettle();

      // Aman Verma is completed, Rahul Sharma and Priya Singh are active
      expect(find.text('Aman Verma'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsNothing);
      expect(find.text('Priya Singh'), findsNothing);
    });

    testWidgets('displays all three status chips: internship, ITR, and evaluation status', (
      tester,
    ) async {
      final mockRepo = MockIndustryRepository();
      final service = IndustryService(repository: mockRepo);

      await tester.pumpWidget(
        MaterialApp(home: InternshipManagementScreen(service: service)),
      );

      await tester.pumpAndSettle();

      // For Aman Verma: status='completed', itrStatus='approved', evaluationStatus='verified'
      // Chips render formatted uppercase labels
      expect(find.text('COMPLETED'), findsWidgets);
      expect(find.text('APPROVED'), findsWidgets);
      expect(find.text('VERIFIED'), findsWidgets);

      // For Rahul Sharma: status='active', itrStatus='submitted', evaluationStatus='pending'
      expect(find.text('ACTIVE'), findsWidgets);
      expect(find.text('SUBMITTED'), findsWidgets);
      expect(find.text('PENDING'), findsWidgets);

      // For Priya Singh: status='active', itrStatus='under_review', evaluationStatus='in_progress'
      expect(find.text('UNDER REVIEW'), findsWidgets);
      expect(find.text('IN PROGRESS'), findsWidgets);
    });

    testWidgets('sorts internships by progress and by name via ActionChip', (
      tester,
    ) async {
      final mockRepo = MockIndustryRepository();
      final service = IndustryService(repository: mockRepo);

      await tester.pumpWidget(
        MaterialApp(home: InternshipManagementScreen(service: service)),
      );

      await tester.pumpAndSettle();

      // Default sort is By Name ('Aman Verma', 'Priya Singh', 'Rahul Sharma')
      expect(find.text('By Name'), findsOneWidget);

      // Switch sort to By Progress (Aman: 100%, Priya: 80%, Rahul: 65%)
      await tester.tap(find.text('By Name'));
      await tester.pumpAndSettle();

      expect(find.text('By Progress'), findsOneWidget);

      // Switch back to By Name
      await tester.tap(find.text('By Progress'));
      await tester.pumpAndSettle();

      expect(find.text('By Name'), findsOneWidget);
    });

    testWidgets('renders empty state when query matches no records', (
      tester,
    ) async {
      final mockRepo = MockIndustryRepository();
      final service = IndustryService(repository: mockRepo);

      await tester.pumpWidget(
        MaterialApp(home: InternshipManagementScreen(service: service)),
      );

      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'NonExistentStudent12345');
      await tester.pumpAndSettle();

      expect(
        find.text('No internships match the selected criteria.'),
        findsOneWidget,
      );
    });

    testWidgets('renders error state and retries on failure', (tester) async {
      final failingRepo = FailingInternshipRepository();
      final service = IndustryService(repository: failingRepo);

      await tester.pumpWidget(
        MaterialApp(home: InternshipManagementScreen(service: service)),
      );

      await tester.pumpAndSettle();

      expect(find.textContaining('Unable to load internships.'), findsOneWidget);
      expect(find.textContaining('Server returned 500 internal error'), findsOneWidget);
      expect(find.text('Try Again'), findsOneWidget);

      failingRepo.shouldFail = false;
      await tester.tap(find.text('Try Again'));
      await tester.pumpAndSettle();

      expect(find.text('Recovered Student'), findsOneWidget);
      expect(find.text('Systems Intern'), findsOneWidget);
    });

    testWidgets('navigates to IndustryInternshipDetailsScreen when card is tapped', (
      tester,
    ) async {
      final mockRepo = MockIndustryRepository();
      final service = IndustryService(repository: mockRepo);

      await tester.pumpWidget(
        MaterialApp(home: InternshipManagementScreen(service: service)),
      );

      await tester.pumpAndSettle();

      await tester.tap(find.text('Rahul Sharma'));
      await tester.pumpAndSettle();

      expect(find.byType(IndustryInternshipDetailsScreen), findsOneWidget);
      expect(find.text('Internship Details'), findsOneWidget);
      expect(find.text('Rahul Sharma'), findsOneWidget);
    });
  });
}
