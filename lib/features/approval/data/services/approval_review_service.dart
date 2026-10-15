import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../models/approval_review_model.dart';
import '../repositories/approval_repository.dart';
import '../repositories/mock_approval_repository.dart';
import '../../domain/entities/approval_review_stage.dart';
import '../../domain/entities/approval_status.dart';

class ApprovalReviewService {
  final ApprovalRepository repository;
  final SupabaseClient? _providedClient;

  ApprovalReviewService({required this.repository, SupabaseClient? client})
    : _providedClient = client;

  SupabaseClient? get client {
    if (_providedClient != null) return _providedClient;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<ApprovalReviewModel> submitReview({
    required String internshipId,
    required ApprovalReviewStage stage,
    required ApprovalStatus status,
    String? remarks,
  }) async {
    if (status == ApprovalStatus.rejected &&
        (remarks == null || remarks.trim().isEmpty)) {
      throw ArgumentError(
        'Remarks are required when rejecting an application.',
      );
    }

    if (repository is MockApprovalRepository &&
        client?.auth.currentUser == null) {
      return repository.createReview(
        internshipId: internshipId,
        reviewerId: 'mock-reviewer',
        stage: stage,
        status: status,
        remarks: remarks,
      );
    }

    final authenticatedClient = await AuthService.requireAuthenticatedClient(
      client: client,
    );
    final user = authenticatedClient.auth.currentUser;
    if (user == null) {
      throw const UnauthenticatedException('Please sign in to submit reviews.');
    }

    return repository.createReview(
      internshipId: internshipId,
      reviewerId: user.id,
      stage: stage,
      status: status,
      remarks: remarks,
    );
  }
}
