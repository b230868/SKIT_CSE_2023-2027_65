import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/auth/data/auth_service.dart';

void main() {
  group('AuthService Rate Limiting & Error Translation Tests', () {
    test(
      'parseAuthErrorMessage translates over_email_send_rate_limit (HTTP 429)',
      () {
        final error = Exception(
          'AuthException: over_email_send_rate_limit, code: 429',
        );
        final message = AuthService.parseAuthErrorMessage(error);
        expect(message, contains('Email delivery rate limit reached'));
        expect(message, contains('2-4 emails/hr'));
        expect(message, contains('Send Email Hook'));
      },
    );

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

    test('DuplicateRequestException formats message properly', () {
      const defaultException = DuplicateRequestException();
      expect(defaultException.toString(), contains('already being processed'));

      const customException = DuplicateRequestException(
        'Custom in-flight lock',
      );
      expect(customException.toString(), equals('Custom in-flight lock'));
    });

    test('In-flight lock is initially false and allows immediate attempt', () {
      expect(AuthService.isEmailActionInProgress, isFalse);
    });

    test('sanitizeSignupMetadata strips unapproved admin role from public registration', () {
      final input = {
        'full_name': 'Test User',
        'role': 'admin',
        'is_admin': true,
        'enrollment_no': '23CS001',
      };
      final sanitized = AuthService.sanitizeSignupMetadata(input);
      expect(sanitized, isNotNull);
      expect(sanitized!['role'], isNull);
      expect(sanitized['is_admin'], isNull);
      expect(sanitized['full_name'], equals('Test User'));
      expect(sanitized['enrollment_no'], equals('23CS001'));
    });

    test('sanitizeSignupMetadata preserves legitimate student and industry metadata', () {
      final input = {
        'full_name': 'Industry Supervisor',
        'role': 'industry',
        'phone': '9876543210',
      };
      final sanitized = AuthService.sanitizeSignupMetadata(input);
      expect(sanitized, isNotNull);
      expect(sanitized!['role'], equals('industry'));
      expect(sanitized['full_name'], equals('Industry Supervisor'));
      expect(sanitized['phone'], equals('9876543210'));
    });

    test('sanitizeSignupMetadata handles null input gracefully', () {
      expect(AuthService.sanitizeSignupMetadata(null), isNull);
    });
  });
}
