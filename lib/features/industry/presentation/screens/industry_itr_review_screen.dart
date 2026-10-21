import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:prashikshan/features/industry/data/models/evaluation_model.dart';
import 'package:prashikshan/features/itr/data/models/itr_model.dart';
import 'package:prashikshan/features/itr/data/services/itr_service.dart';

class IndustryItrReviewScreen extends StatefulWidget {
  final ItrModel itr;
  final ItrService? itrService;

  const IndustryItrReviewScreen({
    super.key,
    required this.itr,
    this.itrService,
  });

  @override
  State<IndustryItrReviewScreen> createState() =>
      _IndustryItrReviewScreenState();
}

class _IndustryItrReviewScreenState extends State<IndustryItrReviewScreen> {
  late final ItrService _itrService;
  late final TextEditingController _remarksController;
  late final TextEditingController _reviewerNameController;

  bool _submitting = false;
  late ItrModel _currentItr;

  // Evaluation criteria scores (each out of 25, total out of 100)
  double _technicalScore = 20.0;
  double _workQualityScore = 20.0;
  double _punctualityScore = 20.0;
  double _presentationScore = 20.0;

  String _certificateStatus = 'pending';

  @override
  void initState() {
    super.initState();
    _itrService = widget.itrService ?? ItrService();
    _currentItr = widget.itr;
    _remarksController = TextEditingController(text: widget.itr.remarks ?? '');
    _reviewerNameController = TextEditingController(
      text: widget.itr.reviewerName ?? 'Industry Supervisor',
    );
    _certificateStatus = widget.itr.certificateStatus ?? 'pending';

    _loadExistingEvaluation();
  }

  Future<void> _loadExistingEvaluation() async {
    try {
      final existing = await _itrService.getEvaluationByItrId(widget.itr.id);
      if (existing != null && mounted) {
        setState(() {
          _technicalScore = existing.technicalScore;
          _workQualityScore = existing.workQualityScore;
          _punctualityScore = existing.punctualityScore;
          _presentationScore = existing.presentationScore;
          _certificateStatus = existing.certificateStatus;
          if (existing.remarks.isNotEmpty && _remarksController.text.isEmpty) {
            _remarksController.text = existing.remarks;
          }
        });
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _remarksController.dispose();
    _reviewerNameController.dispose();
    super.dispose();
  }

  double get _totalScore =>
      (_technicalScore +
              _workQualityScore +
              _punctualityScore +
              _presentationScore)
          .clamp(0.0, 100.0);

  String get _calculatedGrade {
    final score = _totalScore;
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    if (score >= 50) return 'D';
    return 'F';
  }

  String _formatStatus(String status) {
    return status.replaceAll('_', ' ').toUpperCase();
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'submitted':
        return Colors.blue;
      case 'under_review':
        return Colors.orange;
      case 'approved':
      case 'verified':
        return Colors.green;
      case 'changes_requested':
        return Colors.deepOrange;
      case 'rejected':
        return Colors.red;
      case 'draft':
        return Colors.grey;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime? date) {
    if (date == null) return 'Not submitted yet';
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  Future<void> _handleFileAction(String? filePath, String fileLabel) async {
    if (filePath == null || filePath.trim().isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('No $fileLabel was uploaded.')));
      return;
    }

    try {
      final url = await _itrService.getFileUrl(filePath);
      if (!mounted) return;

      if (url == null || url.trim().isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unable to generate download URL for $fileLabel.'),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('$fileLabel Download Link'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Storage Path:\n$filePath',
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 12),
              const Text('Secure signed URL generated (valid for 1 hour):'),
              const SizedBox(height: 8),
              SelectableText(
                url,
                style: const TextStyle(fontSize: 12, color: Colors.blue),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Close'),
            ),
            FilledButton.icon(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('URL copied to clipboard!')),
                );
              },
              icon: const Icon(Icons.copy, size: 16),
              label: const Text('Copy Link'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error accessing file: $e')));
    }
  }

  Future<void> _submitReview(String newStatus) async {
    final remarks = _remarksController.text.trim();
    final reviewerName = _reviewerNameController.text.trim();

    if ((newStatus == 'rejected' || newStatus == 'changes_requested') &&
        remarks.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please provide remarks explaining why changes are requested or rejected.',
          ),
        ),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      // 1. Submit review status & remarks
      await _itrService.reviewItr(
        itrId: _currentItr.id,
        status: newStatus,
        remarks: remarks,
        reviewerName: reviewerName.isNotEmpty ? reviewerName : null,
      );

