import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/faculty_tp/data/models/student_monitoring_detail.dart';
import 'package:prashikshan/features/faculty_tp/data/models/student_monitoring_item.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/student_monitoring_repository.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/student_monitoring_repository_factory.dart';
import 'package:prashikshan/features/faculty_tp/presentation/screens/student_detail_screen.dart';

class TestMockMonitoringRepo implements StudentMonitoringRepository {
  final StudentMonitoringDetail? detailToReturn;
  final bool shouldThrow;

  TestMockMonitoringRepo({
    this.detailToReturn,
    this.shouldThrow = false,
  });

  @override
  Future<List<StudentMonitoringItem>> getStudents() async => [];

  @override
  Future<StudentMonitoringDetail?> getStudentDetails(
    String studentId, {
    String? internshipId,
  }) async {
    if (shouldThrow) {
      throw Exception('Database query failure');
    }
    return detailToReturn;
  }

  @override
  Future<String?> getFileUrl({
    required String bucket,
    required String path,
  }) async {
    return 'https://supabase.prashikshan.test/storage/v1/object/sign/$bucket/$path?token=mock_jwt';
  }
}

void main() {
  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
  });

  tearDown(() {
    StudentMonitoringRepositoryFactory.reset();
  });



  final sampleDetail = StudentMonitoringDetail(
    studentId: 'student-101',
    studentName: 'Aarav Sharma',
    studentEmail: 'aarav.sharma@college.edu',
    rollNumber: '23CS101',
    department: 'Computer Science',
    branch: 'Computer Science and Engineering',
    batchYear: 2026,
    phone: '+91 9876543210',
    address: 'Jaipur, Rajasthan',
    internshipId: 'internship-202',
    internshipTitle: 'Flutter App Developer',
    companyName: 'ABC Technologies',
    internshipMode: 'onsite',
    startDate: DateTime(2026, 9, 1),
    endDate: DateTime(2026, 10, 31),
    internshipStatus: 'active',
    progress: 75,
    description: 'Developing Prashikshan mobile portal modules.',
    industryName: 'ABC Technologies',
    industryAddress: 'Malviya Nagar, Jaipur',
    industryEmail: 'contact@abctech.com',
    industryPhone: '0141-2345678',
    itrId: 'itr-303',
    itrStatus: 'submitted',
    itrProjectTitle: 'Prashikshan Mobile App',
    itrContent: 'Detailed report on cross-platform features and testing.',
    itrWorkDone: 'Built authentication and student monitoring views.',
    itrTechnologiesUsed: 'Flutter, Dart, Supabase',
    itrKeyLearnings: 'State management and backend schema integration.',
    itrChallengesFaced: 'Managing asynchronous locks and complex filters.',
    itrDocumentPath: 'itrs/student-101/final_report.pdf',
    itrProjectZipPath: 'itrs/student-101/code.zip',
    itrSubmittedAt: DateTime(2026, 10, 5),
    itrReviewerName: 'Dr. Verma',
    itrRemarks: 'Good progress. Ready for final evaluation.',
    certificateId: 'cert-404',
    certificateFilePath: 'certificates/student-101/internship_cert.pdf',
    certificateStatus: 'approved',
    certificateCreatedAt: DateTime(2026, 10, 10),
    approvalReviews: [
      StudentApprovalReviewItem(
        id: 'rev-1',
        reviewStage: 'faculty',
        status: 'approved',
        remarks: 'Approved by faculty mentor.',
        createdAt: DateTime(2026, 9, 5),
      ),
      StudentApprovalReviewItem(
        id: 'rev-2',
        reviewStage: 'tp_admin',
        status: 'pending',
        remarks: 'Under verification by T&P cell.',
        createdAt: DateTime(2026, 9, 6),
      ),
    ],
  );

  testWidgets('StudentDetailScreen renders all 6 tabs and displays overview info', (tester) async {
    StudentMonitoringRepositoryFactory.setRepository(
      TestMockMonitoringRepo(detailToReturn: sampleDetail),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentDetailScreen(
          studentId: 'student-101',
          internshipId: 'internship-202',
          studentName: 'Aarav Sharma',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Verify TabBar
    expect(find.text('Overview'), findsOneWidget);
    expect(find.text('Academic Details'), findsOneWidget);
    expect(find.text('Internship'), findsOneWidget);
    expect(find.text('ITR / Work'), findsOneWidget);
    expect(find.text('Certificates'), findsOneWidget);
    expect(find.text('Approvals & Progress'), findsOneWidget);

    // Verify Overview content
    expect(find.text('Aarav Sharma'), findsWidgets);
    expect(find.textContaining('23CS101'), findsOneWidget);
    expect(find.textContaining('aarav.sharma@college.edu'), findsOneWidget);
    expect(find.text('Progress & Completion Summary'), findsOneWidget);
    expect(find.text('Profile Completion'), findsOneWidget);
    expect(find.text('Internship Progress'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
  });

  testWidgets('Academic tab displays real personal and enrollment details', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    StudentMonitoringRepositoryFactory.setRepository(
      TestMockMonitoringRepo(detailToReturn: sampleDetail),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentDetailScreen(
          studentId: 'student-101',
          internshipId: 'internship-202',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to Academic Details tab
    await tester.tap(find.text('Academic Details'));
    await tester.pumpAndSettle();

    expect(find.text('Personal & Contact Information'), findsOneWidget);
    expect(find.text('+91 9876543210'), findsOneWidget);
    expect(find.text('Jaipur, Rajasthan'), findsOneWidget);
    expect(find.text('Academic Enrollment'), findsOneWidget);
    expect(find.text('Computer Science and Engineering'), findsOneWidget);
    expect(find.text('2026'), findsOneWidget);
  });

  testWidgets('Internship tab displays company, role, mode, and objectives', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    StudentMonitoringRepositoryFactory.setRepository(
      TestMockMonitoringRepo(detailToReturn: sampleDetail),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentDetailScreen(
          studentId: 'student-101',
          internshipId: 'internship-202',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to Internship tab
    await tester.tap(find.text('Internship'));
    await tester.pumpAndSettle();

    expect(find.text('Flutter App Developer'), findsOneWidget);
    expect(find.text('ABC Technologies'), findsWidgets);
    expect(find.text('onsite'), findsOneWidget);
    expect(find.text('75%'), findsOneWidget);
    expect(find.text('Developing Prashikshan mobile portal modules.'), findsOneWidget);
    expect(find.text('Host Organization Details'), findsOneWidget);
    expect(find.text('contact@abctech.com'), findsOneWidget);
  });

  testWidgets('ITR tab displays report details and secure file access', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    StudentMonitoringRepositoryFactory.setRepository(
      TestMockMonitoringRepo(detailToReturn: sampleDetail),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentDetailScreen(
          studentId: 'student-101',
          internshipId: 'internship-202',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to ITR / Work tab
    await tester.tap(find.text('ITR / Work'));
    await tester.pumpAndSettle();

    expect(find.text('Industrial Training Report (ITR)'), findsOneWidget);
    expect(find.text('Prashikshan Mobile App'), findsOneWidget);
    expect(find.text('SUBMITTED'), findsOneWidget);
    expect(find.text('Dr. Verma'), findsOneWidget);
    expect(find.text('Good progress. Ready for final evaluation.'), findsOneWidget);
    expect(find.text('ITR Written Report'), findsOneWidget);
    expect(find.text('Project Source Code / Archive'), findsOneWidget);

    // Tap Access File button
    await tester.tap(find.widgetWithText(FilledButton, 'Access File'));
    await tester.pumpAndSettle();

    // Verify secure link dialog appeared with signed URL
    expect(find.textContaining('secure link has been generated'), findsOneWidget);
    expect(find.textContaining('https://supabase.prashikshan.test'), findsOneWidget);
    expect(find.text('Copy Link'), findsOneWidget);

    await tester.tap(find.text('Done'));
    await tester.pumpAndSettle();
  });

  testWidgets('Certificates tab shows uploaded status and missing expiry disclaimer', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    StudentMonitoringRepositoryFactory.setRepository(
      TestMockMonitoringRepo(detailToReturn: sampleDetail),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentDetailScreen(
          studentId: 'student-101',
          internshipId: 'internship-202',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to Certificates tab
    await tester.tap(find.text('Certificates'));
    await tester.pumpAndSettle();

    expect(find.text('Internship Certificate Uploaded'), findsOneWidget);
    expect(find.text('APPROVED'), findsOneWidget);
    expect(find.text('Not tracked in database schema'), findsOneWidget);
    expect(find.text('Access & Preview Certificate'), findsOneWidget);
  });

  testWidgets('Approvals tab displays review workflow and checklist', (tester) async {
    tester.view.devicePixelRatio = 1.0;
    tester.view.physicalSize = const Size(1400, 900);
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    StudentMonitoringRepositoryFactory.setRepository(
      TestMockMonitoringRepo(detailToReturn: sampleDetail),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentDetailScreen(
          studentId: 'student-101',
          internshipId: 'internship-202',
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Switch to Approvals & Progress tab
    await tester.tap(find.text('Approvals & Progress'));
    await tester.pumpAndSettle();


    expect(find.text('Approval Review Workflow'), findsOneWidget);
    expect(find.text('Stage: FACULTY'), findsOneWidget);
    expect(find.text('Stage: TP_ADMIN'), findsOneWidget);
    expect(find.text('Requirements Verification Checklist'), findsOneWidget);
    expect(find.text('Student Profile Completed'), findsOneWidget);
    expect(find.text('ITR / Work Report Submitted'), findsOneWidget);
  });

  testWidgets('Failed data load shows user-friendly error message and retry button', (tester) async {
    StudentMonitoringRepositoryFactory.setRepository(
      TestMockMonitoringRepo(shouldThrow: true),
    );

    await tester.pumpWidget(
      const MaterialApp(
        home: StudentDetailScreen(studentId: 'student-error'),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Unable to load student details.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });
}
