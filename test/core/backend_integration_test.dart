import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:prashikshan/core/auth/auth_service.dart';
import 'package:prashikshan/core/config/backend_config.dart';
import 'package:prashikshan/core/network/api_client.dart';
import 'package:prashikshan/features/faculty_tp/data/models/student_monitoring_item.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/backend_student_monitoring_repository.dart';
import 'package:prashikshan/features/faculty_tp/data/repositories/student_monitoring_repository_factory.dart';

void main() {
  group('BackendConfig Tests', () {
    test('Default configuration provides valid base URL and timeout', () {
      expect(BackendConfig.baseUrl, isNotEmpty);
      expect(BackendConfig.timeout, equals(const Duration(seconds: 15)));
    });

    test('Override URL works correctly', () {
      BackendConfig.setOverrideUrl('http://custom-host:8080');
      expect(BackendConfig.baseUrl, equals('http://custom-host:8080'));

      BackendConfig.setOverrideUrl(null);
      expect(BackendConfig.baseUrl, isNot('http://custom-host:8080'));
    });
  });

  group('ApiClient Tests', () {
    test('GET successful response parses JSON body', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/students'));
        expect(request.headers['Accept'], equals('application/json'));
        return http.Response(
          jsonEncode({
            'success': true,
            'count': 1,
            'data': [
              {'id': '123', 'roll_number': 'CS101'}
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrlOverride: 'http://localhost:3000',
      );

      final result = await apiClient.get('/students');
      expect(result['success'], isTrue);
      expect(result['data'], isList);
      expect(result['data'].first['roll_number'], equals('CS101'));
    });

    test('HTTP 404 throws ApiException with message', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Student with ID not found',
          }),
          404,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrlOverride: 'http://localhost:3000',
      );

      expect(
        () => apiClient.get('/students/00000000-0000-0000-0000-000000000000'),
        throwsA(isA<ApiException>().having(
          (e) => e.statusCode,
          'statusCode',
          equals(404),
        )),
      );
    });

    test('POST request correctly encodes JSON payload', () async {
      final mockClient = MockClient((request) async {
        expect(request.method, equals('POST'));
        final body = jsonDecode(request.body);
        expect(body['progress_percentage'], equals(50));
        return http.Response(
          jsonEncode({
            'success': true,
            'data': {'id': 'update-1', 'progress_percentage': 50}
          }),
          201,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrlOverride: 'http://localhost:3000',
      );

      final result = await apiClient.post(
        '/internships/some-id/progress',
        body: {'progress_percentage': 50},
      );
      expect(result['success'], isTrue);
      expect(result['data']['progress_percentage'], equals(50));
    });
  });

  group('BackendStudentMonitoringRepository Tests', () {
    test('getStudents returns List<StudentMonitoringItem>', () async {
      final mockClient = MockClient((request) async {
        expect(request.url.path, equals('/monitoring/students'));
        return http.Response(
          jsonEncode({
            'success': true,
            'data': [
              {
                'studentId': 'std-1',
                'studentName': 'Rahul Sharma',
                'internshipId': 'int-1',
                'internshipTitle': 'Backend Developer Intern',
                'applicationStatus': 'approved',
              },
              {
                'studentId': 'std-2',
                'studentName': 'Priya Patel',
                'internshipId': 'int-2',
                'internshipTitle': 'Mobile App Intern',
                'applicationStatus': 'pending',
              }
            ]
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrlOverride: 'http://localhost:3000',
      );

      final repo = BackendStudentMonitoringRepository(apiClient: apiClient);
      final students = await repo.getStudents();

      expect(students.length, equals(2));
      expect(students.first, isA<StudentMonitoringItem>());
      expect(students.first.studentName, equals('Rahul Sharma'));
      expect(students.first.applicationStatus, equals('approved'));
      expect(students.last.studentName, equals('Priya Patel'));
      expect(students.last.applicationStatus, equals('pending'));
    });

    test('401 from backend maps to UnauthenticatedException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Authentication token required',
          }),
          401,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrlOverride: 'http://localhost:3000',
      );

      final repo = BackendStudentMonitoringRepository(apiClient: apiClient);
      expect(
        () => repo.getStudents(),
        throwsA(isA<UnauthenticatedException>()),
      );
    });

    test('403 from backend maps to UnauthorizedException', () async {
      final mockClient = MockClient((request) async {
        return http.Response(
          jsonEncode({
            'success': false,
            'message': 'Access forbidden: required role',
          }),
          403,
          headers: {'content-type': 'application/json'},
        );
      });

      final apiClient = ApiClient(
        httpClient: mockClient,
        baseUrlOverride: 'http://localhost:3000',
      );

      final repo = BackendStudentMonitoringRepository(apiClient: apiClient);
      expect(
        () => repo.getStudents(),
        throwsA(isA<UnauthorizedException>()),
      );
    });

    test('StudentMonitoringRepositoryFactory creates Backend repository', () {
      StudentMonitoringRepositoryFactory.reset();
      final backendRepo = StudentMonitoringRepositoryFactory.createBackend();
      expect(backendRepo, isA<BackendStudentMonitoringRepository>());

      StudentMonitoringRepositoryFactory.useBackendApi = true;
      final autoCreated = StudentMonitoringRepositoryFactory.create();
      expect(autoCreated, isA<BackendStudentMonitoringRepository>());
      StudentMonitoringRepositoryFactory.reset();

      // Test .env flag toggle
      dotenv.loadFromString(envString: 'USE_BACKEND_API=true');
      final envCreated = StudentMonitoringRepositoryFactory.create();
      expect(envCreated, isA<BackendStudentMonitoringRepository>());
      StudentMonitoringRepositoryFactory.reset();
      dotenv.clean();
    });
  });
}
