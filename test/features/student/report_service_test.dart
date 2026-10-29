import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prashikshan/models/notification_models.dart';
import 'package:prashikshan/services/report_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
  test('notification model reads internship links from the API', () {
    final notification = AppNotification.fromMap({
      'id': 'notification-1',
      'title': 'Application approved',
      'created_at': '2026-10-26T10:00:00Z',
      'internship_id': 'internship-1',
    });

    expect(notification.internshipId, 'internship-1');
    expect(notification.applicationId, 'internship-1');
  });

  test('report summary parses progress and document analytics', () {
    final summary = ReportSummary.fromMap({
      'total_applications': 3,
      'approved': 1,
      'pending': 1,
      'rejected': 0,
      'completed': 1,
      'documents_uploaded': 2,
      'documents_by_type': {'pdf': 1, 'image': 1},
      'latest_progress': 75,
      'progress': [
        {'week_no': 1, 'progress': 30, 'recorded_at': '2026-10-25T10:00:00Z'},
        {'week_no': 2, 'progress': 75, 'recorded_at': '2026-10-26T10:00:00Z'},
      ],
    });

    expect(summary.completed, 1);
    expect(summary.documentsByType, {'pdf': 1, 'image': 1});
    expect(summary.progressHistory, hasLength(2));
    expect(summary.progressHistory.last.progress, 75);
  });

  test(
    'requests student analytics from the authenticated Supabase RPC',
    () async {
      final client = SupabaseClient(
        'https://example.supabase.co',
        'test-publishable-key',
        httpClient: MockClient((request) async {
          expect(request.method, 'POST');
          expect(request.url.path, '/rest/v1/rpc/get_student_analytics');
          expect(request.headers['apikey'], 'test-publishable-key');
          return http.Response(
            jsonEncode({
              'total_applications': 3,
              'approved': 1,
              'pending': 1,
              'rejected': 0,
              'completed': 1,
              'documents_uploaded': 2,
              'documents_by_type': {'pdf': 1, 'image': 1},
              'latest_progress': 75,
              'progress': [
                {
                  'week_no': 1,
                  'progress': 30,
                  'recorded_at': '2026-10-25T10:00:00Z',
                },
                {
                  'week_no': 2,
                  'progress': 75,
                  'recorded_at': '2026-10-26T10:00:00Z',
                },
              ],
            }),
            200,
            headers: {'content-type': 'application/json'},
            request: request,
          );
        }),
      );
      addTearDown(client.dispose);

      final summary = await ReportService(client: client).studentSummary();

      expect(summary.totalApplications, 3);
      expect(summary.approved, 1);
      expect(summary.pending, 1);
      expect(summary.completed, 1);
      expect(summary.documentsUploaded, 2);
      expect(summary.documentsByType, {'pdf': 1, 'image': 1});
      expect(summary.latestProgress, 75);
      expect(summary.progressHistory, hasLength(2));
      expect(summary.progressHistory.last.progress, 75);
    },
  );
}
