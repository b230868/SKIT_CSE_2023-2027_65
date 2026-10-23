import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/data/models/student_monitoring_detail.dart';
import 'package:prashikshan/features/faculty_tp/data/models/student_monitoring_item.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/student_monitoring_repository.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/student_monitoring_repository_factory.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/student_detail_screen.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/student_monitoring_screen.dart';

class FilterTestRepository extends StudentMonitoringRepository {
  final List<StudentMonitoringItem> students = [
    const StudentMonitoringItem(
      studentId: 'student-1',
      studentName: 'Aarav Patel',
      internshipId: 'intern-1',
      internshipTitle: 'Mobile Flutter Intern',
      applicationStatus: 'active',
      studentEmail: 'aarav@college.edu',
      rollNumber: '23CS101',
      department: 'Computer Science',
      batchYear: 2026,
      companyName: 'Tech Innovations',
      internshipStatus: 'active',
      itrStatus: 'submitted',
      hasCertificate: true,
      progress: 80,
      hasPendingApprovals: false,
    ),
    const StudentMonitoringItem(
      studentId: 'student-2',
      studentName: 'Bhavna Sen',
      internshipId: 'intern-2',
      internshipTitle: 'Cloud DevOps Intern',
      applicationStatus: 'pending',
      studentEmail: 'bhavna@college.edu',
      rollNumber: '23IT202',
      department: 'Information Technology',
      batchYear: 2026,
      companyName: 'CloudSphere',
      internshipStatus: 'pending',
      itrStatus: 'draft',
      hasCertificate: false,
      progress: 30,
      hasPendingApprovals: true,
    ),
    const StudentMonitoringItem(
      studentId: 'student-3',
      studentName: 'Chirag Rao',
      internshipId: 'intern-3',
      internshipTitle: 'Embedded Systems Intern',
      applicationStatus: 'completed',
      studentEmail: 'chirag@college.edu',
      rollNumber: '23EE303',
      department: 'Electrical Engineering',
      batchYear: 2025,
      companyName: 'RoboTech Labs',
      internshipStatus: 'completed',
      itrStatus: null,
      hasCertificate: true,
      progress: 100,
      hasPendingApprovals: false,
    ),
  ];

  @override
  Future<List<StudentMonitoringItem>> getStudents() async => students;

  @override
  Future<StudentMonitoringDetail?> getStudentDetails(
    String studentId, {
    String? internshipId,
  }) async {
    final s = students.firstWhere((x) => x.studentId == studentId);
    return StudentMonitoringDetail(
      studentId: s.studentId,
      studentName: s.studentName,
      studentEmail: s.studentEmail ?? '',
      rollNumber: s.rollNumber,
      department: s.department,
      internshipId: s.internshipId,
      internshipTitle: s.internshipTitle,
      companyName: s.companyName,
      internshipStatus: s.internshipStatus,
      progress: s.progress,
      itrStatus: s.itrStatus,
      certificateFilePath: s.hasCertificate ? 'cert.pdf' : null,
    );
  }

  @override
  Future<String?> getFileUrl({
    required String bucket,
    required String path,
  }) async => 'https://example.com/$bucket/$path';

  @override
  Future<void> verifyStudentDocument({
    required String documentId,
    required String status,
    String? rejectionReason,
    String? remarks,
  }) async {}
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    StudentMonitoringRepositoryFactory.setRepository(FilterTestRepository());
  });

  tearDown(() {
    StudentMonitoringRepositoryFactory.reset();
  });

  testWidgets(
    'StudentMonitoringScreen displays student card with rich details',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: StudentMonitoringScreen()),
      );
      await tester.pumpAndSettle();

      expect(find.text('Student Monitoring'), findsOneWidget);
      expect(find.text('Aarav Patel'), findsOneWidget);
      expect(find.text('Bhavna Sen'), findsOneWidget);

      expect(find.text('Chirag Rao'), findsOneWidget);

      expect(find.textContaining('23CS101'), findsOneWidget);
      expect(find.textContaining('aarav@college.edu'), findsOneWidget);
      expect(find.textContaining('Tech Innovations'), findsOneWidget);
      expect(find.text('80%'), findsOneWidget);
      expect(find.text('ITR: SUBMITTED'), findsOneWidget);
      expect(find.text('Cert: Uploaded'), findsWidgets);
    },
  );

  testWidgets('Searching by student name filters results correctly', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StudentMonitoringScreen()));
    await tester.pumpAndSettle();

    // Search for Bhavna
    await tester.enterText(find.byType(TextField), 'Bhavna');
    await tester.pumpAndSettle();

    expect(find.text('Bhavna Sen'), findsOneWidget);
    expect(find.text('Aarav Patel'), findsNothing);
    expect(find.text('Chirag Rao'), findsNothing);
  });

  testWidgets('Searching by roll number filters results correctly', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StudentMonitoringScreen()));
    await tester.pumpAndSettle();

    // Search for 23EE303
    await tester.enterText(find.byType(TextField), '23EE303');
    await tester.pumpAndSettle();

    expect(find.text('Chirag Rao'), findsOneWidget);
    expect(find.text('Aarav Patel'), findsNothing);
    expect(find.text('Bhavna Sen'), findsNothing);
  });

  testWidgets(
    'Filtering by Pending Approvals only displays students awaiting review',
    (tester) async {
      tester.view.devicePixelRatio = 1.0;
      tester.view.physicalSize = const Size(1400, 1200);
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
      });

      await tester.pumpWidget(
        const MaterialApp(home: StudentMonitoringScreen()),
      );
      await tester.pumpAndSettle();

      // Tap Pending Approvals filter chip
      await tester.tap(find.widgetWithText(FilterChip, 'Pending Approvals'));
      await tester.pumpAndSettle();

      expect(find.text('Bhavna Sen'), findsOneWidget);
      expect(find.text('Aarav Patel'), findsNothing);
      expect(find.text('Chirag Rao'), findsNothing);
    },
  );

  testWidgets('No search match shows empty filter state and reset button', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 1200);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(const MaterialApp(home: StudentMonitoringScreen()));
    await tester.pumpAndSettle();

    // Search for non-existent student
    await tester.enterText(find.byType(TextField), 'NonExistentStudent');
    await tester.pumpAndSettle();

    expect(
      find.text('No students match your filter criteria.'),
      findsOneWidget,
    );
    expect(find.text('Reset All Filters'), findsOneWidget);

    // Tap Reset All Filters
    await tester.tap(find.text('Reset All Filters'));
    await tester.pumpAndSettle();

    expect(find.text('Aarav Patel'), findsOneWidget);
    expect(find.text('Bhavna Sen'), findsOneWidget);
    expect(find.text('Chirag Rao'), findsOneWidget);
  });

  testWidgets('Tapping a student card opens the StudentDetailScreen', (
    tester,
  ) async {
    await tester.pumpWidget(const MaterialApp(home: StudentMonitoringScreen()));
    await tester.pumpAndSettle();

    // Tap Aarav Patel card
    await tester.tap(find.text('Aarav Patel'));
    await tester.pumpAndSettle();

    // Verify StudentDetailScreen opened
    expect(find.byType(StudentDetailScreen), findsOneWidget);
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Academic Details'), findsOneWidget);
  });
}
