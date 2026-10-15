import '../../domain/entities/approval_status.dart';

class ApprovalActionModel {
  final ApprovalStatus status;
  final String remarks;

  const ApprovalActionModel({required this.status, required this.remarks});
}
