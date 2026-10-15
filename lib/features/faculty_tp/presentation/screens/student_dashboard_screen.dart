import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/auth/auth_service.dart';

class StudentDashboardScreen extends StatefulWidget {
  const StudentDashboardScreen({super.key});

  @override
  State<StudentDashboardScreen> createState() => _StudentDashboardScreenState();
}

class _StudentDashboardScreenState extends State<StudentDashboardScreen> {
  bool _isLoading = true;
  String? _error;

  UserProfile? _profile;
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _internshipData;
  Map<String, dynamic>? _itrData;
  Map<String, dynamic>? _certData;
  List<Map<String, dynamic>> _approvalReviews = [];

  @override
  void initState() {
    super.initState();
    _loadStudentDashboard();
  }

  Future<void> _loadStudentDashboard() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      SupabaseClient? client;
      try {
        client = Supabase.instance.client;
      } catch (_) {
        client = null;
      }

      final authService = AuthService(client: client);
      final profile = await authService.getCurrentUserProfile();
      final user = authService.currentUser;

      if (client == null || user == null) {
        setState(() {
          _error = 'Please sign in to view your student dashboard.';
          _isLoading = false;
        });
        return;
      }


      // Query student record for authenticated user
      final studentRes = await client
          .from('students')
          .select('''
            id,
            roll_number,
            department,
            batch_year,
            created_at,
            updated_at
          ''')
          .eq('user_id', user.id)
          .maybeSingle();

      Map<String, dynamic>? internshipMap;
      Map<String, dynamic>? itrMap;
      Map<String, dynamic>? certMap;
      final reviewsList = <Map<String, dynamic>>[];

      if (studentRes != null) {
        final studentId = studentRes['id'] as String;

        // Query active or latest internship
        final internshipRes = await client
            .from('internships')
            .select('''
              id,
              internship_title,
              company_name,
              status,
              mode,
              progress,
              start_date,
              end_date,
              description,
              industries (
                name,
                address,
                contact_email
              ),
              itrs (
                id,
                status,
                content,
                project_title,
                document_path,
                work_done,
                submitted_at,
                reviewer_name,
                remarks
              ),
              certificates (
                id,
                file_path,
                status,
                created_at
              ),
              approval_reviews (
                id,
                status,
                review_stage,
                remarks,
                created_at
              )
            ''')
            .eq('student_id', studentId)
            .order('created_at', ascending: false)
            .limit(1)
            .maybeSingle();

        if (internshipRes != null) {
          internshipMap = Map<String, dynamic>.from(internshipRes);

          if (internshipMap['itrs'] is List && (internshipMap['itrs'] as List).isNotEmpty) {
            itrMap = Map<String, dynamic>.from((internshipMap['itrs'] as List).first as Map);
          } else if (internshipMap['itrs'] is Map) {
            itrMap = Map<String, dynamic>.from(internshipMap['itrs'] as Map);
          }

          if (internshipMap['certificates'] is List && (internshipMap['certificates'] as List).isNotEmpty) {
            certMap = Map<String, dynamic>.from((internshipMap['certificates'] as List).first as Map);
          } else if (internshipMap['certificates'] is Map) {
            certMap = Map<String, dynamic>.from(internshipMap['certificates'] as Map);
          }

          if (internshipMap['approval_reviews'] is List) {
            for (final r in internshipMap['approval_reviews'] as List) {
              reviewsList.add(Map<String, dynamic>.from(r as Map));
            }
          }
        }
      }

      if (!mounted) return;

