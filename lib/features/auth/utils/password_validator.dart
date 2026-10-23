/// Utility class defining and validating password security requirements for Prashikshan.
class PasswordValidator {
  /// Checks if password is at least 8 characters long.
  static bool hasMinLength(String password) => password.length >= 8;

  /// Checks if password contains at least one uppercase letter (A-Z).
  static bool hasUppercase(String password) =>
      RegExp(r'[A-Z]').hasMatch(password);

  /// Checks if password contains at least one lowercase letter (a-z).
  static bool hasLowercase(String password) =>
      RegExp(r'[a-z]').hasMatch(password);

  /// Checks if password contains at least one digit (0-9).
  static bool hasDigit(String password) => RegExp(r'[0-9]').hasMatch(password);

  /// Checks if password contains at least one special character (e.g. @, #, $, !, etc.).
  static bool hasSpecialChar(String password) =>
      RegExp(r'[^A-Za-z0-9\s]').hasMatch(password);

  /// Evaluates whether all 5 password security criteria are satisfied.
  static bool isStrong(String password) {
    return hasMinLength(password) &&
        hasUppercase(password) &&
        hasLowercase(password) &&
        hasDigit(password) &&
        hasSpecialChar(password);
  }

  /// Returns a validation error message if the password fails any criteria, or null if valid.
  static String? validate(String? password) {
    if (password == null || password.isEmpty) {
      return 'Enter a password';
    }
    if (!hasMinLength(password)) {
      return 'Password must be at least 8 characters';
    }
    if (!hasUppercase(password)) {
      return 'Include at least one uppercase letter (A-Z)';
    }
    if (!hasLowercase(password)) {
      return 'Include at least one lowercase letter (a-z)';
    }
    if (!hasDigit(password)) {
      return 'Include at least one digit (0-9)';
    }
    if (!hasSpecialChar(password)) {
      return 'Include at least one special character (e.g. @, #, \$, !)';
    }
    return null;
  }

  /// Validates that confirm password matches the password field exactly.
  static String? validateConfirm(String? confirm, String password) {
    if (confirm == null || confirm.isEmpty) {
      return 'Confirm your password';
    }
    if (confirm != password) {
      return 'Passwords do not match';
    }
    return null;
  }

  /// Returns list of unmet requirement labels for field-level feedback while typing.
  static List<String> unmetRequirements(String password) {
    final unmet = <String>[];
    if (!hasMinLength(password)) unmet.add('8+ characters');
    if (!hasUppercase(password)) unmet.add('Uppercase (A–Z)');
    if (!hasLowercase(password)) unmet.add('Lowercase (a–z)');
    if (!hasDigit(password)) unmet.add('Digit (0–9)');
    if (!hasSpecialChar(password)) unmet.add('Special character');
    return unmet;
  }
}
