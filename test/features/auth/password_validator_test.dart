import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/auth/utils/password_validator.dart';

void main() {
  group('PasswordValidator Unit Tests', () {
    test('detects password shorter than 8 characters', () {
      const shortPass = 'Pass1!';
      expect(PasswordValidator.hasMinLength(shortPass), isFalse);
      expect(PasswordValidator.isStrong(shortPass), isFalse);
      expect(
        PasswordValidator.validate(shortPass),
        'Password must be at least 8 characters',
      );
    });

    test('detects missing uppercase letter', () {
      const noUpper = 'pass@1234';
      expect(PasswordValidator.hasUppercase(noUpper), isFalse);
      expect(PasswordValidator.isStrong(noUpper), isFalse);
      expect(
        PasswordValidator.validate(noUpper),
        'Include at least one uppercase letter (A-Z)',
      );
    });

    test('detects missing lowercase letter', () {
      const noLower = 'PASS@1234';
      expect(PasswordValidator.hasLowercase(noLower), isFalse);
      expect(PasswordValidator.isStrong(noLower), isFalse);
      expect(
        PasswordValidator.validate(noLower),
        'Include at least one lowercase letter (a-z)',
      );
    });

    test('detects missing digit', () {
      const noDigit = 'Password@';
      expect(PasswordValidator.hasDigit(noDigit), isFalse);
      expect(PasswordValidator.isStrong(noDigit), isFalse);
      expect(
        PasswordValidator.validate(noDigit),
        'Include at least one digit (0-9)',
      );
    });

    test('detects missing special character', () {
      const noSpecial = 'Password123';
      expect(PasswordValidator.hasSpecialChar(noSpecial), isFalse);
      expect(PasswordValidator.isStrong(noSpecial), isFalse);
      expect(
        PasswordValidator.validate(noSpecial),
        'Include at least one special character (e.g. @, #, \$, !)',
      );
    });

    test('handles empty and null password inputs', () {
      expect(PasswordValidator.validate(''), 'Enter a password');
      expect(PasswordValidator.validate(null), 'Enter a password');
    });

    test('validates password satisfying every criterion', () {
      const validPasswords = [
        'Strong@Pass1',
        'P@ssw0rd2026',
        'Abcd#1234',
        'Admin!999',
        'Complex_Pass1',
      ];

      for (final pwd in validPasswords) {
        expect(
          PasswordValidator.hasMinLength(pwd),
          isTrue,
          reason: 'Failed min length for $pwd',
        );
        expect(
          PasswordValidator.hasUppercase(pwd),
          isTrue,
          reason: 'Failed uppercase for $pwd',
        );
        expect(
          PasswordValidator.hasLowercase(pwd),
          isTrue,
          reason: 'Failed lowercase for $pwd',
        );
        expect(
          PasswordValidator.hasDigit(pwd),
          isTrue,
          reason: 'Failed digit for $pwd',
        );
        expect(
          PasswordValidator.hasSpecialChar(pwd),
          isTrue,
          reason: 'Failed special char for $pwd',
        );
        expect(
          PasswordValidator.isStrong(pwd),
          isTrue,
          reason: 'Failed isStrong for $pwd',
        );
        expect(
          PasswordValidator.validate(pwd),
          isNull,
          reason: 'Failed validate for $pwd',
        );
      }
    });

    test('validates confirm password matching and mismatch cases', () {
      const validPwd = 'Strong@Pass1';

      expect(
        PasswordValidator.validateConfirm(null, validPwd),
        'Confirm your password',
      );
      expect(
        PasswordValidator.validateConfirm('', validPwd),
        'Confirm your password',
      );
      expect(
        PasswordValidator.validateConfirm('Different@Pass1', validPwd),
        'Passwords do not match',
      );
      expect(PasswordValidator.validateConfirm(validPwd, validPwd), isNull);
    });

    test('tracks unmetRequirements dynamically as password is being typed', () {
      expect(PasswordValidator.unmetRequirements(''), [
        '8+ characters',
        'Uppercase (A–Z)',
        'Lowercase (a–z)',
        'Digit (0–9)',
        'Special character',
      ]);
      expect(PasswordValidator.unmetRequirements('A'), [
        '8+ characters',
        'Lowercase (a–z)',
        'Digit (0–9)',
        'Special character',
      ]);
      expect(PasswordValidator.unmetRequirements('Ab'), [
        '8+ characters',
        'Digit (0–9)',
        'Special character',
      ]);
      expect(PasswordValidator.unmetRequirements('Ab1'), [
        '8+ characters',
        'Special character',
      ]);
      expect(PasswordValidator.unmetRequirements('Ab1!'), ['8+ characters']);
      expect(PasswordValidator.unmetRequirements('Ab1!cdef'), isEmpty);
    });
  });
}
