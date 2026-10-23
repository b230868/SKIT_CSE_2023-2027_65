import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';
import '../../data/models/student_monitoring_item.dart';
import '../../data/repositories/student_monitoring_repository_factory.dart';
import '../../data/services/student_monitoring_service.dart';
import 'student_detail_screen.dart';

class StudentMonitoringScreen extends StatefulWidget {
  final bool initialPendingApprovalsOnly;

  const StudentMonitoringScreen({
    super.key,
    this.initialPendingApprovalsOnly = false,
  });

  @override
  State<StudentMonitoringScreen> createState() =>
      _StudentMonitoringScreenState();
}

class _StudentMonitoringScreenState extends State<StudentMonitoringScreen> {
  late final StudentMonitoringService _service;

  List<StudentMonitoringItem> _students = [];
  bool _isLoading = true;
  String? _error;

  // Search & Filter state
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String _selectedDepartment = 'All';
  String _selectedInternshipStatus = 'All';
  String _selectedItrStatus = 'All';
  String _selectedCertStatus = 'All';
  late bool _pendingApprovalsOnly;

  @override
  void initState() {
    super.initState();
    _pendingApprovalsOnly = widget.initialPendingApprovalsOnly;
    _service = StudentMonitoringService(
      repository: StudentMonitoringRepositoryFactory.create(),
    );
    _loadStudents();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
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
        message = 'Your account does not have permission to access student monitoring data.';
      } else {
        message = 'Unable to load student monitoring data';
      }

