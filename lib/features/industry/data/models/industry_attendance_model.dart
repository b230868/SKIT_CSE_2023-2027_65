class IndustryAttendanceRecord {
  final String id;
  final String internshipId;
  final String studentId;
  final String? studentName;
  final DateTime date;
  final String status; // 'present' | 'absent' | 'leave'
  final String? markedBy;
  final String? markedByName;
  final DateTime? markedAt;
  final String? remarks;

  const IndustryAttendanceRecord({
    required this.id,
    required this.internshipId,
    required this.studentId,
    this.studentName,
    required this.date,
    required this.status,
    this.markedBy,
    this.markedByName,
    this.markedAt,
    this.remarks,
  });

  factory IndustryAttendanceRecord.fromMap(Map<String, dynamic> map) {
    return IndustryAttendanceRecord(
      id: map['id']?.toString() ?? '',
      internshipId: map['internship_id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      studentName: map['student_name']?.toString(),
      date: map['date'] != null
          ? (DateTime.tryParse(map['date'].toString()) ?? DateTime.now())
          : DateTime.now(),
      status: map['status']?.toString() ?? 'present',
      markedBy: map['marked_by']?.toString(),
      markedByName: map['marked_by_name']?.toString(),
      markedAt: map['marked_at'] != null
          ? DateTime.tryParse(map['marked_at'].toString())
          : null,
      remarks: map['remarks']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'internship_id': internshipId,
      'student_id': studentId,
      'student_name': studentName,
      'date':
          '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}',
      'status': status,
      'marked_by': markedBy,
      'marked_by_name': markedByName,
      'marked_at': markedAt?.toIso8601String(),
      'remarks': remarks,
    };
  }

  IndustryAttendanceRecord copyWith({
    String? id,
    String? internshipId,
    String? studentId,
    String? studentName,
    DateTime? date,
    String? status,
    String? markedBy,
    String? markedByName,
    DateTime? markedAt,
    String? remarks,
  }) {
    return IndustryAttendanceRecord(
      id: id ?? this.id,
      internshipId: internshipId ?? this.internshipId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      date: date ?? this.date,
      status: status ?? this.status,
      markedBy: markedBy ?? this.markedBy,
      markedByName: markedByName ?? this.markedByName,
      markedAt: markedAt ?? this.markedAt,
      remarks: remarks ?? this.remarks,
    );
  }
}

class IndustryAttendanceSummary {
  final int totalDays;
  final int presentDays;
  final int absentDays;
  final int leaveDays;

  const IndustryAttendanceSummary({
    required this.totalDays,
    required this.presentDays,
    required this.absentDays,
    required this.leaveDays,
  });

  double get attendancePercentage =>
      totalDays > 0 ? (presentDays / totalDays) * 100 : 0.0;

  factory IndustryAttendanceSummary.fromRecords(
    List<IndustryAttendanceRecord> records,
  ) {
    int p = 0;
    int a = 0;
    int l = 0;
    for (final r in records) {
      final s = r.status.toLowerCase();
      if (s == 'present') {
        p++;
      } else if (s == 'absent') {
        a++;
      } else if (s == 'leave') {
        l++;
      }
    }
    return IndustryAttendanceSummary(
      totalDays: records.length,
      presentDays: p,
      absentDays: a,
      leaveDays: l,
    );
  }
}
