import 'package:flutter/material.dart';

import '../../data/models/industry_attendance_model.dart';
import '../../data/models/industry_dashboard_data.dart';
import '../../data/models/industry_internship_model.dart';
import '../../data/services/industry_service.dart';

class IndustryAttendanceScreen extends StatefulWidget {
  final IndustryService? service;

  const IndustryAttendanceScreen({super.key, this.service});

  @override
  State<IndustryAttendanceScreen> createState() =>
      _IndustryAttendanceScreenState();
}

class _IndustryAttendanceScreenState extends State<IndustryAttendanceScreen> {
  late final IndustryService _service;

  bool _loading = true;
  String? _error;
  List<IndustryInternshipModel> _internships = [];
  IndustryDashboardData? _dashboardData;
  DateTime _selectedDate = DateTime.now();

  // Selected internship for detailed log view
  IndustryInternshipModel? _selectedInternship;
  List<IndustryAttendanceRecord> _selectedRecords = [];
  bool _loadingHistory = false;

  final Map<String, String?> _dailyStatusMap = {};
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = widget.service ?? IndustryService();
    _loadData();
  }

  bool get _isUnassigned {
    final name = _dashboardData?.industryName.toLowerCase() ?? '';
    return name.isEmpty ||
        name.contains('unassigned') ||
        name.contains('unverified');
  }

  Future<void> _loadData() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final results = await Future.wait([
        _service.getIndustryInternships(),
        _service.getDashboardData().catchError(
          (_) => IndustryDashboardData.empty(),
        ),
      ]);

      if (!mounted) return;
      final list = results[0] as List<IndustryInternshipModel>;
      final dash = results[1] as IndustryDashboardData;

      setState(() {
        _internships = list;
        _dashboardData = dash;
        _loading = false;
        if (list.isNotEmpty && _selectedInternship == null) {
          _selectedInternship = list.first;
        }
      });
      await _loadDailyStatusesForDate();
      if (_selectedInternship != null) {
        await _loadHistoryForInternship(_selectedInternship!);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _loadDailyStatusesForDate() async {
    for (final intern in _internships) {
      try {
        final history = await _service.getAttendanceRecords(intern.id);
        final match = history.where(
          (r) =>
              r.date.year == _selectedDate.year &&
              r.date.month == _selectedDate.month &&
              r.date.day == _selectedDate.day,
        );
        if (match.isNotEmpty) {
          _dailyStatusMap[intern.id] = match.first.status.toLowerCase();
        } else {
          _dailyStatusMap[intern.id] = null; // Unmarked
        }
      } catch (_) {
        _dailyStatusMap[intern.id] = null;
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _loadHistoryForInternship(
    IndustryInternshipModel internship,
  ) async {
    setState(() => _loadingHistory = true);
    try {
      final history = await _service.getAttendanceRecords(internship.id);
      if (!mounted) return;
      setState(() {
        _selectedRecords = history;
        _loadingHistory = false;

        // Check if there is already a record for the selected date
        final match = history.where(
          (r) =>
              r.date.year == _selectedDate.year &&
              r.date.month == _selectedDate.month &&
              r.date.day == _selectedDate.day,
        );
        if (match.isNotEmpty) {
          _dailyStatusMap[internship.id] = match.first.status.toLowerCase();
        } else {
          _dailyStatusMap[internship.id] = null;
        }
      });
    } catch (_) {
      if (mounted) setState(() => _loadingHistory = false);
    }
  }

  Future<void> _markStatusForIntern(
    IndustryInternshipModel internship,
    String status,
  ) async {
    if (_isUnassigned) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Cannot record attendance: Your account is pending company assignment by an administrator.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _dailyStatusMap[internship.id] = status;
      _saving = true;
    });

    try {
      await _service.markAttendance(
        internshipId: internship.id,
        studentId: internship.studentId ?? internship.id,
        date: _selectedDate,
        status: status,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Marked ${internship.studentName} as ${status.toUpperCase()} for ${_formatDate(_selectedDate)}',
            ),
            duration: const Duration(seconds: 2),
            backgroundColor: Colors.teal,
          ),
        );
      }

      if (_selectedInternship?.id == internship.id) {
        await _loadHistoryForInternship(internship);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to record attendance: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2025, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 1)),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() => _selectedDate = picked);
      await _loadDailyStatusesForDate();
      if (_selectedInternship != null) {
        await _loadHistoryForInternship(_selectedInternship!);
      }
    }
  }

  String _formatDate(DateTime dt) {
    return '${dt.day.toString().padLeft(2, '0')}/${dt.month.toString().padLeft(2, '0')}/${dt.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance Management'),
        actions: [
          if (_saving)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
            onPressed: _loadData,
          ),
        ],
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // Pending Company Assignment Warning
        if (_isUnassigned) ...[
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.amber.shade400),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.amber.shade900,
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Company Assignment Pending',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Colors.amber.shade900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Your account is not yet mapped to a verified company. Attendance tracking and updates remain restricted until an administrator assigns your company.',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],

        // Date Selector Bar (Always visible across all states)
        Card(
          color: const Color(0xFF14213D),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Attendance Date',
                      style: TextStyle(color: Colors.white70, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatDate(_selectedDate),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
                FilledButton.tonalIcon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_month),
                  label: const Text('Change Date'),
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 16),

        // Section Title & Auto-Save Note
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Mark Daily Attendance',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            Text(
              'Auto-saves on select',
              style: TextStyle(
                fontSize: 12,
                color: Colors.grey.shade600,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),

        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 48),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Loading attendance records...'),
                ],
              ),
            ),
          )
        else if (_error != null)
          Card(
            color: Colors.red.shade50,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: Colors.red.shade200),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 12),
                  const Text(
                    'Unable to load attendance',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade800, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Try Again'),
                  ),
                ],
              ),
            ),
          )
        else
          _buildInternshipContent(),
      ],
    );
  }

  Widget _buildInternshipContent() {
    final summary = IndustryAttendanceSummary.fromRecords(_selectedRecords);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_internships.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.people_outline,
                    size: 48,
                    color: Colors.grey.shade400,
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'No Assigned Interns',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _isUnassigned
                        ? 'Company assignment is pending. Please contact the administrator or T&P cell.'
                        : 'No eligible interns are currently assigned to your company for attendance tracking.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _loadData,
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('Refresh'),
                  ),
                ],
              ),
            ),
          )
        else ...[
          ..._internships.map((intern) {
            final isSelected = _selectedInternship?.id == intern.id;
            final status = _dailyStatusMap[intern.id];

            return Card(
              margin: const EdgeInsets.only(bottom: 10),
              shape: isSelected
                  ? RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                      side: const BorderSide(color: Colors.teal, width: 2),
                    )
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          child: Text(
                            intern.studentName.isNotEmpty
                                ? intern.studentName[0].toUpperCase()
                                : 'S',
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                intern.studentName,
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                '${intern.internshipTitle} • ${intern.studentRollNo ?? "No Roll No"}',
                                style: TextStyle(
                                  fontSize: 13,
                                  color: Colors.grey.shade700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          icon: const Icon(Icons.history, size: 16),
                          label: const Text('Log'),
                          onPressed: () {
                            setState(() => _selectedInternship = intern);
                            _loadHistoryForInternship(intern);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Status for ${_formatDate(_selectedDate)}:',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey.shade700,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: status == null
                                ? Colors.grey.shade200
                                : status == 'present'
                                ? Colors.green.withAlpha(26)
                                : status == 'absent'
                                ? Colors.red.withAlpha(26)
                                : Colors.orange.withAlpha(26),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            status == null ? 'UNMARKED' : status.toUpperCase(),
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: status == null
                                  ? Colors.grey.shade700
                                  : status == 'present'
                                  ? Colors.green
                                  : status == 'absent'
                                  ? Colors.red
                                  : Colors.orange,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    // Segmented Status Selector: Present, Absent, Leave
                    SegmentedButton<String>(
                      emptySelectionAllowed: true,
                      segments: const [
                        ButtonSegment(
                          value: 'present',
                          label: Text('Present'),
                          icon: Icon(
                            Icons.check_circle_outline,
                            color: Colors.green,
                          ),
                        ),
                        ButtonSegment(
                          value: 'absent',
                          label: Text('Absent'),
                          icon: Icon(Icons.cancel_outlined, color: Colors.red),
                        ),
                        ButtonSegment(
                          value: 'leave',
                          label: Text('Leave'),
                          icon: Icon(Icons.beach_access, color: Colors.orange),
                        ),
                      ],
                      selected: status != null ? {status} : <String>{},
                      onSelectionChanged: (Set<String> newSelection) {
                        if (newSelection.isNotEmpty) {
                          _markStatusForIntern(intern, newSelection.first);
                        }
                      },
                    ),
                  ],
                ),
              ),
            );
          }),

          const SizedBox(height: 20),

          // Attendance History for Selected Intern
          if (_selectedInternship != null) ...[
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Attendance History: ${_selectedInternship!.studentName}',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (_loadingHistory)
                  const SizedBox(
                    height: 16,
                    width: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 8),

            // Attendance Summary Chips
            Row(
              children: [
                Expanded(
                  child: _summaryChip(
                    'Total Days',
                    summary.totalDays.toString(),
                    Colors.blueGrey,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryChip(
                    'Present',
                    summary.presentDays.toString(),
                    Colors.green,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryChip(
                    'Absent',
                    summary.absentDays.toString(),
                    Colors.red,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _summaryChip(
                    'Rate',
                    '${summary.attendancePercentage.toStringAsFixed(0)}%',
                    Colors.teal,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            if (_selectedRecords.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(20),
                  child: Center(
                    child: Text(
                      'No attendance records logged yet for this intern.',
                    ),
                  ),
                ),
              )
            else
              ..._selectedRecords.map(
                (r) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    leading: Icon(
                      r.status.toLowerCase() == 'present'
                          ? Icons.check_circle
                          : r.status.toLowerCase() == 'leave'
                          ? Icons.beach_access
                          : Icons.cancel,
                      color: r.status.toLowerCase() == 'present'
                          ? Colors.green
                          : r.status.toLowerCase() == 'leave'
                          ? Colors.orange
                          : Colors.red,
                    ),
                    title: Text(
                      '${_formatDate(r.date)} — ${r.status.toUpperCase()}',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      'Marked by: ${r.markedByName ?? r.markedBy ?? "Company Supervisor"}',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                ),
              ),
          ],
        ],
      ],
    );
  }

  Widget _summaryChip(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: color.withAlpha(25),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withAlpha(80)),
      ),
      child: Column(
        children: [
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
          ),
        ],
      ),
    );
  }
}
