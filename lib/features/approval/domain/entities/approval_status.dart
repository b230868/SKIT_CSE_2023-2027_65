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
}