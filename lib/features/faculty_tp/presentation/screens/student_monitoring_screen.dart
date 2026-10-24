import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/auth/auth_service.dart';
import '../../../internship/models/internship.dart';
import '../../data/models/student_monitoring_item.dart';
import '../../data/repositories/student_monitoring_repository_factory.dart';
import '../../data/services/student_monitoring_service.dart';
import 'student_detail_screen.dart';

class StudentMonitoringScreen extends StatefulWidget {
  const StudentMonitoringScreen({super.key});

  @override
  State<StudentMonitoringScreen> createState() =>
      _StudentMonitoringScreenState();
}

class _StudentMonitoringScreenState
    extends State<StudentMonitoringScreen> {
  late final StudentMonitoringService _service;

  List<StudentMonitoringItem> _students = [];
  bool _isLoading = true;
  String? _error;
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  bool _pendingApprovalsOnly = false;
  final Map<String, String> _documentStatusOverrides = {};

  @override
  void initState() {
    super.initState();

    _service = StudentMonitoringService(
      repository: StudentMonitoringRepositoryFactory.create(),
    );

    _loadStudents();
  }

  Future<void> _loadStudents() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final students = await _service.loadStudents();

      if (!mounted) return;

      setState(() {
        _students = students;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      final String message;
      if (e is UnauthenticatedException) {
        message = 'Please sign in to access student monitoring data.';
      } else if (e is UnauthorizedException ||
          (e is PostgrestException && e.code == '42501') ||
          e.toString().toLowerCase().contains('permission denied')) {
        message =
            'Your account does not have permission to access student monitoring data.';
      } else {
        message = 'Unable to load student monitoring data';
      }

      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<StudentMonitoringItem> get _filteredStudents {
    final query = _searchQuery.toLowerCase();
    return _students.where((student) {
      final matchesQuery =
          query.isEmpty ||
          student.studentName.toLowerCase().contains(query) ||
          (student.studentEmail?.toLowerCase().contains(query) ?? false) ||
          (student.rollNumber?.toLowerCase().contains(query) ?? false);
      return matchesQuery &&
          (!_pendingApprovalsOnly || student.hasPendingApprovals);
    }).toList();
  }

  Future<void> _verifyDocument({
    required String documentId,
    required String status,
    String? rejectionReason,
    String? remarks,
  }) async {
    try {
      await _service.verifyStudentDocument(
        documentId: documentId,
        status: status,
        rejectionReason: rejectionReason,
        remarks: remarks,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            status == 'approved'
                ? 'Document verified by Faculty successfully.'
                : 'Document rejected by Faculty.',
          ),
          backgroundColor: status == 'approved' ? Colors.green : Colors.red,
        ),
      );
      setState(() {
        _documentStatusOverrides[documentId] = status;
      });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update document: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showApproveDialog(InternshipDocument doc) {
    final remarksController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Faculty Document Verification'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Approve document: ${doc.fileName}?'),
            const SizedBox(height: 12),
            TextField(
              controller: remarksController,
              decoration: const InputDecoration(
                labelText: 'Faculty Remarks (Optional)',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              _verifyDocument(
                documentId: doc.id,
                status: 'approved',
                remarks: remarksController.text.trim().isNotEmpty
                    ? remarksController.text.trim()
                    : null,
              );
            },
            child: const Text('Approve'),
          ),
        ],
      ),
    );
  }

  void _showRejectDialog(InternshipDocument doc) {
    final reasonController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Faculty Reject Document'),
        content: Form(
          key: formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Reject document: ${doc.fileName}'),
              const SizedBox(height: 12),
              TextFormField(
                controller: reasonController,
                decoration: const InputDecoration(
                  labelText: 'Rejection Reason *',
                  border: OutlineInputBorder(),
                  hintText: 'Enter mandatory reason for rejection',
                ),
                maxLines: 3,
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Rejection reason is mandatory';
                  }
                  return null;
                },
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () {
              if (formKey.currentState?.validate() ?? false) {
                Navigator.of(ctx).pop();
                _verifyDocument(
                  documentId: doc.id,
                  status: 'rejected',
                  rejectionReason: reasonController.text.trim(),
                );
              }
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Monitoring'),
        actions: [
          IconButton(
            onPressed: () => AuthService.showAuthDialog(
              context,
              onSessionChanged: _loadStudents,
            ),
            icon: Icon(
              AuthService.hasActiveSession
                  ? Icons.account_circle
                  : Icons.account_circle_outlined,
            ),
            tooltip: AuthService.hasActiveSession ? 'Account' : 'Sign In',
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadStudents,
              child: const Text('Retry'),
            ),
            if (_error!.contains('sign in')) ...[
              const SizedBox(height: 12),
              FilledButton(
                onPressed: () => AuthService.showAuthDialog(
                  context,
                  onSessionChanged: _loadStudents,
                ),
                child: const Text('Sign In'),
              ),
            ],
          ],
        ),
      );
    }

    final filteredStudents = _filteredStudents;
    if (filteredStudents.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('No students match your filter criteria.'),
            const SizedBox(height: 8),
            TextButton(
              onPressed: () {
                _searchController.clear();
                setState(() {
                  _searchQuery = '';
                  _pendingApprovalsOnly = false;
                });
              },
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by student name, email, or roll no...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isEmpty
                  ? null
                  : IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _searchQuery = '');
                      },
                    ),
            ),
            onChanged: (value) =>
                setState(() => _searchQuery = value.trim()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Align(
            alignment: Alignment.centerLeft,
            child: FilterChip(
              label: const Text('Pending Approvals'),
              selected: _pendingApprovalsOnly,
              onSelected: (selected) =>
                  setState(() => _pendingApprovalsOnly = selected),
            ),
          ),
        ),
        Expanded(
          child: RefreshIndicator(
            onRefresh: _loadStudents,
            child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: filteredStudents.length,
        itemBuilder: (context, index) {
          final student = filteredStudents[index];

          return InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => StudentDetailScreen(
                  studentId: student.studentId,
                  internshipId: student.internshipId,
                  studentName: student.studentName,
                ),
              ),
            ),
            child: Card(
            margin: const EdgeInsets.only(bottom: 12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const CircleAvatar(
                        child: Icon(Icons.person_outline),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              student.studentName,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            Text(
                              student.internshipTitle,
                              style: TextStyle(
                                fontSize: 13,
                                color: Colors.grey.shade700,
                              ),
                            ),
                            if (student.companyName != null)
                              Text(
                                student.companyName!,
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            if (student.rollNumber != null ||
                                student.studentEmail != null)
                              Text(
                                [
                                  if (student.rollNumber != null)
                                    student.rollNumber!,
                                  if (student.studentEmail != null)
                                    student.studentEmail!,
                                ].join(' • '),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade600,
                                ),
                              ),
                            Text(
                              '${student.progress}%',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Chip(
                        label: Text(
                          student.applicationStatus.toUpperCase(),
                          style: const TextStyle(fontSize: 11),
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                  const Divider(height: 20),
                  Wrap(
                    spacing: 8,
                    children: [
                      Text(
                        'ITR: ${(student.itrStatus ?? 'missing').toUpperCase()}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      Text(
                        student.hasCertificate
                            ? 'Cert: Uploaded'
                            : 'Cert: Missing',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ],
                  ),

                  // Company Evaluation & Attendance Visibility for Faculty
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Company Evaluation',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.indigo,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              student.companyEvaluationScore != null
                                  ? '${student.companyEvaluationScore!.toStringAsFixed(1)} / 100 (Grade: ${student.companyEvaluationGrade ?? "N/A"})'
                                  : 'Evaluation Pending',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: student.companyEvaluationScore != null
                                    ? Colors.black87
                                    : Colors.orange.shade800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          const Text(
                            'Attendance Rate',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                              color: Colors.teal,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            student.attendanceRate != null
                                ? '${student.attendanceRate!.toStringAsFixed(0)}%'
                                : 'No logs',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),

                  if (student.companyRemarks != null &&
                      student.companyRemarks!.isNotEmpty) ...[
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade100,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.comment_outlined, size: 14, color: Colors.blueGrey),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Company Remarks: ${student.companyRemarks!}',
                              style: const TextStyle(fontSize: 12, fontStyle: FontStyle.italic),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],

                  if (student.companyEvaluatorName != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      'Evaluated by: ${student.companyEvaluatorName}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                  ],

                  // Student-Uploaded Documents Section
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text(
                        'Student Documents (Offer Letters & Certificates)',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      Text(
                        '${student.documents.length} doc(s)',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  if (student.documents.isEmpty)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.grey.shade50,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Text(
                        'No offer letters or certificates uploaded yet.',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600, fontStyle: FontStyle.italic),
                      ),
                    )
                  else
                    ...student.documents.map(
                      (doc) => _buildDocumentTile(
                        doc,
                        statusOverride: _documentStatusOverrides[doc.id],
                      ),
                    ),
                ],
              ),
            ),
            ),
          );
        },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDocumentTile(
    InternshipDocument doc, {
    String? statusOverride,
  }) {
    final effectiveStatus = statusOverride ?? doc.status;
    Color indColor = Colors.orange;
    if (effectiveStatus == 'approved' || effectiveStatus == 'verified') {
      indColor = Colors.green;
    }
    if (effectiveStatus == 'rejected') indColor = Colors.red;

    Color facColor = Colors.orange;
    if (doc.facultyStatus == 'approved') facColor = Colors.green;
    if (doc.facultyStatus == 'rejected') facColor = Colors.red;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey.shade300),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                doc.docType == 'certificate'
                    ? Icons.workspace_premium
                    : Icons.description,
                size: 20,
                color: Colors.indigo,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  doc.fileName,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.open_in_new, size: 18),
                tooltip: 'Open / Download Document',
                onPressed: () async {
                  final url = doc.fileUrl;
                  if (url != null && url.isNotEmpty) {
                    final uri = Uri.tryParse(url);
                    if (uri != null) {
                      await launchUrl(uri, mode: LaunchMode.externalApplication);
                    }
                  }
                },
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.grey.shade200,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  doc.docType == 'certificate'
                      ? 'CERTIFICATE'
                      : doc.docType == 'offer_letter'
                          ? 'OFFER LETTER'
                          : 'DOCUMENT',
                  style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'Uploaded: ${doc.createdAt.toLocal().toString().split(' ')[0]}',
                style: TextStyle(fontSize: 11, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 8),
          // Dual Verification Status Badges (Industry & Faculty)
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              borderRadius: BorderRadius.circular(6),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Industry Verification: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: indColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        effectiveStatus.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: indColor),
                      ),
                    ),
                    if (doc.verifiedByName != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${doc.verifiedByName})',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
                if (doc.rejectionReason != null && doc.rejectionReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Industry Rejection Reason: ${doc.rejectionReason}',
                      style: const TextStyle(fontSize: 11, color: Colors.red),
                    ),
                  ),
                if (doc.remarks != null && doc.remarks!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Industry Remarks: ${doc.remarks}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                    ),
                  ),
                const Divider(height: 12),
                Row(
                  children: [
                    Text(
                      'Faculty Verification: ',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey.shade800),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: facColor.withAlpha(26),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        doc.facultyStatus.toUpperCase(),
                        style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: facColor),
                      ),
                    ),
                    if (doc.facultyVerifiedByName != null) ...[
                      const SizedBox(width: 6),
                      Text(
                        '(${doc.facultyVerifiedByName})',
                        style: TextStyle(fontSize: 10, color: Colors.grey.shade600),
                      ),
                    ],
                  ],
                ),
                if (doc.facultyRejectionReason != null && doc.facultyRejectionReason!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Faculty Rejection Reason: ${doc.facultyRejectionReason}',
                      style: const TextStyle(fontSize: 11, color: Colors.red),
                    ),
                  ),
                if (doc.facultyRemarks != null && doc.facultyRemarks!.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      'Faculty Remarks: ${doc.facultyRemarks}',
                      style: TextStyle(fontSize: 11, color: Colors.grey.shade700, fontStyle: FontStyle.italic),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 6),
          // Faculty Verification Action Buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red,
                  side: const BorderSide(color: Colors.red),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showRejectDialog(doc),
                icon: const Icon(Icons.close, size: 14),
                label: const Text('Reject', style: TextStyle(fontSize: 12)),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.green,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _showApproveDialog(doc),
                icon: const Icon(Icons.check, size: 14),
                label: const Text('Approve', style: TextStyle(fontSize: 12)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
