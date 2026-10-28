/// Phone validator enforcing standard National / Telecom valid mobile number formatting.
/// Validates Indian standard mobile numbers (10 digits starting with 6, 7, 8, or 9)
/// while rejecting fake repeated digits (e.g., 0000000000, 9999999999) and sequential patterns (1234567890).
class PhoneValidator {
  // Standard Indian 10-digit mobile number: starts with 6, 7, 8, or 9 followed by 9 digits
  static final RegExp _mobilePattern = RegExp(r'^[6-9]\d{9}$');

  // Known invalid / fake repeated number patterns
  static final List<String> _forbiddenPatterns = [
    '0000000000',
    '1111111111',
    '2222222222',
    '3333333333',
    '4444444444',
    '5555555555',
    '6666666666',
    '7777777777',
    '8888888888',
    '9999999999',
    '1234567890',
    '9876543210',
    '0123456789',
  ];

  /// Validates a phone number.
  /// If [isRequired] is false and input is empty/null, returns null (valid).
  /// Otherwise checks for standard 10-digit mobile number format starting with 6-9,
  /// and ensures it's not a dummy repeated/sequential pattern.
  static String? validate(String? phone, {bool isRequired = false}) {
    if (phone == null || phone.trim().isEmpty) {
      if (isRequired) return 'Enter your mobile number';
      return null;
    }

    // Strip out optional spaces, hyphens, or leading country code (+91 or 0)
    var cleaned = phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }

    if (!RegExp(r'^\d+$').hasMatch(cleaned)) {
      return 'Mobile number must contain digits only';
    }

    if (cleaned.length != 10) {
      return 'Mobile number must be exactly 10 digits';
    }

    if (!_mobilePattern.hasMatch(cleaned)) {
      return 'Enter a valid mobile number starting with 6, 7, 8, or 9';
    }

    // Check for dummy / all identical digits
    final allSame = cleaned.split('').every((char) => char == cleaned[0]);
    if (allSame || _forbiddenPatterns.contains(cleaned)) {
      return 'Enter a valid registered mobile number, not a dummy or sequential combination';
    }

    return null;
  }

  /// Cleans the phone string into a standard 10-digit representation.
  static String format(String phone) {
    var cleaned = phone.trim().replaceAll(RegExp(r'[\s\-\(\)]'), '');
    if (cleaned.startsWith('+91')) {
      cleaned = cleaned.substring(3);
    } else if (cleaned.startsWith('91') && cleaned.length == 12) {
      cleaned = cleaned.substring(2);
    } else if (cleaned.startsWith('0') && cleaned.length == 11) {
      cleaned = cleaned.substring(1);
    }
    return cleaned;
  }
}
