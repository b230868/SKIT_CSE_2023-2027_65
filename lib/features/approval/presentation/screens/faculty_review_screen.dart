import 'package:flutter/material.dart';

import '../../../../core/auth/auth_service.dart';
import '../../data/models/approval_request_model.dart';
import '../../data/services/approval_review_service_provider.dart';
import '../../domain/entities/approval_review_stage.dart';
import '../../domain/entities/approval_status.dart';

class FacultyReviewScreen extends StatefulWidget {
  final ApprovalRequestModel request;

  const FacultyReviewScreen({super.key, required this.request});

  @override
  State<FacultyReviewScreen> createState() => _FacultyReviewScreenState();
}

class _FacultyReviewScreenState extends State<FacultyReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();

  ApprovalStatus _selectedStatus = ApprovalStatus.underReview;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    final remarks = _remarksController.text.trim();

    if (_selectedStatus == ApprovalStatus.rejected && remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter remarks for rejection.')),
      );
      return;
    }

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ApprovalReviewServiceProvider.instance.submitReview(
        internshipId: widget.request.internshipId,
        stage: ApprovalReviewStage.faculty,
        status: _selectedStatus,
        remarks: remarks.isEmpty ? null : remarks,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      final String message;
      if (error is UnauthenticatedException) {
        message = 'Please sign in to submit a review.';
      } else if (error is UnauthorizedException) {
        message = 'You do not have permission to submit faculty reviews.';
      } else {
        message = 'Failed to submit review. Please try again.';
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Theme.of(context).colorScheme.error,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  String _statusLabel(ApprovalStatus status) {
    switch (status) {
      case ApprovalStatus.approved:
        return 'Approved';
      case ApprovalStatus.rejected:
        return 'Rejected';
      case ApprovalStatus.underReview:
        return 'Under Review';
      case ApprovalStatus.pending:
        return 'Pending';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Faculty Review')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              widget.request.studentName,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            Text(widget.request.rollNumber),
            const SizedBox(height: 20),
            Text(
              widget.request.internshipTitle,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(widget.request.industryName),
            const SizedBox(height: 24),
            DropdownButtonFormField<ApprovalStatus>(
              initialValue: _selectedStatus,
              decoration: const InputDecoration(
                labelText: 'Review Status',
                border: OutlineInputBorder(),
              ),
              items: [
                ApprovalStatus.underReview,
                ApprovalStatus.approved,
                ApprovalStatus.rejected,
              ].map((status) {
                return DropdownMenuItem(
                  value: status,
                  child: Text(_statusLabel(status)),
                );
              }).toList(),
              onChanged: _isSubmitting
                  ? null
                  : (status) {
                      if (status == null) return;
                      setState(() {
                        _selectedStatus = status;
                      });
                    },
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _remarksController,
              maxLines: 5,
              enabled: !_isSubmitting,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                hintText: 'Enter review remarks',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  _selectedStatus == ApprovalStatus.rejected &&
                          (value == null || value.trim().isEmpty)
                      ? 'Please enter remarks for rejection.'
                      : null,
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _isSubmitting ? null : _submitReview,
              icon: _isSubmitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.check),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit Faculty Review',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
