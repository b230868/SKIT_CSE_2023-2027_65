import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:prashikshan/models/notification_models.dart';
import 'package:prashikshan/screens/student/reports_screen.dart';

typedef _Loader = Future<ReportSummary> Function({bool force});

Widget _app(_Loader loader) => MaterialApp(home: ReportsScreen(loader: loader));

/// A tall test window so the whole scrolling report is built at once.
void _tallScreen(WidgetTester tester) {
  tester.view.physicalSize = const Size(800, 3200);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

ReportSummary _sample() => const ReportSummary(
      totalApplications: 5,
      approved: 3,
      pending: 1,
      rejected: 1,
      documentsUploaded: 2,
      latestProgress: 70,
      documentsByType: {'resume': 1, 'noc': 1},
      progressHistory: [
        ProgressPoint(weekNo: 1, progress: 10),
        ProgressPoint(weekNo: 2, progress: 20),
        ProgressPoint(weekNo: 3, progress: 30),
        ProgressPoint(weekNo: 4, progress: 40),
        ProgressPoint(weekNo: 5, progress: 50),
        ProgressPoint(weekNo: 6, progress: 70),
      ],
      studentName: 'Test Student',
      unreadNotifications: 1,
      notificationsByType: {'application': 2},
    );

void main() {
  testWidgets('a new student sees the empty state', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_app(({bool force = false}) async => ReportSummary.empty()));
    await tester.pumpAndSettle();

    expect(find.text('Nothing to report yet'), findsOneWidget);
    expect(find.text('Application summary'), findsNothing);
  });

  testWidgets('the report shows application and progress figures', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_app(({bool force = false}) async => _sample()));
    await tester.pumpAndSettle();

    expect(find.text('Application summary'), findsOneWidget);
    expect(find.text('60% of your applications were approved'), findsOneWidget);
    expect(find.text('Progress analytics'), findsOneWidget);
    expect(find.text('Best week'), findsOneWidget);
    expect(find.text('Week 6'), findsOneWidget); // gain of 20 in week 6 is the largest
    expect(find.text('Resume'), findsOneWidget);
    expect(find.text('NOC'), findsOneWidget);
    expect(find.text('1 of 2'), findsOneWidget); // unread notifications
  });

  testWidgets('choosing 4 weeks narrows the progress analytics', (tester) async {
    _tallScreen(tester);
    await tester.pumpWidget(_app(({bool force = false}) async => _sample()));
    await tester.pumpAndSettle();

    expect(find.text('6'), findsOneWidget); // weeks logged

    await tester.tap(find.text('4 weeks'));
    await tester.pumpAndSettle();

    expect(find.text('6'), findsNothing);
    expect(find.text('4'), findsOneWidget); // weeks logged in the window
  });

  testWidgets('an error shows Retry and recovers', (tester) async {
    _tallScreen(tester);
    var calls = 0;
    await tester.pumpWidget(_app(({bool force = false}) async {
      calls++;
      if (calls == 1) throw Exception('network down');
      return _sample();
    }));
    await tester.pumpAndSettle();

    expect(find.text('Could not load your report.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Application summary'), findsOneWidget);
    expect(calls, 2);
  });
}
