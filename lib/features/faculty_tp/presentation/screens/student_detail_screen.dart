import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../geo_progress/models/geo_progress_log.dart';
import '../../../geo_progress/services/geo_progress_service.dart';
import '../../data/models/student_monitoring_detail.dart';
import '../../data/repositories/student_monitoring_repository_factory.dart';
import '../../data/services/student_monitoring_service.dart';

class StudentDetailScreen extends StatefulWidget {
  final String studentId;
  final String? internshipId;
  final String? studentName;

  const StudentDetailScreen({
    super.key,
    required this.studentId,
    this.internshipId,
    this.studentName,
  });

  @override
  State<StudentDetailScreen> createState() => _StudentDetailScreenState();
}

class _StudentDetailScreenState extends State<StudentDetailScreen>
    with SingleTickerProviderStateMixin {
  late final StudentMonitoringService _service;
  late final TabController _tabController;

  StudentMonitoringDetail? _detail;
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = StudentMonitoringService(
      repository: StudentMonitoringRepositoryFactory.create(),
    );
    _tabController = TabController(length: 6, vsync: this);
    _loadDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadDetails() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final detail = await _service.loadStudentDetails(
        widget.studentId,
        internshipId: widget.internshipId,
      );

      if (!mounted) return;

      setState(() {
        _detail = detail;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      final String message;
      if (e is UnauthenticatedException) {
        message = 'Please sign in to access student monitoring details.';
      } else if (e is UnauthorizedException ||
          (e is PostgrestException && e.code == '42501') ||
          e.toString().toLowerCase().contains('permission denied')) {
        message = 'Your account does not have permission to view this student.';
      } else {
        message = 'Unable to load student details.';
      }

      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  Future<void> _openFileUrl({
    required String bucket,
    required String path,
    required String fileTitle,
  }) async {
    try {
      final url = await _service.getFileUrl(bucket: bucket, path: path);
      if (!mounted) return;

      if (url == null || url.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to generate secure file access URL.'),
          ),
        );
        return;
      }

      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(fileTitle),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'A secure link has been generated to view or download this document:',
              ),
              const SizedBox(height: 12),
              SelectableText(
                url,
                style: const TextStyle(
                  fontSize: 12,
                  color: Colors.blue,
                  decoration: TextDecoration.underline,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Link expires after 1 hour for security.',
                style: TextStyle(fontSize: 11, color: Colors.grey),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Clipboard.setData(ClipboardData(text: url));
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Secure link copied to clipboard!'),
                  ),
                );
              },
              child: const Text('Copy Link'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Failed to retrieve file: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.studentName ?? _detail?.studentName ?? 'Student Details';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadDetails,
            tooltip: 'Refresh',
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          tabs: const [
            Tab(icon: Icon(Icons.dashboard_outlined), text: 'Overview'),
            Tab(icon: Icon(Icons.school_outlined), text: 'Academic Details'),
            Tab(icon: Icon(Icons.business_center_outlined), text: 'Internship'),
            Tab(icon: Icon(Icons.description_outlined), text: 'ITR / Work'),
            Tab(icon: Icon(Icons.verified_outlined), text: 'Certificates'),
            Tab(
              icon: Icon(Icons.checklist_rtl_outlined),
              text: 'Approvals & Progress',
            ),
          ],
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 48, color: Colors.red),
              const SizedBox(height: 16),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadDetails,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final detail = _detail;
    if (detail == null) {
      return const Center(child: Text('Student information not found.'));
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildOverviewTab(detail),
        _buildAcademicTab(detail),
        _buildInternshipTab(detail),
        _buildItrTab(detail),
        _buildCertificatesTab(detail),
        _buildApprovalsTab(detail),
      ],
    );
  }

  // ===========================================================================
  // TAB 1: OVERVIEW & PROGRESS
  // ===========================================================================
  Widget _buildOverviewTab(StudentMonitoringDetail detail) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Header Profile Card
        Card(
          elevation: 2,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 32,
                  backgroundImage:
                      (detail.avatarUrl != null && detail.avatarUrl!.isNotEmpty)
                      ? NetworkImage(detail.avatarUrl!)
                      : null,
                  child: (detail.avatarUrl == null || detail.avatarUrl!.isEmpty)
                      ? Text(
                          detail.studentName.isNotEmpty
                              ? detail.studentName[0].toUpperCase()
                              : 'S',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        detail.studentName,
                        style: Theme.of(context).textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Roll No: ${detail.rollNumber ?? 'Not assigned'}',
                        style: TextStyle(color: Colors.grey.shade700),
                      ),
                      Text(
                        '${detail.department ?? 'Dept N/A'} • Batch ${detail.batchYear?.toString() ?? 'N/A'}',
                        style: TextStyle(color: Colors.grey.shade600),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        detail.studentEmail,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 13,
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

        // Progress Metric Summary
        Text(
          'Progress & Completion Summary',
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),

        Row(
          children: [
            Expanded(
              child: Card(
                color: Colors.blue.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profile Completion',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${detail.profileCompletionPercentage}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: detail.profileCompletionPercentage / 100,
                        backgroundColor: Colors.blue.shade100,
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Card(
                color: Colors.green.shade50,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Internship Progress',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${detail.progress}%',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Colors.green.shade800,
                        ),
                      ),
                      const SizedBox(height: 6),
                      LinearProgressIndicator(
                        value: (detail.progress.clamp(0, 100)) / 100,
                        backgroundColor: Colors.green.shade100,
                        color: Colors.green.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),

        const SizedBox(height: 16),

        // Milestone Statuses
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Key Academic & Monitoring Milestones',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const Divider(),
                _statusMilestoneRow(
                  title: 'Internship Status',
                  status: detail.internshipStatus ?? 'Not registered',
                  isGood:
                      detail.internshipStatus == 'active' ||
                      detail.internshipStatus == 'completed',
                ),
                _statusMilestoneRow(
                  title: 'ITR Submission',
                  status: detail.itrStatus != null
                      ? 'ITR: ${detail.itrStatus!.toUpperCase()}'
                      : 'Not submitted',
                  isGood:
                      detail.itrStatus == 'submitted' ||
                      detail.itrStatus == 'approved',
                ),
                _statusMilestoneRow(
                  title: 'Certificate Upload',
                  status: detail.hasCertificateUploaded
                      ? 'Uploaded (${detail.certificateStatus ?? 'Pending'})'
                      : 'Not uploaded',
                  isGood: detail.hasCertificateUploaded,
                ),
                _statusMilestoneRow(
                  title: 'Pending Approvals',
                  status:
                      detail.approvalReviews.any(
                        (r) => r.status.toLowerCase() == 'pending',
                      )
                      ? 'Review Pending'
                      : (detail.approvalReviews.isNotEmpty
                            ? 'Reviews Complete'
                            : 'No reviews logged'),
                  isGood: !detail.approvalReviews.any(
                    (r) => r.status.toLowerCase() == 'pending',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _statusMilestoneRow({
    required String title,
    required String status,
    required bool isGood,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title),
          Chip(
            label: Text(
              status,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: isGood ? Colors.green.shade900 : Colors.orange.shade900,
              ),
            ),
            backgroundColor: isGood
                ? Colors.green.shade50
                : Colors.orange.shade50,
            side: BorderSide(
              color: isGood ? Colors.green.shade300 : Colors.orange.shade300,
            ),
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  // ===========================================================================
  // TAB 2: PERSONAL & ACADEMIC DETAILS
  // ===========================================================================
  Widget _buildAcademicTab(StudentMonitoringDetail detail) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(Icons.person, 'Personal & Contact Information'),
                const Divider(),
                _dataItem('Full Name', detail.studentName),
                _dataItem('Email Address', detail.studentEmail),
                _dataItem('Phone Number', detail.phone ?? 'Not provided'),
                _dataItem(
                  'Residential Address',
                  detail.address ?? 'Not provided',
                ),
                _dataItem('Account Active', detail.isActive ? 'Yes' : 'No'),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(Icons.school, 'Academic Enrollment'),
                const Divider(),
                _dataItem(
                  'Roll Number / Student ID',
                  detail.rollNumber ?? 'Not assigned',
                ),
                _dataItem('Department', detail.department ?? 'Not assigned'),
                _dataItem(
                  'Branch / Course',
                  detail.branch ?? detail.department ?? 'Not assigned',
                ),
                _dataItem(
                  'Batch Year',
                  detail.batchYear?.toString() ?? 'Not specified',
                ),
                _dataItem(
                  'Profile Created On',
                  detail.profileCreatedAt != null
                      ? _formatDate(detail.profileCreatedAt!)
                      : 'Unknown',
                ),
                _dataItem(
                  'Last Profile Update',
                  detail.profileUpdatedAt != null
                      ? _formatDate(detail.profileUpdatedAt!)
                      : 'Unknown',
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 3: INTERNSHIP DETAILS
  // ===========================================================================
  Widget _buildInternshipTab(StudentMonitoringDetail detail) {
    if (detail.internshipId == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.business_center_outlined,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 12),
              Text(
                'No internship records found for this student.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(Icons.work_outline, 'Internship Overview'),
                const Divider(),
                _dataItem(
                  'Internship Title / Role',
                  detail.internshipTitle ?? 'Untitled',
                ),
                _dataItem(
                  'Company / Organization',
                  detail.companyName ?? 'Not specified',
                ),
                _dataItem(
                  'Internship Mode',
                  detail.internshipMode ?? 'Not specified',
                ),
                _dataItem(
                  'Current Status',
                  detail.internshipStatus?.toUpperCase() ?? 'PENDING',
                ),
                _dataItem('Reported Progress', '${detail.progress}%'),
                _dataItem(
                  'Start Date',
                  detail.startDate != null
                      ? _formatDate(detail.startDate!)
                      : 'N/A',
                ),
                _dataItem(
                  'End Date',
                  detail.endDate != null ? _formatDate(detail.endDate!) : 'N/A',
                ),
                if (detail.durationInWeeks != null)
                  _dataItem(
                    'Calculated Duration',
                    '${detail.durationInWeeks} weeks',
                  ),
                _dataItem(
                  'Description & Objectives',
                  detail.description ?? 'No description provided.',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  Icons.location_city,
                  'Host Organization Details',
                ),
                const Divider(),
                _dataItem(
                  'Industry Name',
                  detail.industryName ?? detail.companyName ?? 'N/A',
                ),
                _dataItem(
                  'Industry Address',
                  detail.industryAddress ?? 'Not provided',
                ),
                _dataItem(
                  'Contact Email',
                  detail.industryEmail ?? 'Not provided',
                ),
                _dataItem(
                  'Contact Phone',
                  detail.industryPhone ?? 'Not provided',
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        _buildFacultyGeoProgressSection(detail),
      ],
    );
  }

  Widget _buildFacultyGeoProgressSection(StudentMonitoringDetail detail) {
    final isApproved = detail.internshipStatus?.toLowerCase() == 'approved';

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.share_location, color: Colors.indigo),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Student Geo Progress Tracking',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                Chip(
                  label: Text(
                    isApproved ? 'TRACKING ACTIVE' : 'LOCKED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                      color: isApproved ? Colors.green.shade900 : Colors.red.shade900,
                    ),
                  ),
                  backgroundColor:
                      isApproved ? Colors.green.shade50 : Colors.red.shade50,
                  side: BorderSide(
                    color:
                        isApproved ? Colors.green.shade300 : Colors.red.shade300,
                  ),
                ),
              ],
            ),
            const Divider(),
            if (!isApproved)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lock_outline, color: Colors.amber.shade900),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Geo Progress tracking is locked. It will only be visible once you approve this internship application.',
                        style: TextStyle(
                          color: Colors.amber.shade900,
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              )
            else
              FutureBuilder<List<GeoProgressLog>>(
                future: GeoProgressService().fetchHistory(detail.internshipId!),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 20),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      child: Text(
                        'Unable to load geo progress logs: ${snapshot.error}',
                        style: TextStyle(color: Colors.red.shade700, fontSize: 13),
                      ),
                    );
                  }
                  final logs = snapshot.data ?? [];
                  if (logs.isEmpty) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No geo-tagged progress reports submitted by student yet.',
                        style: TextStyle(color: Colors.grey),
                      ),
                    );
                  }
                  return Column(
                    children: logs.map((log) {
                      final hasCoords = log.latitude != null && log.longitude != null;
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
                              backgroundColor: Colors.indigo.shade100,
                              child: Text(
                                '${log.progressPercent}%',
                                style: TextStyle(
                                  color: Colors.indigo.shade900,
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
                                          Icons.location_on,
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
                    }).toList(),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }

  // ===========================================================================
  // TAB 4: ITR / WORK SUBMISSION DETAILS
  // ===========================================================================
  Widget _buildItrTab(StudentMonitoringDetail detail) {
    if (detail.itrId == null &&
        detail.itrContent == null &&
        detail.itrStatus == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.assignment_late_outlined,
                size: 48,
                color: Colors.grey,
              ),
              SizedBox(height: 12),
              Text(
                'No Industrial Training Report (ITR) submitted yet.',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  Icons.description,
                  'Industrial Training Report (ITR)',
                ),
                const Divider(),
                _dataItem(
                  'Submission Title',
                  detail.itrProjectTitle ?? 'Industrial Training Report',
                ),
                _dataItem(
                  'Current Status',
                  detail.itrStatus?.toUpperCase() ?? 'SUBMITTED',
                ),
                _dataItem(
                  'Submitted At',
                  detail.itrSubmittedAt != null
                      ? _formatDate(detail.itrSubmittedAt!)
                      : 'Pending formal submission',
                ),
                if (detail.itrReviewedAt != null)
                  _dataItem('Reviewed At', _formatDate(detail.itrReviewedAt!)),
                if (detail.itrReviewerName != null)
                  _dataItem('Reviewer Name', detail.itrReviewerName!),
                if (detail.itrRemarks != null && detail.itrRemarks!.isNotEmpty)
                  _dataItem('Reviewer Feedback / Remarks', detail.itrRemarks!),
                _dataItem(
                  'Report Content / Overview',
                  detail.itrContent ??
                      detail.itrProjectDescription ??
                      'No text summary provided.',
                ),
                if (detail.itrWorkDone != null)
                  _dataItem('Work Done Details', detail.itrWorkDone!),
                if (detail.itrTechnologiesUsed != null)
                  _dataItem('Technologies Used', detail.itrTechnologiesUsed!),
                if (detail.itrKeyLearnings != null)
                  _dataItem('Key Learnings', detail.itrKeyLearnings!),
                if (detail.itrChallengesFaced != null)
                  _dataItem('Challenges Faced', detail.itrChallengesFaced!),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(Icons.attach_file, 'Uploaded Report Documents'),
                const Divider(),
                if (detail.itrDocumentPath != null &&
                    detail.itrDocumentPath!.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.picture_as_pdf,
                      color: Colors.red,
                    ),
                    title: const Text('ITR Written Report'),
                    subtitle: Text(detail.itrDocumentPath!),
                    trailing: FilledButton.tonalIcon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Access File'),
                      onPressed: () => _openFileUrl(
                        bucket: 'itrs',
                        path: detail.itrDocumentPath!,
                        fileTitle: 'ITR Written Report',
                      ),
                    ),
                  )
                else
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8.0),
                    child: Text('No main document file uploaded for ITR.'),
                  ),
                if (detail.itrProjectZipPath != null &&
                    detail.itrProjectZipPath!.isNotEmpty)
                  ListTile(
                    leading: const Icon(Icons.folder_zip, color: Colors.amber),
                    title: const Text('Project Source Code / Archive'),
                    subtitle: Text(detail.itrProjectZipPath!),
                    trailing: FilledButton.tonalIcon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Access Zip'),
                      onPressed: () => _openFileUrl(
                        bucket: 'itrs',
                        path: detail.itrProjectZipPath!,
                        fileTitle: 'Project Source Code',
                      ),
                    ),
                  ),
                if (detail.itrPresentationPath != null &&
                    detail.itrPresentationPath!.isNotEmpty)
                  ListTile(
                    leading: const Icon(
                      Icons.slideshow,
                      color: Colors.deepOrange,
                    ),
                    title: const Text('Project Presentation (PPT)'),
                    subtitle: Text(detail.itrPresentationPath!),
                    trailing: FilledButton.tonalIcon(
                      icon: const Icon(Icons.open_in_new, size: 16),
                      label: const Text('Access PPT'),
                      onPressed: () => _openFileUrl(
                        bucket: 'itrs',
                        path: detail.itrPresentationPath!,
                        fileTitle: 'Project Presentation',
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 5: CERTIFICATES & DOCUMENTS
  // ===========================================================================
  Widget _buildCertificatesTab(StudentMonitoringDetail detail) {
    final hasUploaded = detail.hasCertificateUploaded;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: hasUploaded ? Colors.green.shade50 : Colors.orange.shade50,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(
                  hasUploaded ? Icons.verified : Icons.warning_amber_rounded,
                  color: hasUploaded
                      ? Colors.green.shade800
                      : Colors.orange.shade800,
                  size: 32,
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        hasUploaded
                            ? 'Internship Certificate Uploaded'
                            : 'Internship Certificate Not Uploaded',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 15,
                          color: hasUploaded
                              ? Colors.green.shade900
                              : Colors.orange.shade900,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        hasUploaded
                            ? 'The student has uploaded a completion certificate reference.'
                            : 'No verified certificate file has been submitted for this internship.',
                        style: TextStyle(
                          fontSize: 13,
                          color: hasUploaded
                              ? Colors.green.shade900
                              : Colors.orange.shade900,
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
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(Icons.document_scanner, 'Certificate Details'),
                const Divider(),
                _dataItem('Document Type', 'Internship Completion Certificate'),
                _dataItem(
                  'Upload Status',
                  hasUploaded ? 'Uploaded' : 'Not Uploaded',
                ),
                _dataItem(
                  'Verification Status',
                  detail.certificateStatus != null
                      ? detail.certificateStatus!.toUpperCase()
                      : (hasUploaded ? 'PENDING' : 'NOT APPLICABLE'),
                ),
                _dataItem(
                  'Upload Date',
                  detail.certificateCreatedAt != null
                      ? _formatDate(detail.certificateCreatedAt!)
                      : 'N/A',
                ),
                _dataItem('Expiry Date', 'Not tracked in database schema'),
                _dataItem(
                  'File Path Reference',
                  detail.certificateFilePath ?? 'No file reference stored',
                ),
                if (hasUploaded) ...[
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.file_open),
                      label: const Text('Access & Preview Certificate'),
                      onPressed: () => _openFileUrl(
                        bucket: 'certificates',
                        path: detail.certificateFilePath!,
                        fileTitle: 'Internship Certificate',
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ===========================================================================
  // TAB 6: APPROVALS & PROGRESS
  // ===========================================================================
  Widget _buildApprovalsTab(StudentMonitoringDetail detail) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(Icons.checklist, 'Approval Review Workflow'),
                const Divider(),
                if (detail.approvalReviews.isEmpty)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 12.0),
                    child: Text('No formal approval reviews recorded yet.'),
                  )
                else
                  ...detail.approvalReviews.map((review) {
                    final isApproved =
                        review.status.toLowerCase() == 'approved';
                    final isPending = review.status.toLowerCase() == 'pending';

                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: isApproved
                            ? Colors.green.shade100
                            : (isPending
                                  ? Colors.orange.shade100
                                  : Colors.red.shade100),
                        child: Icon(
                          isApproved
                              ? Icons.check
                              : (isPending ? Icons.hourglass_top : Icons.close),
                          color: isApproved
                              ? Colors.green.shade800
                              : (isPending
                                    ? Colors.orange.shade800
                                    : Colors.red.shade800),
                        ),
                      ),
                      title: Text(
                        'Stage: ${review.reviewStage.toUpperCase()}',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Status: ${review.status.toUpperCase()}'),
                          if (review.remarks != null &&
                              review.remarks!.isNotEmpty)
                            Text('Remarks: ${review.remarks!}'),
                          if (review.createdAt != null)
                            Text(
                              'Date: ${_formatDate(review.createdAt!)}',
                              style: const TextStyle(fontSize: 12),
                            ),
                        ],
                      ),
                      isThreeLine: true,
                    );
                  }),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _sectionHeader(
                  Icons.pending_actions,
                  'Requirements Verification Checklist',
                ),
                const Divider(),
                _checklistTile(
                  'Student Profile Completed',
                  detail.profileCompletionPercentage >= 80,
                ),
                _checklistTile(
                  'Internship Application Stored',
                  detail.internshipId != null,
                ),
                _checklistTile(
                  'ITR / Work Report Submitted',
                  detail.itrStatus == 'submitted' ||
                      detail.itrStatus == 'approved',
                ),
                _checklistTile(
                  'Completion Certificate Uploaded',
                  detail.hasCertificateUploaded,
                ),
                _checklistTile(
                  'Faculty Review Approved',
                  detail.approvalReviews.any(
                    (r) => r.reviewStage == 'faculty' && r.status == 'approved',
                  ),
                ),
                _checklistTile(
                  'T&P Approval Granted',
                  detail.approvalReviews.any(
                    (r) =>
                        r.reviewStage == 'tp_admin' && r.status == 'approved',
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _checklistTile(String label, bool isComplete) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        isComplete ? Icons.check_circle : Icons.radio_button_unchecked,
        color: isComplete ? Colors.green : Colors.grey,
      ),
      title: Text(
        label,
        style: TextStyle(
          fontWeight: isComplete ? FontWeight.w600 : FontWeight.normal,
          color: isComplete ? Colors.black87 : Colors.grey.shade700,
        ),
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title) {
    return Row(
      children: [
        Icon(icon, size: 20, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.bold),
        ),
      ],
    );
  }

  Widget _dataItem(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 150,
            child: Text(
              label,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: Colors.grey.shade700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }
}
