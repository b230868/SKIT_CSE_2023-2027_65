import 'approval_repository_provider.dart';
import 'approval_review_service.dart';

class ApprovalReviewServiceProvider {
  ApprovalReviewServiceProvider._();

  static ApprovalReviewService? _override;

  static void setService(ApprovalReviewService service) {
    _override = service;
  }

  static void reset() {
    _override = null;
  }

  static ApprovalReviewService get instance {
    return _override ??
        ApprovalReviewService(repository: ApprovalRepositoryProvider.instance);
  }
}
