/// Comprehensive email validator that detects disposable/fake domains, typos, and invalid formats.
class EmailValidator {
  // Common valid email providers and top-level domain patterns
  static final RegExp _emailFormatRegex = RegExp(
    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
  );

  // Known temporary / disposable / throwaway email domains
  static const Set<String> _disposableDomains = {
    'tempmail.com',
    'temp-mail.org',
    'guerrillamail.com',
    'guerrillamail.net',
    'guerrillamail.org',
    'sharklasers.com',
    'grr.la',
    'pokemail.net',
    '10minutemail.com',
    '10minutemail.net',
    'mailinator.com',
    'dispostable.com',
    'yopmail.com',
    'yopmail.fr',
    'yopmail.net',
    'trashmail.com',
    'trashmail.net',
    'throwawaymail.com',
    'getairmail.com',
    'fakemailgenerator.com',
    'mytemp.email',
    'tempail.com',
    'fakeinbox.com',
    'mohmal.com',
    'crazymailing.com',
    'generator.email',
    'dropmail.me',
    'nada.ltd',
    'inboxkitten.com',
  };

  // Common popular domains and typo suggestions (e.g. gmai.com -> gmail.com)
  static const Map<String, String> _commonDomainTypos = {
    'gmai.com': 'gmail.com',
    'gamil.com': 'gmail.com',
    'gmaill.com': 'gmail.com',
    'gmial.com': 'gmail.com',
    'gmaild.com': 'gmail.com',
    'hotmial.com': 'hotmail.com',
    'hotmai.com': 'hotmail.com',
    'outlok.com': 'outlook.com',
    'yahho.com': 'yahoo.com',
    'yaho.com': 'yahoo.com',
  };

  /// Validates an email address and returns an error message if invalid, or null if valid.
  static String? validate(String? email) {
    if (email == null || email.trim().isEmpty) {
      return 'Enter your email address';
    }

    final trimmed = email.trim().toLowerCase();

    // 1. Strict format check
    if (!_emailFormatRegex.hasMatch(trimmed) ||
        trimmed.contains('..') ||
        trimmed.startsWith('.') ||
        trimmed.endsWith('.')) {
      return 'Enter a valid email address (e.g. name@example.com)';
    }

    final parts = trimmed.split('@');
    if (parts.length != 2) {
      return 'Enter a valid email address';
    }

    final localPart = parts[0];
    final domain = parts[1];

    if (localPart.length < 2) {
      return 'Email address username is too short';
    }

    // 2. Detect common typos (e.g. @gmai.com)
    if (_commonDomainTypos.containsKey(domain)) {
      final suggested = _commonDomainTypos[domain];
      return 'Did you mean @$suggested? Please check the email spelling.';
    }

    // 3. Block temporary / fake disposable domains
    if (_disposableDomains.contains(domain)) {
      return 'Temporary/disposable email addresses are not allowed. Use an active, valid email.';
    }

    // 4. Domain structure checks: must have valid TLD (at least 2 letters, not all digits, no special chars)
    final domainParts = domain.split('.');
    if (domainParts.length < 2) {
      return 'Invalid email domain. Please enter a valid email address.';
    }

    final tld = domainParts.last;
    if (tld.length < 2 || RegExp(r'^\d+$').hasMatch(tld)) {
      return 'Invalid email domain extension. Use a real email address.';
    }

    return null;
  }

  /// Returns true if the email is considered valid.
  static bool isValid(String? email) => validate(email) == null;
}
