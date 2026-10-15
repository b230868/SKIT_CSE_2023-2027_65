enum ApprovalStatus {
  pending,
  underReview,
  approved,
  rejected,
}

extension ApprovalStatusExtension on ApprovalStatus {
  String get value {
    switch (this) {
      case ApprovalStatus.pending:
        return 'pending';
      case ApprovalStatus.underReview:
        return 'under_review';
      case ApprovalStatus.approved:
        return 'approved';
      case ApprovalStatus.rejected:
        return 'rejected';
    }
  }

  String get displayName {
    switch (this) {
      case ApprovalStatus.pending:
        return 'Pending';
      case ApprovalStatus.underReview:
        return 'Under Review';
      case ApprovalStatus.approved:
        return 'Approved';
      case ApprovalStatus.rejected:
        return 'Rejected';
    }
  }
}