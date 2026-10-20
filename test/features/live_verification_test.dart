import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:prashikshan/core/auth/auth_service.dart';
import 'package:prashikshan/core/config/supabase_config.dart';
import 'package:prashikshan/features/approval/data/repositories/supabase_approval_repository.dart';
import 'package:prashikshan/features/approval/domain/entities/approval_review_stage.dart';
import 'package:prashikshan/features/faculty_reports/data/repositories/supabase_faculty_report_repository.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/supabase_faculty_dashboard_repository.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/supabase_student_monitoring_repository.dart';

class TestHttpOverrides extends HttpOverrides {}

void main() {
  final runLiveTests = Platform.environment['RUN_LIVE_SUPABASE_TESTS'] == 'true';

  setUpAll(() async {
    if (!runLiveTests) return;
    HttpOverrides.global = TestHttpOverrides();
    await dotenv.load(fileName: '.env');
  });

  group('Live Supabase Backend Verification', skip: !runLiveTests, () {
    late final SupabaseClient client;

    setUpAll(() {
      client = SupabaseClient(
        SupabaseConfig.url,
        SupabaseConfig.publishableKey,
      );
    });

    test('Faculty authentication and profile check', () async {
      final res = await client.auth.signInWithPassword(
        email: 'faculty@faculty.com',
        password: 'Faculty@123',
      );

      expect(res.user, isNotNull);
      expect(res.session, isNotNull);

      final authService = AuthService(client: client);
      final profile = await authService.getCurrentUserProfile();
      expect(profile, isNotNull);
      expect(profile!.role, equals(AppRole.facultyMentor));
      expect(profile.isActive, isTrue);
    });

    test('Faculty dashboard statistics query real database', () async {
      final repo = SupabaseFacultyDashboardRepository(client: client);
      final stats = await repo.getDashboardStatistics();

      expect(stats.pendingApprovals, greaterThanOrEqualTo(0));
      expect(stats.approvedInternships, greaterThanOrEqualTo(0));
      expect(stats.rejectedApplications, greaterThanOrEqualTo(0));
      expect(stats.studentsRequiringReview, greaterThanOrEqualTo(0));
    });

    test('Student monitoring query real database', () async {
      final repo = SupabaseStudentMonitoringRepository(client: client);
      final students = await repo.getStudents();

      expect(students, isNotEmpty);
      expect(students.first.studentName, isNotEmpty);
      expect(students.first.internshipTitle, isNotEmpty);
    });

    test('Faculty approval requests query real database', () async {
      final repo = SupabaseApprovalRepository(client: client);
      final requests = await repo.getApprovalRequests(
        stage: ApprovalReviewStage.faculty,
      );

      expect(requests, isNotNull);
      expect(requests.length, greaterThanOrEqualTo(1));
    });

    test('Faculty reports query real database', () async {
      final repo = SupabaseFacultyReportRepository(client: client);
      final report = await repo.getReportData();

      expect(report.totalInternships, greaterThanOrEqualTo(1));
      expect(report.facultyStageCount, greaterThanOrEqualTo(0));
    });

    test(
      'T&P authentication, profile, dashboard, and requests check',
      () async {
        await client.auth.signOut();
        final res = await client.auth.signInWithPassword(
          email: 'tp@college.com',
          password: 'Tp@1234',
        );

        expect(res.user, isNotNull);
        expect(res.session, isNotNull);

        final authService = AuthService(client: client);
        final profile = await authService.getCurrentUserProfile();
        expect(profile, isNotNull);
        expect(profile!.role, equals(AppRole.tpOfficer));
        expect(profile.isActive, isTrue);

        final dashboardRepo = SupabaseFacultyDashboardRepository(
          client: client,
        );
        final stats = await dashboardRepo.getDashboardStatistics();
        expect(stats.pendingApprovals, greaterThanOrEqualTo(0));

        final monitoringRepo = SupabaseStudentMonitoringRepository(
          client: client,
        );
        final students = await monitoringRepo.getStudents();
        expect(students, isNotEmpty);

        final approvalRepo = SupabaseApprovalRepository(client: client);
        final requests = await approvalRepo.getApprovalRequests(
          stage: ApprovalReviewStage.tpAdmin,
        );
        expect(requests, isNotNull);
        final requestsFacultyStage = await approvalRepo.getApprovalRequests(
          stage: ApprovalReviewStage.faculty,
        );
        expect(requestsFacultyStage.length, greaterThanOrEqualTo(1));
      },
    );
  });
}
