import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../internship/models/internship.dart';
import '../../data/models/industry_attendance_model.dart';
import '../../data/models/industry_evaluation_model.dart';
import '../../data/models/industry_internship_model.dart';
import '../../data/services/industry_evaluation_service.dart';
import '../../data/services/industry_service.dart';
import '../../../geo_progress/models/geo_progress_log.dart';
import '../../../geo_progress/services/geo_progress_service.dart';
import 'industry_evaluation_form_screen.dart';

class IndustryInternshipDetailsScreen extends StatefulWidget {
  final IndustryInternshipModel internship;
  final IndustryService? industryService;
  final IndustryEvaluationService? evaluationService;

  const IndustryInternshipDetailsScreen({
    super.key,
    required this.internship,
    this.industryService,
    this.evaluationService,
  });

  @override
  State<IndustryInternshipDetailsScreen> createState() =>
      _IndustryInternshipDetailsScreenState();
}

class _IndustryInternshipDetailsScreenState
    extends State<IndustryInternshipDetailsScreen> {
  late final IndustryService _industryService;
  late final IndustryEvaluationService _evaluationService;
  late IndustryInternshipModel _internship;

  bool _loading = true;
  String? _loadError;
  IndustryEvaluationModel? _evaluation;
  List<IndustryAttendanceRecord> _attendanceRecords = [];
  List<InternshipDocument> _studentDocuments = [];
  List<GeoProgressLog> _geoProgressLogs = [];

  @override
  void initState() {
    super.initState();
    _internship = widget.internship;
    _industryService = widget.industryService ?? IndustryService();
    _evaluationService =
        widget.evaluationService ?? IndustryEvaluationService();
    _fetchDetails();
  }

  Future<void> _fetchDetails() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });

    try {
      final results = await Future.wait([
        _evaluationService.getEvaluationByInternshipId(_internship.id),
        _industryService.getAttendanceRecords(_internship.id),
        _industryService.getStudentDocuments(_internship.id),
        GeoProgressService().fetchHistory(_internship.id).catchError((_) => <GeoProgressLog>[]),
      ]);

      if (!mounted) return;
      setState(() {
        _evaluation = results[0] as IndustryEvaluationModel?;
        _attendanceRecords = results[1] as List<IndustryAttendanceRecord>;
        _studentDocuments = results[2] as List<InternshipDocument>;
        _geoProgressLogs = results[3] as List<GeoProgressLog>;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _loading = false;
      });
    }
  }

  String _formatStatus(String value) {
    return value.replaceAll('_', ' ').toUpperCase();
  }

  String _formatDate(DateTime? dt) {
    if (dt == null) return 'Not set';
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'approved':
      case 'verified':
      case 'issued':
        return Colors.green;
      case 'completed':
        return Colors.blue;
      case 'under_review':
      case 'in_progress':
        return Colors.orange;
      case 'rejected':
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  Future<void> _handleIssueOfferLetter() async {
    final urlController = TextEditingController(
      text:
          _internship.offerLetterUrl ??
          'https://storage.prashikshan.edu/offer_letters/${_internship.id}.pdf',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Issue Offer Letter'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Issue company offer letter for ${_internship.studentName}:'),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Document / File URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Issue Offer Letter'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _industryService.issueOfferLetter(
          internshipId: _internship.id,
          fileUrl: urlController.text.trim(),
        );
        setState(() {
          _internship = _internship.copyWith(
            offerLetterStatus: 'issued',
            offerLetterUrl: urlController.text.trim(),
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Offer letter issued successfully.'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to issue offer letter: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleVerifyOfferLetter() async {
    try {
      await _industryService.verifyOfferLetter(internshipId: _internship.id);
      setState(() {
        _internship = _internship.copyWith(offerLetterStatus: 'verified');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Offer letter verified.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to verify offer letter: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _handleIssueCertificate() async {
    final urlController = TextEditingController(
      text:
          _internship.certificateUrl ??
          'https://storage.prashikshan.edu/certificates/${_internship.id}.pdf',
    );
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Issue Completion Certificate'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Issue internship completion certificate for ${_internship.studentName}:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                labelText: 'Certificate Document URL',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Issue Certificate'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _industryService.issueCertificate(
          internshipId: _internship.id,
          fileUrl: urlController.text.trim(),
        );
        setState(() {
          _internship = _internship.copyWith(
            certificateStatus: 'issued',
            certificateUrl: urlController.text.trim(),
          );
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Completion certificate issued successfully.'),
              backgroundColor: Colors.teal,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to issue certificate: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleVerifyCertificate() async {
    try {
      await _industryService.verifyCertificate(internshipId: _internship.id);
      setState(() {
        _internship = _internship.copyWith(certificateStatus: 'verified');
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Completion certificate verified.'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to verify certificate: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _openDocument(InternshipDocument doc) async {
    final url = doc.fileUrl;
    if (url != null && url.isNotEmpty) {
      final uri = Uri.tryParse(url);
      if (uri != null) {
        try {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          return;
        } catch (_) {}
      }
    }
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Document file preview: ${doc.fileName} (${doc.filePath})',
          ),
        ),
      );
    }
  }

  Future<void> _handleVerifyStudentDocument(InternshipDocument doc) async {
    final remarksController = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Verify ${doc.fileName}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Confirm verification for ${_internship.studentName}\'s uploaded document:',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: 'Remarks (Optional)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Verify Document'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _industryService.verifyStudentDocument(
          documentId: doc.id,
          status: 'verified',
          remarks: remarksController.text.trim().isNotEmpty
              ? remarksController.text.trim()
              : null,
        );
        await _fetchDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document verified successfully.'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to verify document: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _handleRejectStudentDocument(InternshipDocument doc) async {
    final reasonController = TextEditingController();
    final remarksController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reject ${doc.fileName}'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('A mandatory rejection reason is required:'),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason *',
                  hintText: 'e.g. Invalid company seal or mismatch in dates',
                  border: OutlineInputBorder(),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Please provide a reason for rejection.';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              TextField(
                controller: remarksController,
                decoration: const InputDecoration(
                  labelText: 'Remarks for Re-upload (Optional)',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.pop(ctx, true);
              }
            },
            child: const Text('Reject Document'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await _industryService.verifyStudentDocument(
          documentId: doc.id,
          status: 'rejected',
          rejectionReason: reasonController.text.trim(),
          remarks: remarksController.text.trim().isNotEmpty
              ? remarksController.text.trim()
              : null,
        );
        await _fetchDetails();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Document rejected with feedback provided.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Failed to reject document: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final subItems = <String>[];
    if (_internship.studentRollNo != null &&
        _internship.studentRollNo!.isNotEmpty) {
      subItems.add('ID: ${_internship.studentRollNo}');
    }
    if (_internship.branch != null && _internship.branch!.isNotEmpty) {
      subItems.add(_internship.branch!);
    }
    if (_internship.companyName != null &&
        _internship.companyName!.isNotEmpty) {
      subItems.add(_internship.companyName!);
    }

    final attSummary = IndustryAttendanceSummary.fromRecords(
      _attendanceRecords,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Internship Details'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _fetchDetails,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _loadError != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.error_outline,
                      size: 50,
                      color: Colors.red,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Unable to load details:\n\n$_loadError',
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _fetchDetails,
                      child: const Text('Try Again'),
                    ),
                  ],
                ),
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Student Profile Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          child: Text(
                            _internship.studentName.isNotEmpty
                                ? _internship.studentName[0].toUpperCase()
                                : 'S',
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _internship.studentName,
                                style: const TextStyle(
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _internship.internshipTitle,
                                style: TextStyle(
                                  fontSize: 15,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                              if (subItems.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 4),
                                  child: Text(
                                    subItems.join(' • '),
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey.shade600,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Internship Overview Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        _InfoRow(
                          label: 'Internship Status',
                          value: _formatStatus(_internship.status),
                        ),
                        const Divider(),
                        _InfoRow(
                          label: 'Progress',
                          value: '${_internship.progress.toStringAsFixed(0)}%',
                        ),
                        const Divider(),
                        _InfoRow(
                          label: 'Start Date',
                          value: _formatDate(_internship.startDate),
                        ),
                        const Divider(),
                        _InfoRow(
                          label: 'End Date',
                          value: _formatDate(_internship.endDate),
                        ),
                        const Divider(),
                        _InfoRow(
                          label: 'Evaluation Status',
                          value: _formatStatus(
                            _evaluation?.status ?? _internship.evaluationStatus,
                          ),
                        ),
                        const Divider(),
                        _InfoRow(
                          label: 'Attendance Rate',
                          value: _attendanceRecords.isNotEmpty
                              ? '${attSummary.attendancePercentage.toStringAsFixed(0)}% (${attSummary.presentDays}/${attSummary.totalDays} Days)'
                              : (_internship.attendanceRate != null
                                    ? '${_internship.attendanceRate!.toStringAsFixed(0)}%'
                                    : 'No logs yet'),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Geo-Tagged Progress Section for Industry
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Student Geo-Progress Updates',
                      style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    Chip(
                      label: Text(
                        '${_geoProgressLogs.length} Updates',
                        style: const TextStyle(fontSize: 12, color: Colors.indigo),
                      ),
                      backgroundColor: Colors.indigo.shade50,
                      side: BorderSide(color: Colors.indigo.shade200),
                    ),
                  ],
                ),
                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (_geoProgressLogs.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 8),
                            child: Text(
                              'No geo-progress updates submitted by student yet.',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                        else
                          ..._geoProgressLogs.map((log) {
                            final hasCoords =
                                log.latitude != null && log.longitude != null;
                            return Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.shade50,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.grey.shade200),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: Colors.teal.shade100,
                                    child: Text(
                                      '${log.progressPercent}%',
                                      style: TextStyle(
                                        color: Colors.teal.shade900,
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          log.taskSummary,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: 14,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          _formatDate(log.capturedAt),
                                          style: TextStyle(
                                            color: Colors.grey.shade600,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (hasCoords) ...[
                                          const SizedBox(height: 4),
                                          Row(
                                            children: [
                                              const Icon(
                                                Icons.location_pin,
                                                size: 14,
                                                color: Colors.redAccent,
                                              ),
                                              const SizedBox(width: 4),
                                              Text(
                                                'Lat: ${log.latitude!.toStringAsFixed(4)}, Long: ${log.longitude!.toStringAsFixed(4)} (±${log.accuracyM?.toStringAsFixed(0) ?? '?'}m)',
                                                style: TextStyle(
                                                  color: Colors.grey.shade800,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Attendance Section
                const Text(
                  'Internship Attendance',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Attendance Summary',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Chip(
                              label: Text(
                                _attendanceRecords.isNotEmpty
                                    ? '${attSummary.attendancePercentage.toStringAsFixed(0)}% Present'
                                    : 'Pending Logs',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Colors.teal,
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _miniMetric(
                              'Total Days',
                              attSummary.totalDays.toString(),
                            ),
                            _miniMetric(
                              'Present',
                              attSummary.presentDays.toString(),
                              color: Colors.green,
                            ),
                            _miniMetric(
                              'Absent',
                              attSummary.absentDays.toString(),
                              color: Colors.red,
                            ),
                            _miniMetric(
                              'Leave',
                              attSummary.leaveDays.toString(),
                              color: Colors.orange,
                            ),
                          ],
                        ),
                        if (_attendanceRecords.isNotEmpty) ...[
                          const Divider(height: 24),
                          const Text(
                            'Recent Attendance Logs:',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 6),
                          ..._attendanceRecords
                              .take(3)
                              .map(
                                (r) => Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 4,
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        r.status.toLowerCase() == 'present'
                                            ? Icons.check_circle_outline
                                            : Icons.cancel_outlined,
                                        size: 16,
                                        color:
                                            r.status.toLowerCase() == 'present'
                                            ? Colors.green
                                            : Colors.red,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(_formatDate(r.date)),
                                      const Spacer(),
                                      Text(
                                        r.status.toUpperCase(),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color:
                                              r.status.toLowerCase() ==
                                                  'present'
                                              ? Colors.green
                                              : Colors.red,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                        ],
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Performance Evaluation Section
                const Text(
                  'Internship Performance Evaluation',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _evaluation != null &&
                                      _evaluation!.status == 'verified'
                                  ? 'Evaluation Completed'
                                  : 'Company Evaluation',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Chip(
                              label: Text(
                                _formatStatus(
                                  _evaluation?.status ??
                                      _internship.evaluationStatus,
                                ),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: _getStatusColor(
                                _evaluation?.status ??
                                    _internship.evaluationStatus,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        if (_evaluation != null &&
                            _evaluation!.totalScore > 0) ...[
                          Row(
                            children: [
                              Text(
                                'Score: ${_evaluation!.totalScore.toStringAsFixed(1)} / 100',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.indigo,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Text(
                                'Grade: ${_evaluation!.grade}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                          if (_evaluation!.feedback != null &&
                              _evaluation!.feedback!.isNotEmpty) ...[
                            const SizedBox(height: 8),
                            Text(
                              'Feedback: ${_evaluation!.feedback}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade800,
                              ),
                            ),
                          ],
                          if (_evaluation!.remarks != null &&
                              _evaluation!.remarks!.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              'Supervisor Remarks: ${_evaluation!.remarks}',
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                          ],
                        ] else ...[
                          const Text(
                            'Performance evaluation is pending for this intern. Evaluate against the 5-criteria company rubric.',
                            style: TextStyle(fontSize: 14),
                          ),
                        ],
                        const SizedBox(height: 14),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            icon: const Icon(Icons.assignment_turned_in),
                            label: Text(
                              _evaluation != null &&
                                      _evaluation!.status == 'verified'
                                  ? 'View / Edit Company Evaluation'
                                  : 'Evaluate Student Performance',
                            ),
                            onPressed: () async {
                              final dummyEval =
                                  _evaluation ??
                                  IndustryEvaluationModel(
                                    id: '',
                                    internshipId: _internship.id,
                                    studentId: _internship.studentId ?? '',
                                    studentName: _internship.studentName,
                                    internshipTitle:
                                        _internship.internshipTitle,
                                    companyName:
                                        _internship.companyName ?? 'Company',
                                    totalScore: 0,
                                    grade: 'F',
                                    status: 'pending',
                                  );

                              final updated = await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => IndustryEvaluationFormScreen(
                                    evaluation: dummyEval,
                                    evaluationService: _evaluationService,
                                  ),
                                ),
                              );

                              if (updated == true) {
                                _fetchDetails();
                              }
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 20),

                // Company Issued Documents: Offer Letter & Certificate
                const Text(
                  'Company Documents',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                // Offer Letter Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(Icons.description, color: Colors.teal),
                                SizedBox(width: 8),
                                Text(
                                  'Offer Letter',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Chip(
                              label: Text(
                                _formatStatus(_internship.offerLetterStatus),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: _getStatusColor(
                                _internship.offerLetterStatus,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        if (_internship.offerLetterUrl != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Document: ${_internship.offerLetterUrl}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.upload_file),
                                label: Text(
                                  _internship.offerLetterStatus == 'pending'
                                      ? 'Issue Offer Letter'
                                      : 'Update Offer Letter',
                                ),
                                onPressed: _handleIssueOfferLetter,
                              ),
                            ),
                            if (_internship.offerLetterStatus == 'issued') ...[
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.verified),
                                label: const Text('Verify'),
                                onPressed: _handleVerifyOfferLetter,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 10),

                // Completion Certificate Card
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Row(
                              children: [
                                Icon(
                                  Icons.workspace_premium,
                                  color: Colors.deepPurple,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  'Internship Completion Certificate',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Chip(
                              label: Text(
                                _formatStatus(_internship.certificateStatus),
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: _getStatusColor(
                                _internship.certificateStatus,
                              ),
                              visualDensity: VisualDensity.compact,
                            ),
                          ],
                        ),
                        if (_internship.certificateUrl != null) ...[
                          const SizedBox(height: 6),
                          Text(
                            'Document: ${_internship.certificateUrl}',
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey.shade700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.upload_file),
                                label: Text(
                                  _internship.certificateStatus == 'pending'
                                      ? 'Issue Certificate'
                                      : 'Update Certificate',
                                ),
                                onPressed: _handleIssueCertificate,
                              ),
                            ),
                            if (_internship.certificateStatus == 'issued') ...[
                              const SizedBox(width: 8),
                              FilledButton.tonalIcon(
                                icon: const Icon(Icons.verified),
                                label: const Text('Verify'),
                                onPressed: _handleVerifyCertificate,
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Student-Uploaded Documents: Offer Letters & Certificates Verification
                const Text(
                  'Student-Uploaded Documents',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),

                if (_studentDocuments.isEmpty)
                  const Card(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(
                        child: Text(
                          'No student-uploaded documents found for verification.',
                          style: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ),
                  )
                else
                  ..._studentDocuments.map((doc) {
                    final docTypeName = doc.docType == 'offer_letter'
                        ? 'Student Offer Letter'
                        : doc.docType == 'certificate'
                        ? 'Student Certificate'
                        : doc.docType.replaceAll('_', ' ').toUpperCase();

                    final statusColor = doc.status == 'verified'
                        ? Colors.green
                        : doc.status == 'rejected'
                        ? Colors.red
                        : Colors.orange;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      doc.docType == 'offer_letter'
                                          ? Icons.description
                                          : Icons.workspace_premium,
                                      color: doc.docType == 'offer_letter'
                                          ? Colors.teal
                                          : Colors.deepPurple,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      docTypeName,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                                Chip(
                                  label: Text(
                                    doc.status.toUpperCase(),
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: Colors.white,
                                    ),
                                  ),
                                  backgroundColor: statusColor,
                                  visualDensity: VisualDensity.compact,
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'File: ${doc.fileName}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 13,
                              ),
                            ),
                            Text(
                              'Uploaded: ${_formatDate(doc.createdAt)}',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey.shade600,
                              ),
                            ),
                            if (doc.verifiedByName != null) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reviewed by: ${doc.verifiedByName} on ${_formatDate(doc.verifiedAt)}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                            if (doc.remarks != null &&
                                doc.remarks!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Text(
                                'Reviewer Remarks: ${doc.remarks}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ],
                            if (doc.status == 'rejected' &&
                                doc.rejectionReason != null) ...[
                              const SizedBox(height: 6),
                              Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(
                                  color: Colors.red.shade50,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(
                                    color: Colors.red.shade200,
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 16,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        'Rejection Reason: ${doc.rejectionReason!}',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.red.shade900,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.visibility, size: 16),
                                  label: const Text('Preview / Download'),
                                  onPressed: () => _openDocument(doc),
                                ),
                                const Spacer(),
                                if (doc.status != 'verified') ...[
                                  FilledButton.tonalIcon(
                                    icon: const Icon(
                                      Icons.check_circle_outline,
                                      size: 16,
                                    ),
                                    label: const Text('Verify'),
                                    onPressed: () =>
                                        _handleVerifyStudentDocument(doc),
                                  ),
                                  const SizedBox(width: 8),
                                ],
                                if (doc.status != 'rejected') ...[
                                  OutlinedButton.icon(
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: Colors.red,
                                    ),
                                    icon: const Icon(
                                      Icons.cancel_outlined,
                                      size: 16,
                                    ),
                                    label: const Text('Reject'),
                                    onPressed: () =>
                                        _handleRejectStudentDocument(doc),
                                  ),
                                ],
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  }),

                const SizedBox(height: 24),
              ],
            ),
    );
  }

  Widget _miniMetric(String label, String value, {Color? color}) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: color ?? Colors.black87,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
        ),
        Flexible(child: Text(value, textAlign: TextAlign.right)),
      ],
    );
  }
}