      // 2. Persist formal evaluation rubrics & certificate verification
      final evaluation = EvaluationModel(
        id: 'eval-${_currentItr.id}',
        itrId: _currentItr.id,
        internshipId: _currentItr.internshipId,
        studentId: _currentItr.studentId,
        evaluatorId: '',
        evaluatorName: reviewerName.isNotEmpty
            ? reviewerName
            : 'Industry Supervisor',
        technicalScore: _technicalScore,
        workQualityScore: _workQualityScore,
        punctualityScore: _punctualityScore,
        presentationScore: _presentationScore,
        remarks: remarks,
        certificateStatus: _certificateStatus,
        certificateVerifiedAt: _certificateStatus == 'verified'
            ? DateTime.now()
            : null,
        evaluatedAt: DateTime.now(),
      );

      await _itrService.saveEvaluation(evaluation);

      if (!mounted) return;

      setState(() {
        _currentItr = _currentItr.copyWith(
          status: newStatus,
          remarks: remarks,
          reviewerName: reviewerName,
          evaluationScore: _totalScore,
          evaluationGrade: _calculatedGrade,
          certificateStatus: _certificateStatus,
        );
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'ITR evaluation saved: ${_formatStatus(newStatus)} (Grade: $_calculatedGrade)',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Unable to update review: $e')));
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
    }
  }

