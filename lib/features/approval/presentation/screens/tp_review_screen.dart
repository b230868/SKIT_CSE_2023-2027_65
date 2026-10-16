import 'package:flutter/material.dart';

import '../../../../core/auth/auth_service.dart';
import '../../data/models/approval_request_model.dart';
import '../../data/services/approval_review_service_provider.dart';
import '../../domain/entities/approval_review_stage.dart';
import '../../domain/entities/approval_status.dart';

class TpReviewScreen extends StatefulWidget {
  final ApprovalRequestModel request;

  const TpReviewScreen({super.key, required this.request});

  @override
  State<TpReviewScreen> createState() => _TpReviewScreenState();
}

class _TpReviewScreenState extends State<TpReviewScreen> {
  final _formKey = GlobalKey<FormState>();
  final _remarksController = TextEditingController();

  ApprovalStatus _selectedStatus = ApprovalStatus.approved;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    if (!_formKey.currentState!.validate()) return;

    final remarks = _remarksController.text.trim();

    setState(() {
      _isSubmitting = true;
    });

    try {
      await ApprovalReviewServiceProvider.instance.submitReview(
        internshipId: widget.request.internshipId,
        stage: ApprovalReviewStage.tpAdmin,
        status: _selectedStatus,
        remarks: remarks.isEmpty ? null : remarks,
      );

      if (!mounted) return;

      Navigator.pop(context, true);
    } catch (error) {
      if (!mounted) return;

      final String message;
      if (error is UnauthenticatedException) {
        message = 'Please sign in to submit reviews.';
      } else if (error is UnauthorizedException) {
        message = 'Your account does not have permission to submit reviews.';
      } else {
        message = 'Unable to submit T&P decision: $error';
      }

      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));

      setState(() {
        _isSubmitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('T&P Review')),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            const Text(
              'Faculty Approved Application',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 20),
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
                labelText: 'T&P Decision',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: ApprovalStatus.approved,
                  child: Text('Approved'),
                ),
                DropdownMenuItem(
                  value: ApprovalStatus.rejected,
                  child: Text('Rejected'),
                ),
              ],
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
                hintText: 'Enter T&P remarks',
                border: OutlineInputBorder(),
              ),
              validator: (value) =>
                  _selectedStatus == ApprovalStatus.rejected &&
                      (value == null || value.trim().isEmpty)
                  ? 'Please enter rejection remarks.'
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
                  : const Icon(Icons.check_circle),
              label: Text(
                _isSubmitting ? 'Submitting...' : 'Submit T&P Decision',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
