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
  final String? internshipId;
  final String? studentId;
  final String? studentName;
  final String? docType; // 'offer_letter' | 'certificate' | 'other'
  final String fileName;
  final String filePath;
  final String? fileUrl;
  final String status; // 'pending' | 'verified' | 'rejected'
  final String? rejectionReason;
  final String? remarks;
  final String? verifiedBy;
  final String? verifiedByName;
  final DateTime? verifiedAt;
  final String facultyStatus; // 'pending' | 'verified' | 'rejected'
  final String? facultyRejectionReason;
  final String? facultyRemarks;
  final String? facultyVerifiedBy;
  final String? facultyVerifiedByName;
  final DateTime? facultyVerifiedAt;
  final DateTime createdAt;

  const InternshipDocument({
    required this.id,
    this.internshipId,
    this.studentId,
    this.studentName,
    this.docType,
    required this.fileName,
    required this.filePath,
    this.fileUrl,
    this.status = 'pending',
    this.rejectionReason,
    this.remarks,
    this.verifiedBy,
    this.verifiedByName,
    this.verifiedAt,
    this.facultyStatus = 'pending',
    this.facultyRejectionReason,
    this.facultyRemarks,
    this.facultyVerifiedBy,
    this.facultyVerifiedByName,
    this.facultyVerifiedAt,
    required this.createdAt,
  });

  InternshipDocument copyWith({
    String? id,
    String? internshipId,
    String? studentId,
    String? studentName,
    String? docType,
    String? fileName,
    String? filePath,
    String? fileUrl,
    String? status,
    String? rejectionReason,
    String? remarks,
    String? verifiedBy,
    String? verifiedByName,
    DateTime? verifiedAt,
    String? facultyStatus,
    String? facultyRejectionReason,
    String? facultyRemarks,
    String? facultyVerifiedBy,
    String? facultyVerifiedByName,
    DateTime? facultyVerifiedAt,
    DateTime? createdAt,
  }) {
    return InternshipDocument(
      id: id ?? this.id,
      internshipId: internshipId ?? this.internshipId,
      studentId: studentId ?? this.studentId,
      studentName: studentName ?? this.studentName,
      docType: docType ?? this.docType,
      fileName: fileName ?? this.fileName,
      filePath: filePath ?? this.filePath,
      fileUrl: fileUrl ?? this.fileUrl,
      status: status ?? this.status,
      rejectionReason: rejectionReason ?? this.rejectionReason,
      remarks: remarks ?? this.remarks,
      verifiedBy: verifiedBy ?? this.verifiedBy,
      verifiedByName: verifiedByName ?? this.verifiedByName,
      verifiedAt: verifiedAt ?? this.verifiedAt,
      facultyStatus: facultyStatus ?? this.facultyStatus,
      facultyRejectionReason:
          facultyRejectionReason ?? this.facultyRejectionReason,
      facultyRemarks: facultyRemarks ?? this.facultyRemarks,
      facultyVerifiedBy: facultyVerifiedBy ?? this.facultyVerifiedBy,
      facultyVerifiedByName:
          facultyVerifiedByName ?? this.facultyVerifiedByName,
      facultyVerifiedAt: facultyVerifiedAt ?? this.facultyVerifiedAt,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  factory InternshipDocument.fromMap(Map<String, dynamic> m) =>
      InternshipDocument(
        id: (m['id'] ?? '').toString(),
        internshipId: m['internship_id']?.toString(),
        studentId: m['student_id']?.toString(),
        studentName: m['student_name']?.toString(),
        docType: m['doc_type']?.toString(),
        fileName: (m['file_name'] ?? 'document.pdf').toString(),
        filePath: (m['file_path'] ?? '').toString(),
        fileUrl: m['file_url']?.toString(),
        status: (m['status'] ?? 'pending').toString(),
        rejectionReason: m['rejection_reason']?.toString(),
        remarks: m['remarks']?.toString(),
        verifiedBy: m['verified_by']?.toString(),
        verifiedByName: m['verified_by_name']?.toString(),
        verifiedAt: m['verified_at'] != null
            ? DateTime.tryParse(m['verified_at'].toString())?.toLocal()
            : null,
        facultyStatus: (m['faculty_status'] ?? 'pending').toString(),
        facultyRejectionReason: m['faculty_rejection_reason']?.toString(),
        facultyRemarks: m['faculty_remarks']?.toString(),
        facultyVerifiedBy: m['faculty_verified_by']?.toString(),
        facultyVerifiedByName: m['faculty_verified_by_name']?.toString(),
        facultyVerifiedAt: m['faculty_verified_at'] != null
            ? DateTime.tryParse(m['faculty_verified_at'].toString())?.toLocal()
            : null,
        createdAt: m['created_at'] != null
            ? (DateTime.tryParse(m['created_at'].toString()) ?? DateTime.now())
                .toLocal()
            : DateTime.now(),
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'internship_id': internshipId,
        'student_id': studentId,
        'student_name': studentName,
        'doc_type': docType,
        'file_name': fileName,
        'file_path': filePath,
        'file_url': fileUrl,
        'status': status,
        'rejection_reason': rejectionReason,
        'remarks': remarks,
        'verified_by': verifiedBy,
        'verified_by_name': verifiedByName,
        'verified_at': verifiedAt?.toIso8601String(),
        'faculty_status': facultyStatus,
        'faculty_rejection_reason': facultyRejectionReason,
        'faculty_remarks': facultyRemarks,
        'faculty_verified_by': facultyVerifiedBy,
        'faculty_verified_by_name': facultyVerifiedByName,
        'faculty_verified_at': facultyVerifiedAt?.toIso8601String(),
        'created_at': createdAt.toIso8601String(),
      };
}
