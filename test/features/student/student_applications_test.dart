import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/internship/models/internship.dart';
import 'package:prashikshan/models/student_models.dart';
import 'package:prashikshan/screens/student/applications_screen.dart';
import 'package:prashikshan/services/document_progress_service.dart';
import 'package:prashikshan/services/student_service.dart';

void main() {
  test('document and progress models parse database rows', () {
    final document = DocumentItem.fromMap({
      'id': 'document-1',
      'doc_type': 'resume',
      'file_name': 'resume.pdf',
      'uploaded_at': '2026-10-06T10:00:00.000Z',
    });
    final progress = ProgressLog.fromMap({
      'id': 'progress-1',
      'week_no': 2,
      'progress': 45,
      'summary': 'Completed API integration',
    });

    expect(document.id, 'document-1');
    expect(document.docType, 'resume');
    expect(document.fileName, 'resume.pdf');
    expect(document.uploadedAt, DateTime.utc(2026, 10, 6, 10));
    expect(progress.id, 'progress-1');
    expect(progress.weekNo, 2);
    expect(progress.progress, 45);
    expect(progress.summary, 'Completed API integration');
  });

  testWidgets('applications list opens details with documents and progress', (
    tester,
  ) async {
    final internship = _internship(status: 'approved');
    final service = _FakeStudentService([Application(internship)]);
    final documents = _FakeDocumentProgressService(
      documentItems: [
        DocumentItem(
          'document-1',
          'resume',
          'resume.pdf',
          DateTime.utc(2026, 10, 6),
        ),
      ],
      progressItems: [
        const ProgressLog('progress-1', 2, 45, 'Completed API integration'),
      ],
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApplicationsScreen(
            service: service,
            documentService: documents,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Backend internship'), findsOneWidget);
    expect(find.textContaining('Demo Technologies'), findsOneWidget);

    await tester.tap(find.text('Backend internship'));
    await tester.pumpAndSettle();

    expect(find.text('Documents'), findsOneWidget);
    expect(find.text('resume.pdf'), findsOneWidget);
    expect(documents.requestedDocuments, ['internship-1']);

    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();

    expect(find.text('Overall progress: 45%'), findsOneWidget);
    expect(find.text('Week 2 · 45%'), findsOneWidget);
    expect(find.text('Completed API integration'), findsOneWidget);
    expect(find.text('Week 3 update'), findsOneWidget);
  });

  testWidgets('pending internship cannot submit progress updates', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: ApplicationsScreen(
            service: _FakeStudentService([
              Application(_internship(status: 'pending')),
            ]),
            documentService: _FakeDocumentProgressService(),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Backend internship'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Progress').last);
    await tester.pumpAndSettle();

    expect(
      find.text('Progress updates open once your internship is approved.'),
      findsOneWidget,
    );
    expect(find.text('Save update'), findsNothing);
  });
}

Internship _internship({required String status}) => Internship(
  id: 'internship-1',
  studentId: 'student-1',
  companyName: 'Demo Technologies',
  title: 'Backend internship',
  mode: 'remote',
  startDate: DateTime.utc(2026, 10, 1),
  endDate: DateTime.utc(2026, 12, 1),
  status: status,
  progress: 45,
  createdAt: DateTime.utc(2026, 9, 20),
);

class _FakeStudentService implements StudentDataSource {
  _FakeStudentService(this.applications);

  final List<Application> applications;

  @override
  Future<List<Application>> myApplications() async => applications;
}

class _FakeDocumentProgressService implements DocumentProgressDataSource {
  _FakeDocumentProgressService({
    this.documentItems = const [],
    this.progressItems = const [],
  });

  final List<DocumentItem> documentItems;
  final List<ProgressLog> progressItems;
  final requestedDocuments = <String>[];
  final requestedProgress = <String>[];

  @override
  Future<List<DocumentItem>> documents(String internshipId) async {
    requestedDocuments.add(internshipId);
    return documentItems;
  }

  @override
  Future<List<ProgressLog>> progress(String internshipId) async {
    requestedProgress.add(internshipId);
    return progressItems;
  }

  @override
  Future<void> addProgress(
    String internshipId,
    int week,
    int progress,
    String summary,
  ) async {}

  @override
  Future<void> upload(
    String internshipId,
    String docType,
    PlatformFile file,
  ) async {}
}
