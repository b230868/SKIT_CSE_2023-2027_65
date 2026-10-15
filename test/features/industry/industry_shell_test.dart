import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/auth/models/app_user.dart';
import 'package:prashikshan/features/industry/data/repositories/industry_repository_provider.dart';
import 'package:prashikshan/features/industry/data/repositories/mock_industry_repository.dart';
import 'package:prashikshan/features/industry/presentation/screens/industry_shell.dart';
import 'package:prashikshan/features/itr/data/repositories/itr_repository_provider.dart';
import 'package:prashikshan/features/itr/data/repositories/mock_itr_repository.dart';

void main() {
  setUp(() {
    IndustryRepositoryProvider.setInstance(MockIndustryRepository());
    ItrRepositoryProvider.setInstance(MockItrRepository());
  });

  tearDown(() {
    IndustryRepositoryProvider.reset();
    ItrRepositoryProvider.reset();
  });

  const testUser = AppUser(
    id: 'industry-user-1',
    fullName: 'Acme Corp Mentor',
    email: 'mentor@acmewidgets.com',
    role: 'industry',
    phone: '+91 9876543210',
  );

  group('IndustryShell System & Navigation E2E Tests', () {
    testWidgets(
      'renders all 5 navigation tabs and switches tabs via bottom bar',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: IndustryShell(user: testUser)),
        );

        await tester.pumpAndSettle();

        // Tab 0: Dashboard is default
        expect(find.text('Industry Dashboard'), findsOneWidget);
        expect(find.text('Active Interns'), findsOneWidget);

        // Verify bottom navigation bar destinations
        expect(find.byType(NavigationBar), findsOneWidget);
        expect(find.byType(NavigationDestination), findsNWidgets(5));

        // Tap 'Internships' tab via destination icon
        await tester.tap(find.byIcon(Icons.business_center_outlined));
        await tester.pumpAndSettle();
        expect(find.text('Internship Management'), findsOneWidget);
        expect(find.byType(TextField), findsOneWidget); // Search field

        // Tap 'ITR Reviews' tab via destination icon
        await tester.tap(find.byIcon(Icons.assignment_outlined));
        await tester.pumpAndSettle();
        expect(find.byType(ListView), findsWidgets);

        // Tap 'Reports' tab via destination icon
        await tester.tap(find.byIcon(Icons.bar_chart_outlined));
        await tester.pumpAndSettle();
        expect(find.text('Reports & Analytics'), findsOneWidget);
        expect(find.text('Internship Status Distribution'), findsOneWidget);

        // Tap 'Profile' tab via destination icon
        await tester.tap(find.byIcon(Icons.person_outline));
        await tester.pumpAndSettle();
        expect(find.text('mentor@acmewidgets.com'), findsOneWidget);
        expect(find.widgetWithText(AppBar, 'Profile'), findsOneWidget);
      },
    );

    testWidgets(
      'quick action shortcuts on dashboard switch to the corresponding tabs',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          const MaterialApp(home: IndustryShell(user: testUser)),
        );

        await tester.pumpAndSettle();

        // On Dashboard, tap 'Review Student ITRs' quick action card
        final reviewAction = find.widgetWithText(
          ListTile,
          'Review Student ITRs',
        );
        expect(reviewAction, findsOneWidget);
        await tester.tap(reviewAction);
        await tester.pumpAndSettle();

        // Verify destination is now selected index 2 (ITR Reviews)
        final navBar = tester.widget<NavigationBar>(find.byType(NavigationBar));
        expect(navBar.selectedIndex, 2);

        // Switch back to Dashboard (index 0)
        await tester.tap(find.byIcon(Icons.dashboard_outlined));
        await tester.pumpAndSettle();
        expect(find.text('Industry Dashboard'), findsOneWidget);

        // Tap 'View Reports & Analytics' quick action card
        final reportsAction = find.widgetWithText(
          ListTile,
          'View Reports & Analytics',
        );
        expect(reportsAction, findsOneWidget);
        await tester.tap(reportsAction);
        await tester.pumpAndSettle();

        // Verify destination is now selected index 3 (Reports)
        final navBarReports = tester.widget<NavigationBar>(
          find.byType(NavigationBar),
        );
        expect(navBarReports.selectedIndex, 3);
        expect(find.text('Internship Status Distribution'), findsOneWidget);
      },
    );
  });
}
