class Internship {
  final String id;
  final String studentId;
  final String companyName;
  final String title;
  final String? description;
  final String mode; // onsite | remote | hybrid
  final DateTime startDate;
  final DateTime endDate;
  final String status; // pending | approved | rejected | completed
  final int progress; // 0..100
  final DateTime createdAt;

  const Internship({
    required this.id,
    required this.studentId,
    required this.companyName,
    required this.title,
    this.description,
    required this.mode,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.progress,
    required this.createdAt,
  });

  factory Internship.fromMap(Map<String, dynamic> m) {
    return Internship(
      id: m['id'] as String,
      studentId: m['student_id'] as String,
      companyName: m['company_name'] as String,
      title: m['title'] as String,
      description: m['description'] as String?,
      mode: (m['mode'] ?? 'onsite') as String,
      startDate: DateTime.parse(m['start_date'] as String),
      endDate: DateTime.parse(m['end_date'] as String),
      status: (m['status'] ?? 'pending') as String,
      progress: (m['progress'] ?? 0) as int,
      createdAt: DateTime.parse(m['created_at'] as String),
    );
  }

  bool get isEditable => status == 'pending';
}

class ProgressUpdate {
  final String id;
  final String note;
  final int percent;
  final DateTime createdAt;

  const ProgressUpdate({
    required this.id,
    required this.note,
    required this.percent,
    required this.createdAt,
  });

  factory ProgressUpdate.fromMap(Map<String, dynamic> m) => ProgressUpdate(
        id: m['id'] as String,
        note: m['note'] as String,
        percent: m['percent'] as int,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}

class InternshipDocument {
  final String id;
  final String fileName;
  final String filePath;
  final DateTime createdAt;

  const InternshipDocument({
    required this.id,
    required this.fileName,
    required this.filePath,
    required this.createdAt,
  });

  factory InternshipDocument.fromMap(Map<String, dynamic> m) =>
      InternshipDocument(
        id: m['id'] as String,
        fileName: m['file_name'] as String,
        filePath: m['file_path'] as String,
        createdAt: DateTime.parse(m['created_at'] as String).toLocal(),
      );
}