      setState(() {
        _error = message;
        _isLoading = false;
      });
    }
  }

  List<String> get _departmentOptions {
    final depts = <String>{'All'};
    for (final s in _students) {
      if (s.department != null && s.department!.trim().isNotEmpty) {
        depts.add(s.department!.trim());
      }
    }
    return depts.toList();
  }

  List<StudentMonitoringItem> get _filteredStudents {
    return _students.where((student) {
      // 1. Text Search: name, email, roll number
      if (_searchQuery.isNotEmpty) {
        final q = _searchQuery.toLowerCase();
        final nameMatches = student.studentName.toLowerCase().contains(q);
        final emailMatches =
            student.studentEmail?.toLowerCase().contains(q) ?? false;
        final rollMatches =
            student.rollNumber?.toLowerCase().contains(q) ?? false;
        final titleMatches = student.internshipTitle.toLowerCase().contains(q);
        if (!nameMatches && !emailMatches && !rollMatches && !titleMatches) {
          return false;
        }
      }

      // 2. Department filter
      if (_selectedDepartment != 'All') {
        if (student.department?.toLowerCase() !=
            _selectedDepartment.toLowerCase()) {
          return false;
        }
      }

      // 3. Internship Status filter
      if (_selectedInternshipStatus != 'All') {
        final currentStatus =
            (student.internshipStatus ?? student.applicationStatus)
                .toLowerCase();
        if (currentStatus != _selectedInternshipStatus.toLowerCase()) {
          return false;
        }
      }

      // 4. ITR status filter
      if (_selectedItrStatus != 'All') {
        final itr = student.itrStatus?.toLowerCase();
        if (_selectedItrStatus == 'submitted' &&
            itr != 'submitted' &&
            itr != 'approved') {
          return false;
        } else if (_selectedItrStatus == 'draft' && itr != 'draft') {
          return false;
        } else if (_selectedItrStatus == 'missing' &&
            itr != null &&
            itr.isNotEmpty) {
          return false;
        }
      }

      // 5. Certificate status filter
      if (_selectedCertStatus != 'All') {
        if (_selectedCertStatus == 'uploaded' && !student.hasCertificate) {
          return false;
        } else if (_selectedCertStatus == 'not_uploaded' &&
            student.hasCertificate) {
          return false;
        }
      }

      // 6. Pending approvals only
      if (_pendingApprovalsOnly && !student.hasPendingApprovals) {
        return false;
      }

      return true;
    }).toList();
  }

  bool get _hasActiveFilters {
    return _searchQuery.isNotEmpty ||
        _selectedDepartment != 'All' ||
        _selectedInternshipStatus != 'All' ||
        _selectedItrStatus != 'All' ||
        _selectedCertStatus != 'All' ||
        _pendingApprovalsOnly;
  }

  void _resetFilters() {
    setState(() {
      _searchController.clear();
      _searchQuery = '';
      _selectedDepartment = 'All';
      _selectedInternshipStatus = 'All';
      _selectedItrStatus = 'All';
      _selectedCertStatus = 'All';
      _pendingApprovalsOnly = false;
    });
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudents,
            tooltip: 'Refresh',
          ),
        ],
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
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadStudents,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
              if (_error!.contains('sign in')) ...[
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: () => AuthService.showAuthDialog(
                    context,
                    onSessionChanged: _loadStudents,
                  ),
                  icon: const Icon(Icons.login),
                  label: const Text('Sign In'),
                ),
              ],
            ],
          ),
        ),
      );
    }

    if (_students.isEmpty) {
      return const Center(child: Text('No students available'));
    }

    final filtered = _filteredStudents;

    return Column(
      children: [
        _buildSearchAndFilterHeader(),
        Expanded(
          child: filtered.isEmpty
              ? _buildEmptyFilteredState()
              : RefreshIndicator(
                  onRefresh: _loadStudents,
                  child: ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final student = filtered[index];
                      return _buildStudentCard(student);
                    },
                  ),
                ),
        ),
      ],
    );
  }

  Widget _buildSearchAndFilterHeader() {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            offset: const Offset(0, 2),
            blurRadius: 4,
          ),
        ],
      ),
      child: Column(
        children: [
          // Search TextField
          TextField(
            controller: _searchController,
            decoration: InputDecoration(
              hintText: 'Search by student name, email, or roll no...',
              prefixIcon: const Icon(Icons.search),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear),
                      onPressed: () {
                        setState(() {
                          _searchController.clear();
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: Colors.grey.shade300),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 10,
              ),
              isDense: true,
            ),
            onChanged: (val) {
              setState(() {
                _searchQuery = val.trim();
              });
            },
          ),
          const SizedBox(height: 8),

          // Horizontal Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Department filter dropdown chip
                if (_departmentOptions.length > 2) ...[
                  PopupMenuButton<String>(
                    initialValue: _selectedDepartment,
                    onSelected: (val) {
                      setState(() {
                        _selectedDepartment = val;
                      });
                    },
                    itemBuilder: (ctx) => _departmentOptions.map((dept) {
                      return PopupMenuItem(
                        value: dept,
                        child: Text(dept == 'All' ? 'All Departments' : dept),
                      );
                    }).toList(),
                    child: Chip(
                      avatar: const Icon(Icons.domain, size: 16),
                      label: Text(
                        _selectedDepartment == 'All'
                            ? 'Department'
                            : _selectedDepartment,
                        style: const TextStyle(fontSize: 12),
                      ),
                      backgroundColor: _selectedDepartment != 'All'
                          ? Colors.blue.shade100
                          : null,
                    ),
                  ),
                  const SizedBox(width: 6),
                ],

                // Internship Status filter
                PopupMenuButton<String>(
                  initialValue: _selectedInternshipStatus,
                  onSelected: (val) {
                    setState(() {
                      _selectedInternshipStatus = val;
                    });
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'All',
                      child: Text('All Internship Statuses'),
                    ),
                    PopupMenuItem(value: 'active', child: Text('Active')),
                    PopupMenuItem(value: 'planned', child: Text('Planned')),
                    PopupMenuItem(value: 'completed', child: Text('Completed')),
                    PopupMenuItem(value: 'pending', child: Text('Pending')),
                  ],
                  child: Chip(
                    avatar: const Icon(
                      Icons.business_center_outlined,
                      size: 16,
                    ),
                    label: Text(
                      _selectedInternshipStatus == 'All'
                          ? 'Internship Status'
                          : _selectedInternshipStatus.toUpperCase(),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _selectedInternshipStatus != 'All'
                        ? Colors.blue.shade100
                        : null,
                  ),
                ),
                const SizedBox(width: 6),

                // ITR status filter
                PopupMenuButton<String>(
                  initialValue: _selectedItrStatus,
                  onSelected: (val) {
                    setState(() {
                      _selectedItrStatus = val;
                    });
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'All',
                      child: Text('All ITR Statuses'),
                    ),
                    PopupMenuItem(
                      value: 'submitted',
                      child: Text('ITR Submitted'),
                    ),
                    PopupMenuItem(value: 'draft', child: Text('ITR Draft')),
                    PopupMenuItem(value: 'missing', child: Text('ITR Missing')),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.description_outlined, size: 16),
                    label: Text(
                      _selectedItrStatus == 'All'
                          ? 'ITR Status'
                          : 'ITR: ${_selectedItrStatus.toUpperCase()}',
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _selectedItrStatus != 'All'
                        ? Colors.blue.shade100
                        : null,
                  ),
                ),
                const SizedBox(width: 6),

                // Certificate Status filter
                PopupMenuButton<String>(
                  initialValue: _selectedCertStatus,
                  onSelected: (val) {
                    setState(() {
                      _selectedCertStatus = val;
                    });
                  },
                  itemBuilder: (ctx) => const [
                    PopupMenuItem(
                      value: 'All',
                      child: Text('All Certificate Statuses'),
                    ),
                    PopupMenuItem(
                      value: 'uploaded',
                      child: Text('Certificate Uploaded'),
                    ),
                    PopupMenuItem(
                      value: 'not_uploaded',
                      child: Text('Certificate Missing'),
                    ),
                  ],
                  child: Chip(
                    avatar: const Icon(Icons.verified_outlined, size: 16),
                    label: Text(
                      _selectedCertStatus == 'All'
                          ? 'Certificate'
                          : (_selectedCertStatus == 'uploaded'
                                ? 'Cert Uploaded'
                                : 'Cert Missing'),
                      style: const TextStyle(fontSize: 12),
                    ),
                    backgroundColor: _selectedCertStatus != 'All'
                        ? Colors.blue.shade100
                        : null,
                  ),
                ),
                const SizedBox(width: 6),

                // Pending Approvals Toggle Chip
                FilterChip(
                  label: const Text(
                    'Pending Approvals',
                    style: TextStyle(fontSize: 12),
                  ),
                  selected: _pendingApprovalsOnly,
                  onSelected: (val) {
                    setState(() {
                      _pendingApprovalsOnly = val;
                    });
                  },
                ),

                if (_hasActiveFilters) ...[
                  const SizedBox(width: 6),
                  ActionChip(
                    avatar: const Icon(Icons.close, size: 14),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                    onPressed: _resetFilters,
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }

  Widget _buildEmptyFilteredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.search_off, size: 48, color: Colors.grey),
            const SizedBox(height: 12),
            const Text(
              'No students match your filter criteria.',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            const Text(
              'Try clearing some filters or searching with a different term.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _resetFilters,
              child: const Text('Reset All Filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStudentCard(StudentMonitoringItem student) {
    final statusColor = _getStatusColor(student.applicationStatus);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => StudentDetailScreen(
                studentId: student.studentId,
                internshipId: student.internshipId,
                studentName: student.studentName,
              ),
            ),
          );
        },
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Top Row: Avatar, Name, Roll No, Chevron
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  CircleAvatar(
                    radius: 20,
                    backgroundColor: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    child: Text(
                      student.studentName.isNotEmpty
                          ? student.studentName[0].toUpperCase()
                          : 'S',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
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
                            fontSize: 15,
                          ),
                        ),
                        if (student.rollNumber != null ||
                            student.department != null)
                          Text(
                            [
                              if (student.rollNumber != null)
                                'Roll: ${student.rollNumber}',
                              if (student.department != null)
                                student.department,
                              if (student.batchYear != null)
                                'Batch ${student.batchYear}',
                            ].join(' • '),
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        if (student.studentEmail != null)
                          Text(
                            student.studentEmail!,
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right, color: Colors.grey),
                ],
              ),

              const SizedBox(height: 10),
              const Divider(height: 1),
              const SizedBox(height: 10),

              // Internship Details Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          student.internshipTitle,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        if (student.companyName != null &&
                            student.companyName!.isNotEmpty)
                          Text(
                            student.companyName!,
                            style: TextStyle(
                              color: Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Chip(
                    label: Text(
                      student.applicationStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: statusColor.shade900,
                      ),
                    ),
                    backgroundColor: statusColor.shade50,
                    side: BorderSide(color: statusColor.shade200),
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Progress Bar
              Row(
                children: [
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: LinearProgressIndicator(
                        value: (student.progress.clamp(0, 100)) / 100,
                        minHeight: 6,
                        backgroundColor: Colors.grey.shade200,
                        color: Colors.blue.shade700,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${student.progress}%',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Colors.grey.shade800,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 10),

              // Status badges row: ITR, Certificate, Pending review
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: [
                  _badgeChip(
                    icon: Icons.description_outlined,
                    label: student.itrStatus != null
                        ? 'ITR: ${student.itrStatus!.toUpperCase()}'
                        : 'ITR: Missing',
                    isPositive:
                        student.itrStatus == 'submitted' ||
                        student.itrStatus == 'approved',
                  ),
                  _badgeChip(
                    icon: Icons.verified_outlined,
                    label: student.hasCertificate
                        ? 'Cert: Uploaded'
                        : 'Cert: Missing',
                    isPositive: student.hasCertificate,
                  ),
                  if (student.hasPendingApprovals)
                    _badgeChip(
                      icon: Icons.hourglass_top,
                      label: 'Approval Pending',
                      isPositive: false,
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _badgeChip({
    required IconData icon,
    required String label,
    required bool isPositive,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: isPositive ? Colors.green.shade50 : Colors.orange.shade50,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: isPositive ? Colors.green.shade300 : Colors.orange.shade300,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 13,
            color: isPositive ? Colors.green.shade800 : Colors.orange.shade800,
          ),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: isPositive
                  ? Colors.green.shade900
                  : Colors.orange.shade900,
            ),
          ),
        ],
      ),
    );
  }

  MaterialColor _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'approved':
      case 'active':
      case 'completed':
        return Colors.green;
      case 'rejected':
        return Colors.red;
      case 'planned':
        return Colors.blue;
      case 'pending':
      default:
        return Colors.orange;
    }
  }
}
