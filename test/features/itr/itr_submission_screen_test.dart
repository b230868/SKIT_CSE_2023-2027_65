import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/itr/data/models/itr_model.dart';
import 'package:prashikshan/features/itr/data/repositories/mock_itr_repository.dart';
import 'package:prashikshan/features/itr/data/services/itr_service.dart';
import 'package:prashikshan/features/itr/presentation/screens/itr_submission_screen.dart';

void main() {
  testWidgets('ItrSubmissionScreen renders input fields and saves draft', (
    WidgetTester tester,
  ) async {
    final mockRepo = MockItrRepository();
    final service = ItrService(mockRepo);

    const itr = ItrModel(
      id: 'itr-003',
      internshipId: 'internship-003',
      studentId: 'student-003',
      studentName: 'Aman Verma',
      internshipTitle: 'Flutter Development Intern',
      companyName: 'Tech Company',
      status: 'draft',
      projectZipPath: 'storage/project.zip',
      presentationPath: 'storage/presentation.pptx',
    );

    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    await tester.pumpWidget(
      MaterialApp(
        home: ItrSubmissionScreen(itr: itr, itrService: service),
      ),
    );

    await tester.pumpAndSettle();

    // Verify Title in AppBar
    expect(find.widgetWithText(AppBar, 'Submit ITR'), findsOneWidget);

    // Verify form fields exist
    expect(find.text('Internship Work Details / Summary *'), findsOneWidget);
    expect(
      find.text('Work Completed (Deliverables & Modules)'),
      findsOneWidget,
    );
    expect(find.text('Technologies & Tools Used'), findsOneWidget);
    expect(find.text('Key Learnings'), findsOneWidget);
    expect(find.text('Challenges Faced & Solutions'), findsOneWidget);

    // Verify project file cards & submit button
    expect(find.text('Project ZIP File'), findsOneWidget);
    expect(find.text('Project Presentation'), findsOneWidget);
    expect(find.widgetWithText(ElevatedButton, 'Submit ITR'), findsOneWidget);

    // Enter summary and submit
    await tester.enterText(
      find.widgetWithText(TextField, 'Internship Work Details / Summary *'),
      'Completed week 4 tasks.',
    );
    await tester.pumpAndSettle();

    await tester.ensureVisible(
      find.widgetWithText(ElevatedButton, 'Submit ITR'),
    );
    await tester.tap(find.widgetWithText(ElevatedButton, 'Submit ITR'));
    await tester.pumpAndSettle();

    // Verify updated state in mock repository
    final updated = await service.getItrById('itr-003');
    expect(updated, isNotNull);
    expect(updated!.content, equals('Completed week 4 tasks.'));
    expect(updated.status, equals('submitted'));
  });
}
