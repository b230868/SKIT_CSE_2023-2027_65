import 'package:flutter/material.dart';
<<<<<<< HEAD

import '../../../../core/auth/auth_service.dart';
import '../../data/models/approval_request_model.dart';
import '../../data/services/approval_review_service_provider.dart';
=======
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/approval_request_model.dart';
import '../../data/services/approval_repository_provider.dart';
>>>>>>> origin/main
import '../../domain/entities/approval_review_stage.dart';
import '../../domain/entities/approval_status.dart';

class TpReviewScreen extends StatefulWidget {
  final ApprovalRequestModel request;

  const TpReviewScreen({super.key, required this.request});

  @override
  State<TpReviewScreen> createState() => _TpReviewScreenState();
}

class _TpReviewScreenState extends State<TpReviewScreen> {
<<<<<<< HEAD
  final _remarksController = TextEditingController();

  ApprovalStatus _selectedStatus = ApprovalStatus.approved;

  bool _isSubmitting = false;

  @override
  void dispose() {
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _submitReview() async {
    final remarks = _remarksController.text.trim();

    if (_selectedStatus == ApprovalStatus.rejected && remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter rejection remarks.')),
=======
  final _formKey = GlobalKey<FormState>();
  final _remarks = TextEditingController();
  ApprovalStatus _status = ApprovalStatus.approved;
  bool _saving = false;

  @override
  void dispose() {
    _remarks.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please sign in before submitting a decision.')),
>>>>>>> origin/main
      );
      return;
    }

<<<<<<< HEAD
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
=======
    setState(() => _saving = true);
    try {
      await ApprovalRepositoryProvider.instance.createReview(
        internshipId: widget.request.internshipId,
        reviewerId: userId,
        stage: ApprovalReviewStage.tpAdmin,
        status: _status,
        remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit T&P decision: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
>>>>>>> origin/main
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('T&P Review')),
<<<<<<< HEAD
      body: ListView(
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
          TextField(
            controller: _remarksController,
            maxLines: 5,
            enabled: !_isSubmitting,
            decoration: const InputDecoration(
              labelText: 'Remarks',
              hintText: 'Enter T&P remarks',
              border: OutlineInputBorder(),
            ),
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
=======
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(widget.request.internshipTitle),
            const SizedBox(height: 20),
            DropdownButtonFormField<ApprovalStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Decision'),
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
              onChanged: _saving
                  ? null
                  : (status) {
                      if (status != null) setState(() => _status = status);
                    },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _remarks,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Remarks',
                alignLabelWithHint: true,
              ),
              validator: (value) =>
                  _status == ApprovalStatus.rejected &&
                          (value == null || value.trim().isEmpty)
                      ? 'Please enter rejection remarks.'
                      : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(
                _saving ? 'Submitting...' : 'Submit T&P Decision',
              ),
            ),
          ],
        ),
>>>>>>> origin/main
      ),
    );
  }
}
