import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prashikshan/services/report_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

void main() {
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
              'latest_progress': 75,
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
      expect(summary.latestProgress, 75);
    },
  );
}
