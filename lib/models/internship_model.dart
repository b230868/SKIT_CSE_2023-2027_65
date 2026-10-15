class Internship {
  final String? id;
  final String studentId;
  final String companyName;
  final String role;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final DateTime? createdAt;

  const Internship({
    this.id,
    required this.studentId,
    required this.companyName,
    required this.role,
    required this.startDate,
    required this.endDate,
    this.status = 'pending',
    this.createdAt,
  });

  factory Internship.fromMap(Map<String, dynamic> map) {
    return Internship(
      id: map['id']?.toString(),
      studentId: map['student_id']?.toString() ?? '',
      companyName: map['company_name']?.toString() ?? '',
      role: map['role']?.toString() ?? '',
      startDate: DateTime.parse(map['start_date'].toString()),
      endDate: DateTime.parse(map['end_date'].toString()),
      status: map['status']?.toString() ?? 'pending',
      createdAt: map['created_at'] == null
          ? null
          : DateTime.tryParse(map['created_at'].toString()),
    );
  }

  Map<String, dynamic> toMap() => {
        if (id != null) 'id': id,
        'student_id': studentId,
        'company_name': companyName,
        'role': role,
        'start_date': _dateOnly(startDate),
        'end_date': _dateOnly(endDate),
        'status': status,
      };

  static String _dateOnly(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-'
      '${date.month.toString().padLeft(2, '0')}-'
      '${date.day.toString().padLeft(2, '0')}';
}
