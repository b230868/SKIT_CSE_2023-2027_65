class AppConstants {
  // Institutional Defaults
  static const String institutionName = 'SKIT Jaipur';
  static const String appName = 'Prashikshan';
  static const String appTagline = 'Internships and ITR, tracked in one place.';

  // Application / Workflow Statuses
  static const String statusPending = 'pending';
  static const String statusApproved = 'approved';
  static const String statusRejected = 'rejected';
  static const String statusActive = 'active';
  static const String statusCompleted = 'completed';
  static const String statusIssued = 'issued';
  static const String statusSubmitted = 'submitted';
  static const String statusAll = 'all';

  // Document Types
  static const Map<String, String> documentTypes = {
    'resume': 'Resume',
    'offer_letter': 'Offer letter',
    'noc': 'NOC',
    'certificate': 'Certificate',
    'other': 'Other',
  };

  // Pagination & Display Defaults
  static const int defaultPageSize = 20;
  static const int recentItemsLimit = 5;
}
