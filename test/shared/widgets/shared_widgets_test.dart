import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prashikshan/shared/widgets/animated_count_card.dart';
import 'package:prashikshan/shared/widgets/empty_state_view.dart';
import 'package:prashikshan/shared/widgets/error_state_view.dart';
import 'package:prashikshan/shared/widgets/progress_ring.dart';
import 'package:prashikshan/shared/widgets/skeleton_loader.dart';
import 'package:prashikshan/shared/widgets/stepper_timeline.dart';

void main() {
  group('AnimatedCountCard Tests', () {
    testWidgets('renders label and count, handles tap', (tester) async {
      bool tapped = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AnimatedCountCard(
              label: 'Pending',
              count: 4,
              onTap: () => tapped = true,
            ),
          ),
        ),
      );

      // Verify label is present
      expect(find.text('Pending'), findsOneWidget);

      // Settle animations
      await tester.pumpAndSettle();
      expect(find.text('4'), findsOneWidget);

      // Tap card
      await tester.tap(find.byType(AnimatedCountCard));
      expect(tapped, true);
    });

    testWidgets('respects reduced-motion setting', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: true),
            child: Scaffold(
              body: AnimatedCountCard(label: 'Approved', count: 12),
            ),
          ),
        ),
      );

      // In reduced motion, it renders target count immediately
      expect(find.text('12'), findsOneWidget);
      expect(find.text('Approved'), findsOneWidget);
    });
  });

  group('ProgressRingCard Tests', () {
    testWidgets('renders percentage and context details', (tester) async {
      bool ringTapped = false;
      bool logTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ProgressRingCard(
              progress: 65,
              companyName: 'Infosys Ltd',
              roleTitle: 'Software Engineering Intern',
              isApproved: true,
              onTap: () => ringTapped = true,
              onLogProgress: () => logTapped = true,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      expect(find.text('65%'), findsOneWidget);
      expect(find.text('Infosys Ltd'), findsOneWidget);
      expect(find.text('Software Engineering Intern'), findsOneWidget);
      expect(find.text("Log this week's progress"), findsOneWidget);

      await tester.tap(find.text("Log this week's progress"));
      expect(logTapped, true);

      await tester.tap(find.byType(ProgressRingCard));
      expect(ringTapped, true);
    });

    testWidgets('does not show log progress button when not approved', (
      tester,
    ) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: ProgressRingCard(
              progress: 0,
              companyName: 'Pending Review',
              isApproved: false,
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();
      expect(find.text("Log this week's progress"), findsNothing);
    });
  });

  group('StepperTimeline Tests', () {
    testWidgets('renders all 6 lifecycle steps and handles step tap', (
      tester,
    ) async {
      int? tappedIndex;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StepperTimeline.fromApplicationState(
              status: 'approved',
              documentCount: 2,
              progressPercentage: 40,
              onStepTap: (i) => tappedIndex = i,
            ),
          ),
        ),
      );

      expect(find.text('Applied'), findsOneWidget);
      expect(find.text('Approved'), findsWidgets);
      expect(find.text('Documents'), findsOneWidget);
      expect(find.text('Progress'), findsOneWidget);
      expect(find.text('ITR'), findsOneWidget);
      expect(find.text('Certificate'), findsOneWidget);

      // Tap on step 2 (Documents)
      await tester.tap(find.text('Documents'));
      expect(tappedIndex, 2);
    });

    testWidgets('shows rejected status appropriately', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StepperTimeline.fromApplicationState(
              status: 'rejected',
              documentCount: 0,
              progressPercentage: 0,
            ),
          ),
        ),
      );

      expect(find.text('Rejected'), findsOneWidget);
    });
  });

  group('SkeletonLoader Tests', () {
    testWidgets('renders skeleton box and dashboard skeleton', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: DashboardSkeleton())),
      );

      expect(find.byType(DashboardSkeleton), findsOneWidget);
      expect(find.byType(SkeletonBox), findsWidgets);
    });
  });

  group('EmptyStateView and ErrorStateView Tests', () {
    testWidgets(
      'EmptyStateView displays title, description, and action button',
      (tester) async {
        bool actionTriggered = false;
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: EmptyStateView(
                title: 'No applications',
                description: 'You have not submitted any applications yet.',
                actionLabel: 'Apply now',
                onAction: () => actionTriggered = true,
              ),
            ),
          ),
        );

        expect(find.text('No applications'), findsOneWidget);
        expect(
          find.text('You have not submitted any applications yet.'),
          findsOneWidget,
        );
        expect(find.text('Apply now'), findsOneWidget);

        await tester.tap(find.text('Apply now'));
        expect(actionTriggered, true);
      },
    );

    testWidgets('ErrorStateView displays message and triggers retry', (
      tester,
    ) async {
      bool retryTriggered = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: ErrorStateView(
              message: 'Failed to connect to server.',
              onRetry: () => retryTriggered = true,
            ),
          ),
        ),
      );

      expect(find.text('Something went wrong'), findsOneWidget);
      expect(find.text('Failed to connect to server.'), findsOneWidget);
      expect(find.text('Try again'), findsOneWidget);

      await tester.tap(find.text('Try again'));
      expect(retryTriggered, true);
    });
  });
}