  Widget _infoCard({
    required IconData icon,
    required String title,
    required String? value,
  }) {
    final displayValue = value == null || value.trim().isEmpty
        ? 'Not specified'
        : value;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: const Color(0xFF14213D)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(displayValue, style: const TextStyle(fontSize: 14)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCriterionSlider({
    required String label,
    required String description,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: const Color(0xFF14213D).withAlpha(20),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${value.toInt()} / 25',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
        Text(
          description,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        Slider(
          value: value,
          min: 0,
          max: 25,
          divisions: 25,
          label: '${value.toInt()}',
          onChanged: onChanged,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Review Student ITR')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Student & Internship Header Card
            Card(
              color: const Color(0xFF14213D),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: const Color(0xFFE09F1F),
                          child: Text(
                            _currentItr.studentName.isNotEmpty
                                ? _currentItr.studentName[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _currentItr.studentName,
                                style: const TextStyle(
                                  fontSize: 19,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _currentItr.internshipTitle,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.white70,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Chip(
                          label: Text(
                            _formatStatus(_currentItr.status),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          backgroundColor: _getStatusColor(_currentItr.status),
                        ),
                      ],
                    ),
                    const Divider(color: Colors.white24, height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Company: ${_currentItr.companyName}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          'Submitted: ${_formatDate(_currentItr.submittedAt)}',
                          style: const TextStyle(
                            color: Colors.white70,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Attached Deliverables Section
            const Text(
              'Attached Deliverables',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  children: [
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x1A14213D),
                        child: Icon(Icons.folder_zip, color: Color(0xFF14213D)),
                      ),
                      title: const Text('Project Source Code (ZIP)'),
                      subtitle: Text(
                        _currentItr.projectZipPath ?? 'No ZIP file attached',
                      ),
                      trailing: _currentItr.projectZipPath != null
                          ? IconButton(
                              icon: const Icon(Icons.download),
                              tooltip: 'Get Download Link',
                              onPressed: () => _handleFileAction(
                                _currentItr.projectZipPath,
                                'Project ZIP',
                              ),
                            )
                          : null,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const CircleAvatar(
                        backgroundColor: Color(0x1AE09F1F),
                        child: Icon(Icons.slideshow, color: Color(0xFFE09F1F)),
                      ),
                      title: const Text('Project Presentation (PPT)'),
                      subtitle: Text(
                        _currentItr.presentationPath ??
                            'No presentation attached',
                      ),
                      trailing: _currentItr.presentationPath != null
                          ? IconButton(
                              icon: const Icon(Icons.download),
                              tooltip: 'Get Download Link',
                              onPressed: () => _handleFileAction(
                                _currentItr.presentationPath,
                                'Presentation',
                              ),
                            )
                          : null,
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Student ITR Work Details
            const Text(
              'Student Submission Content',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            _infoCard(
              icon: Icons.article_outlined,
              title: 'Work Summary',
              value: _currentItr.content,
            ),
            if (_currentItr.workDone != null &&
                _currentItr.workDone!.isNotEmpty)
              _infoCard(
                icon: Icons.assignment_turned_in_outlined,
                title: 'Work Completed',
                value: _currentItr.workDone,
              ),
            _infoCard(
              icon: Icons.code,
              title: 'Technologies & Tools Used',
              value: _currentItr.technologiesUsed,
            ),
            _infoCard(
              icon: Icons.school,
              title: 'Key Learnings',
              value: _currentItr.keyLearnings,
            ),
            _infoCard(
              icon: Icons.psychology,
              title: 'Challenges Faced & Solutions',
              value: _currentItr.challengesFaced,
            ),

            const SizedBox(height: 24),

            // User Story 3: Evaluation Criteria Rubric
            const Text(
              'Mentor Evaluation Rubric (100 Marks)',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Live Total Marks Header
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF14213D).withAlpha(15),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Total Evaluation Score',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                              ),
                              Text(
                                '${_totalScore.toInt()} / 100',
                                style: const TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF14213D),
                                ),
                              ),
                            ],
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFFE09F1F),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              'Grade $_calculatedGrade',
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.black,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 20),

                    _buildCriterionSlider(
                      label: '1. Technical Competency (25)',
                      description: 'Domain mastery, engineering quality, architectural reasoning',
                      value: _technicalScore,
                      onChanged: (v) => setState(() => _technicalScore = v),
                    ),

                    const SizedBox(height: 10),

                    _buildCriterionSlider(
                      label: '2. Work Quality & Deliverables (25)',
                      description: 'Adherence to specifications, completeness, bug-free delivery',
                      value: _workQualityScore,
                      onChanged: (v) => setState(() => _workQualityScore = v),
                    ),

                    const SizedBox(height: 10),

                    _buildCriterionSlider(
                      label: '3. Punctuality & Communication (25)',
                      description: 'Timeliness, attendance, team collaboration, progress logging',
                      value: _punctualityScore,
                      onChanged: (v) => setState(() => _punctualityScore = v),
                    ),

                    const SizedBox(height: 10),

                    _buildCriterionSlider(
                      label: '4. Project Viva & Presentation (25)',
                      description: 'Viva answers, presentation deck clarity, defense of project',
                      value: _presentationScore,
                      onChanged: (v) => setState(() => _presentationScore = v),
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 20),

            // Certificate Verification Section
            const Text(
              'Certificate Verification',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const Icon(Icons.verified, color: Colors.teal),
                    const SizedBox(width: 14),
                    const Expanded(
                      child: Text(
                        'Certificate Status:',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    DropdownButton<String>(
                      value: _certificateStatus,
                      underline: const SizedBox(),
                      items: const [
                        DropdownMenuItem(
                          value: 'pending',
                          child: Text('Pending Audit'),
                        ),
                        DropdownMenuItem(
                          value: 'verified',
                          child: Text('Verified & Signed'),
                        ),
                        DropdownMenuItem(
                          value: 'rejected',
                          child: Text('Rejected / Incomplete'),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _certificateStatus = v);
                        }
                      },
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Supervisor Review Remarks & Submit Decision
            const Text(
              'Supervisor Decision & Remarks',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 10),

            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    TextField(
                      controller: _reviewerNameController,
                      decoration: const InputDecoration(
                        labelText: 'Supervisor / Mentor Name',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      controller: _remarksController,
                      maxLines: 4,
                      decoration: const InputDecoration(
                        labelText: 'Review Remarks & Feedback',
                        hintText: 'Enter your evaluation remarks, feedback, or requested changes...',
                        border: OutlineInputBorder(),
                        alignLabelWithHint: true,
                      ),
                    ),
                    const SizedBox(height: 20),
                    if (_submitting)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(),
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          InkWell(
                            onTap: () => _submitReview('approved'),
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 2),
                              child: Text(
                                'Approve ITR',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.transparent,
                                ),
                              ),
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: Colors.green.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.check_circle),
                            label: Text(
                              'Approve & Evaluate (${_totalScore.toInt()}/100 - Grade $_calculatedGrade)',
                            ),
                            onPressed: () => _submitReview('approved'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            style: OutlinedButton.styleFrom(
                              foregroundColor: Colors.deepOrange.shade800,
                              side: BorderSide(
                                color: Colors.deepOrange.shade600,
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.edit_note),
                            label: const Text('Request Changes / Resubmission'),
                            onPressed: () => _submitReview('changes_requested'),
                          ),
                          const SizedBox(height: 8),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.red.shade700,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                            icon: const Icon(Icons.cancel),
                            label: const Text('Reject ITR'),
                            onPressed: () => _submitReview('rejected'),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 30),
          ],
        ),
      ),
    );
  }
}
