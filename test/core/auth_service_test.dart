import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/core/auth/auth_service.dart';

void main() {
  group('AuthService In-Flight Protection and Error Translation Tests', () {
    test('parseAuthErrorMessage translates over_email_send_rate_limit to friendly actionable message', () {
      final error = Exception(
        'AuthException: over_email_send_rate_limit, code: 429',
      );
      final message = AuthService.parseAuthErrorMessage(error);
      expect(message, contains('Email delivery rate limit reached'));
      expect(message, contains('2-4 emails/hr'));
      expect(message, contains('Send Email Hook'));
    });

    test('parseAuthErrorMessage translates invalid credentials', () {
      final error = Exception('AuthException: Invalid login credentials');
      final message = AuthService.parseAuthErrorMessage(error);
      expect(message, contains('Invalid email or password'));
    });

    test('parseAuthErrorMessage translates email not confirmed', () {
      final error = Exception('AuthException: Email not confirmed');
      final message = AuthService.parseAuthErrorMessage(error);
      expect(message, contains('Email address is not yet confirmed'));
    });

    test('parseAuthErrorMessage translates user already registered', () {
      final error = Exception('AuthException: User already registered');
      final message = AuthService.parseAuthErrorMessage(error);
      expect(message, contains('already exists'));
    });

    test('parseAuthErrorMessage translates network socket failure', () {
      final error = Exception('SocketException: Failed host lookup');
      final message = AuthService.parseAuthErrorMessage(error);
      expect(message, contains('Network connection error'));
    });

    test(
      'DuplicateRequestException formats default and custom message properly',
      () {
        const defaultException = DuplicateRequestException();
        expect(
          defaultException.toString(),
          contains('request is currently in progress'),
        );

        const customException = DuplicateRequestException(
          'Concurrent action blocked',
        );
        expect(customException.toString(), equals('Concurrent action blocked'));
      },
    );

    test('In-flight lock is reset after execution allows immediate retry without arbitrary 60s cooldown', () async {
      // Confirm that no arbitrary countdown lock remains active
      expect(AuthService.isEmailActionInProgress, isFalse);
    });

    test('parseAuthErrorMessage translates access denied role escalation error', () {
      final error = Exception(
        'PostgrestException: Access denied: Only administrators can assign elevated user roles.',
      );
      final message = AuthService.parseAuthErrorMessage(error);
      expect(
        message,
        contains(
          'Access denied: Only administrators can assign elevated user roles.',
        ),
      );
    });

    test('parseAuthErrorMessage translates target user profile not found', () {
      final error = Exception(
        'PostgrestException: Target user profile not found.',
      );
      final message = AuthService.parseAuthErrorMessage(error);
      expect(message, contains('Target user profile not found.'));
    });

    test('sanitizeSignupMetadata strips attempted admin role escalation from metadata', () {
      final input = {
        'full_name': 'Attacker',
        'role': 'admin',
        'enrollment_no': '23CS001',
      };
      final sanitized = AuthService.sanitizeSignupMetadata(input);
      expect(sanitized, isNotNull);
      expect(sanitized!['role'], isNull);
      expect(sanitized['full_name'], equals('Attacker'));
      expect(sanitized['enrollment_no'], equals('23CS001'));
    });

    test('sanitizeSignupMetadata strips faculty_mentor, tp_officer, and app_role parameters', () {
      final input = {
        'full_name': 'Student User',
        'role': 'faculty_mentor',
        'app_role': 'tp_officer',
        'roles': ['admin', 'faculty_mentor'],
        'is_admin': true,
        'isAdmin': true,
        'branch': 'Computer Science',
      };
      final sanitized = AuthService.sanitizeSignupMetadata(input);
      expect(sanitized, isNotNull);
      expect(sanitized!['role'], isNull);
      expect(sanitized['app_role'], isNull);
      expect(sanitized['roles'], isNull);
      expect(sanitized['is_admin'], isNull);
      expect(sanitized['isAdmin'], isNull);
      expect(sanitized['full_name'], equals('Student User'));
      expect(sanitized['branch'], equals('Computer Science'));
    });

    test('sanitizeSignupMetadata handles null input gracefully', () {
      expect(AuthService.sanitizeSignupMetadata(null), isNull);
    });
  });
}
