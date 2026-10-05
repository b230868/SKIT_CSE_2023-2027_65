import 'package:flutter/material.dart';

import '../../data/models/approval_request_model.dart';
import '../../data/models/approval_review_model.dart';
import '../../data/repositories/approval_repository.dart';
import '../../data/services/approval_repository_provider.dart';
import '../../domain/entities/approval_review_stage.dart';
import '../../domain/entities/approval_status.dart';
import 'faculty_review_screen.dart';
import 'tp_review_screen.dart';

class ApprovalDetailsScreen extends StatefulWidget {
  final ApprovalRequestModel request;
  final ApprovalReviewStage stage;

  const ApprovalDetailsScreen({
    super.key,
    required this.request,
    required this.stage,
  });

  @override
  State<ApprovalDetailsScreen> createState() =>
      _ApprovalDetailsScreenState();
}

class _ApprovalDetailsScreenState
    extends State<ApprovalDetailsScreen> {
  final ApprovalRepository _repository =
      ApprovalRepositoryProvider.instance;

  List<ApprovalReviewModel> _reviews = [];
  bool _isLoadingReviews = true;

  String? _reviewError;

  @override
  void initState() {
    super.initState();
    _loadReviews();
  }

  Future<void> _loadReviews() async {
    try {
      final reviews = await _repository.getReviews();

      if (!mounted) return;

      setState(() {
        _reviews = reviews
            .where(
              (review) =>
                  review.internshipId ==
                  widget.request.internshipId,
            )
            .toList();
        _reviewError = null;
        _isLoadingReviews = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _reviewError = 'Unable to load previous reviews.';
        _isLoadingReviews = false;
      });
    }
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(value),
        ],
      ),
    );
  }

  String _statusLabel(ApprovalStatus status) {
    switch (status) {
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

  String _stageLabel() {
    switch (widget.stage) {
      case ApprovalReviewStage.faculty:
        return 'Faculty';
      case ApprovalReviewStage.tpAdmin:
        return 'T&P';
    }
  }

  String _formatDate(DateTime date) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  bool get _canReview {
    if (widget.stage == ApprovalReviewStage.faculty) {
      return widget.request.approvalStatus ==
              ApprovalStatus.pending ||
          widget.request.approvalStatus ==
              ApprovalStatus.underReview;
    }

    return widget.stage == ApprovalReviewStage.tpAdmin &&
        widget.request.approvalStatus ==
            ApprovalStatus.approved;
  }

  Future<void> _openReview(BuildContext context) async {
    final bool? updated;

    if (widget.stage == ApprovalReviewStage.faculty) {
      updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => FacultyReviewScreen(
            request: widget.request,
          ),
        ),
      );
    } else {
      updated = await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TpReviewScreen(
            request: widget.request,
          ),
        ),
      );
    }

    if (!context.mounted || updated != true) return;

    Navigator.pop(context, true);
  }

  Widget _reviewHistory() {
    if (_isLoadingReviews) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: CircularProgressIndicator(),
        ),
      );
    }

    final error = _reviewError;
    if (error != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            error,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: () {
              setState(() {
                _isLoadingReviews = true;
                _reviewError = null;
              });
              _loadReviews();
            },
            child: const Text('Retry'),
          ),
        ],
      );
    }

    final reviews = [..._reviews]
      ..sort(
        (a, b) => b.createdAt.compareTo(a.createdAt),
      );

    if (reviews.isEmpty) {
      return const Text(
        'No previous reviews found.',
      );
    }

    return Column(
      children: reviews.map((review) {
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(
              '${review.reviewStage == 'faculty' ? 'Faculty' : 'T&P'} - '
              '${_statusLabel(review.status)}',
            ),
            subtitle: Text(
              '${review.remarks ?? 'No remarks'}\n'
              '${_formatDate(review.createdAt)}',
            ),
            isThreeLine: true,
          ),
        );
      }).toList(),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval Details'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(
            '${_stageLabel()} Approval',
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 20),

          const Text(
            'Student Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _detailRow(
            'Student Name',
            widget.request.studentName,
          ),
          _detailRow(
            'Roll Number',
            widget.request.rollNumber,
          ),

          const SizedBox(height: 10),

          const Text(
            'Internship Information',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _detailRow(
            'Internship Title',
            widget.request.internshipTitle,
          ),
          _detailRow(
            'Industry',
            widget.request.industryName,
          ),
          _detailRow(
            'Internship Status',
            widget.request.internshipStatus,
          ),
          _detailRow(
            'Approval Status',
            _statusLabel(
              widget.request.approvalStatus,
            ),
          ),
          _detailRow(
            'Internship ID',
            widget.request.internshipId,
          ),

          const SizedBox(height: 20),

          const Text(
            'Previous Reviews',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _reviewHistory(),

          if (_canReview) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => _openReview(context),
              icon: Icon(
                widget.stage == ApprovalReviewStage.faculty
                    ? Icons.rate_review
                    : Icons.verified,
              ),
              label: Text(
                widget.stage == ApprovalReviewStage.faculty
                    ? 'Open Faculty Review'
                    : 'Open T&P Review',
              ),
            ),
          ],
        ],
      ),
    );
  }
}