      setState(() {
        _profile = profile;
        _studentData = studentRes != null ? Map<String, dynamic>.from(studentRes) : null;
        _internshipData = internshipMap;
        _itrData = itrMap;
        _certData = certMap;
        _approvalReviews = reviewsList;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Unable to load dashboard data: $e';
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Student Dashboard'),
        actions: [
          IconButton(
            onPressed: () => AuthService.showAuthDialog(
              context,
              onSessionChanged: _loadStudentDashboard,
            ),
            icon: const Icon(Icons.account_circle),
            tooltip: 'Account',
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadStudentDashboard,
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
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton.icon(
                onPressed: _loadStudentDashboard,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final name = _profile?.fullName ?? 'Student';
    final email = _profile?.email ?? '';
    final rollNo = _studentData?['roll_number'] as String? ?? 'Pending Enrollment';
    final dept = _studentData?['department'] as String? ?? _profile?.department ?? 'General';
    final batch = _studentData?['batch_year']?.toString() ?? 'N/A';

    return RefreshIndicator(
      onRefresh: _loadStudentDashboard,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Profile Greeting Card
          Card(
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      name.isNotEmpty ? name[0].toUpperCase() : 'S',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Welcome, $name',
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Roll No: $rollNo • $dept (Batch $batch)',
                          style: TextStyle(color: Colors.grey.shade700, fontSize: 13),
                        ),
                        if (email.isNotEmpty)
                          Text(
                            email,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 12),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 16),

          // Current Internship Card
          Text(
            'My Internship Status',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 8),

          if (_internshipData == null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    const Icon(Icons.business_center_outlined, size: 40, color: Colors.grey),
                    const SizedBox(height: 8),
                    const Text(
                      'No active internship record registered yet.',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Contact your department Faculty Mentor or T&P Officer.',
                      style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            _internshipData!['internship_title'] as String? ?? 'Internship',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        Chip(
                          label: Text(
                            (_internshipData!['status'] as String? ?? 'ACTIVE').toUpperCase(),
                            style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                          backgroundColor: Colors.green.shade50,
                          padding: EdgeInsets.zero,
                        ),
                      ],
                    ),
                    Text(
                      _internshipData!['company_name'] as String? ?? 'Host Organization',
                      style: TextStyle(color: Colors.grey.shade700, fontSize: 14),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: ((_internshipData!['progress'] as num? ?? 0) / 100).clamp(0.0, 1.0),
                              minHeight: 8,
                              color: Colors.blue.shade700,
                              backgroundColor: Colors.blue.shade50,
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Text(
                          '${_internshipData!['progress'] ?? 0}% Completed',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 16),

          // ITR & Certificate Row
          Row(
            children: [
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.description, size: 18, color: Colors.blue),
                            SizedBox(width: 6),
                            Text('ITR Report', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _itrData != null
                              ? 'Status: ${_itrData!['status']?.toString().toUpperCase() ?? 'SUBMITTED'}'
                              : 'Status: Not Submitted',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: _itrData != null ? Colors.green.shade800 : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Row(
                          children: [
                            Icon(Icons.verified, size: 18, color: Colors.green),
                            SizedBox(width: 6),
                            Text('Certificate', style: TextStyle(fontWeight: FontWeight.bold)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          (_certData != null && _certData!['file_path'] != null)
                              ? 'Status: Uploaded'
                              : 'Status: Not Uploaded',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: (_certData != null && _certData!['file_path'] != null)
                                ? Colors.green.shade800
                                : Colors.orange.shade800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Approvals Card
          if (_approvalReviews.isNotEmpty) ...[
            Text(
              'Approvals Status',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 8),
            Card(
              child: Column(
                children: _approvalReviews.map((rev) {
                  final stage = rev['review_stage'] as String? ?? 'Faculty';
                  final status = rev['status'] as String? ?? 'Pending';
                  return ListTile(
                    leading: const Icon(Icons.check_circle_outline, color: Colors.blue),
                    title: Text('Stage: ${stage.toUpperCase()}'),
                    trailing: Chip(
                      label: Text(status.toUpperCase(), style: const TextStyle(fontSize: 11)),
                      backgroundColor: status.toLowerCase() == 'approved'
                          ? Colors.green.shade50
                          : Colors.orange.shade50,
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
