import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../data/models/approval_request_model.dart';
import '../../data/services/approval_repository_provider.dart';
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
  final _remarks = TextEditingController();
  ApprovalStatus _status = ApprovalStatus.underReview;
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
        const SnackBar(content: Text('Please sign in before submitting a review.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ApprovalRepositoryProvider.instance.createReview(
        internshipId: widget.request.internshipId,
        reviewerId: userId,
        stage: ApprovalReviewStage.faculty,
        status: _status,
        remarks: _remarks.text.trim().isEmpty ? null : _remarks.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not submit faculty review: $error')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
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
            Text(widget.request.internshipTitle),
            const SizedBox(height: 20),
            DropdownButtonFormField<ApprovalStatus>(
              initialValue: _status,
              decoration: const InputDecoration(labelText: 'Decision'),
              items: const [
                DropdownMenuItem(
                  value: ApprovalStatus.underReview,
                  child: Text('Under Review'),
                ),
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
                      ? 'Please enter remarks for rejection.'
                      : null,
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: Text(
                _saving ? 'Submitting...' : 'Submit Faculty Review',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
