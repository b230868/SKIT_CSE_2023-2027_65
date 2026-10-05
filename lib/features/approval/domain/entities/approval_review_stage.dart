enum ApprovalReviewStage {
  faculty,
  tpAdmin,
}

extension ApprovalReviewStageExtension on ApprovalReviewStage {
  String get value {
    switch (this) {
      case ApprovalReviewStage.faculty:
        return 'faculty';
      case ApprovalReviewStage.tpAdmin:
        return 'tp_admin';
    }
  }
}