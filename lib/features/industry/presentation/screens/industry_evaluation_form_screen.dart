import 'package:flutter/material.dart';

import '../../data/models/industry_evaluation_model.dart';
import '../../data/services/industry_evaluation_service.dart';

class IndustryEvaluationFormScreen extends StatefulWidget {
  final IndustryEvaluationModel evaluation;
  final IndustryEvaluationService? evaluationService;

  const IndustryEvaluationFormScreen({
    super.key,
    required this.evaluation,
    this.evaluationService,
  });

  @override
  State<IndustryEvaluationFormScreen> createState() =>
      _IndustryEvaluationFormScreenState();
}

class _IndustryEvaluationFormScreenState
    extends State<IndustryEvaluationFormScreen> {
  late final IndustryEvaluationService _service;
  late double _techScore;
  late double _qualityScore;
  late double _attendanceScore;
  late double _initiativeScore;
  late double _communicationScore;

  late final TextEditingController _feedbackController;
  late final TextEditingController _remarksController;

  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _service = widget.evaluationService ?? IndustryEvaluationService();

    final ev = widget.evaluation;
    _techScore = ev.technicalSkillsScore;
    _qualityScore = ev.workQualityScore;
    _attendanceScore = ev.attendanceScore;
    _initiativeScore = ev.initiativeScore;
    _communicationScore = ev.communicationScore;

    // If initial scores are all 0, provide sensible defaults for convenient grading
    if (_techScore == 0 &&
        _qualityScore == 0 &&
        _attendanceScore == 0 &&
        _initiativeScore == 0 &&
        _communicationScore == 0 &&
        ev.totalScore > 0) {
      final perCategory = (ev.totalScore / 5).clamp(0.0, 20.0);
      _techScore = perCategory;
      _qualityScore = perCategory;
      _attendanceScore = perCategory;
      _initiativeScore = perCategory;
      _communicationScore = perCategory;
    }

    _feedbackController = TextEditingController(text: ev.feedback ?? '');
    _remarksController = TextEditingController(text: ev.remarks ?? '');
  }

  @override
  void dispose() {
    _feedbackController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  double get _totalScore =>
      _techScore +
      _qualityScore +
      _attendanceScore +
      _initiativeScore +
      _communicationScore;

  String get _calculatedGrade =>
      IndustryEvaluationModel.calculateGrade(_totalScore);

  Future<void> _submitEvaluation({required bool verify}) async {
    setState(() => _submitting = true);
    final status = verify ? 'verified' : 'in_progress';

    try {
      await _service.saveEvaluation(
        internshipId: widget.evaluation.internshipId,
        studentId: widget.evaluation.studentId,
        studentName: widget.evaluation.studentName,
        internshipTitle: widget.evaluation.internshipTitle,
        companyName: widget.evaluation.companyName,
        evaluationId: widget.evaluation.id.isNotEmpty
            ? widget.evaluation.id
            : null,
        industryId: widget.evaluation.industryId,
        technicalSkillsScore: _techScore,
        workQualityScore: _qualityScore,
        attendanceScore: _attendanceScore,
        initiativeScore: _initiativeScore,
        communicationScore: _communicationScore,
        status: status,
        feedback: _feedbackController.text.trim(),
        remarks: _remarksController.text.trim(),
      );

      if (verify) {
        await _service.verifyInternship(
          internshipId: widget.evaluation.internshipId,
          remarks: _remarksController.text.trim().isNotEmpty
              ? _remarksController.text.trim()
              : 'Verified by industry supervisor',
          evaluationId: widget.evaluation.id.isNotEmpty
              ? widget.evaluation.id
              : null,
        );
      }

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            verify
                ? 'Evaluation submitted and internship verified!'
                : 'Evaluation draft saved successfully.',
          ),
          backgroundColor: Colors.green,
        ),
      );

      if (mounted) {
        setState(() => _submitting = false);
      }

      if (Navigator.canPop(context)) {
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to save evaluation: $e'),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Widget _buildCriterionSlider({
    required String title,
    required String description,
    required double value,
    required ValueChanged<double> onChanged,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 15,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primaryContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${value.toStringAsFixed(1)} / 20',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
            ),
            Slider(
              value: value,
              min: 0,
              max: 20,
              divisions: 40,
              label: value.toStringAsFixed(1),
              onChanged: onChanged,
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ev = widget.evaluation;

    return Scaffold(
      appBar: AppBar(title: const Text('Intern Evaluation & Verification')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Student & Internship Header Card
          Card(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        child: Text(
                          ev.studentName.isNotEmpty
                              ? ev.studentName[0].toUpperCase()
                              : 'S',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ev.studentName,
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              ev.internshipTitle,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Total Score & Grade Display Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      const Text(
                        'Total Score',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        '${_totalScore.toStringAsFixed(1)} / 100',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ],
                  ),
                  Container(height: 50, width: 1, color: Colors.grey.shade300),
                  Column(
                    children: [
                      const Text(
                        'Grade',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _calculatedGrade,
                        style: const TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w800,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          const Text(
            'Evaluation Criteria',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 10),

          _buildCriterionSlider(
            title: '1. Technical Competence',
            description: 'Understanding and application of required technical stack and tools.',
            value: _techScore,
            onChanged: (val) => setState(() => _techScore = val),
          ),

          _buildCriterionSlider(
            title: '2. Quality of Deliverables',
            description: 'Accuracy, reliability, and code/document quality in tasks completed.',
            value: _qualityScore,
            onChanged: (val) => setState(() => _qualityScore = val),
          ),

          _buildCriterionSlider(
            title: '3. Attendance & Punctuality',
            description: 'Regularity in check-ins, meetings, and adherence to working hours.',
            value: _attendanceScore,
            onChanged: (val) => setState(() => _attendanceScore = val),
          ),

          _buildCriterionSlider(
            title: '4. Problem Solving & Initiative',
            description: 'Self-learning, troubleshooting capacity, and proactive ownership.',
            value: _initiativeScore,
            onChanged: (val) => setState(() => _initiativeScore = val),
          ),

          _buildCriterionSlider(
            title: '5. Teamwork & Communication',
            description: 'Clarity in daily reports, team collaboration, and mentor interactions.',
            value: _communicationScore,
            onChanged: (val) => setState(() => _communicationScore = val),
          ),

          const SizedBox(height: 14),

          // Qualitative Feedback
          TextField(
            controller: _feedbackController,
            maxLines: 3,
            decoration: const InputDecoration(
              labelText: 'Performance Feedback (Strengths & Improvements)',
              hintText: 'Share constructive observations regarding intern performance...',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 14),

          // Formal Verification Remarks
          TextField(
            controller: _remarksController,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Supervisory / Verification Remarks',
              hintText: 'Official remarks for university evaluation records...',
              border: OutlineInputBorder(),
            ),
          ),

          const SizedBox(height: 24),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _submitting
                      ? null
                      : () => _submitEvaluation(verify: false),
                  icon: const Icon(Icons.save_outlined),
                  label: const Text('Save Draft'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _submitting
                      ? null
                      : () => _submitEvaluation(verify: true),
                  icon: _submitting
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.verified),
                  label: const Text('Verify & Submit'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 30),
        ],
      ),
    );
  }
}
