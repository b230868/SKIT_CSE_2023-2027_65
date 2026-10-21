class EvaluationModel {
  final String id;
  final String itrId;
  final String internshipId;
  final String studentId;
  final String evaluatorId;
  final String evaluatorName;

  final double technicalScore; // 0..25
  final double workQualityScore; // 0..25
  final double punctualityScore; // 0..25
  final double presentationScore; // 0..25

  final String remarks;
  final String certificateStatus; // pending | verified | rejected
  final DateTime? certificateVerifiedAt;
  final DateTime evaluatedAt;

  const EvaluationModel({
    required this.id,
    required this.itrId,
    required this.internshipId,
    required this.studentId,
    required this.evaluatorId,
    required this.evaluatorName,
    required this.technicalScore,
    required this.workQualityScore,
    required this.punctualityScore,
    required this.presentationScore,
    required this.remarks,
    this.certificateStatus = 'pending',
    this.certificateVerifiedAt,
    required this.evaluatedAt,
  });

  double get totalScore =>
      (technicalScore + workQualityScore + punctualityScore + presentationScore)
          .clamp(0.0, 100.0);

  String get grade {
    final score = totalScore;
    if (score >= 90) return 'A+';
    if (score >= 80) return 'A';
    if (score >= 70) return 'B';
    if (score >= 60) return 'C';
    if (score >= 50) return 'D';
    return 'F';
  }

  bool get isCertificateVerified => certificateStatus == 'verified';

  factory EvaluationModel.fromMap(Map<String, dynamic> map) {
    return EvaluationModel(
      id: map['id']?.toString() ?? '',
      itrId: map['itr_id']?.toString() ?? map['itrs_id']?.toString() ?? '',
      internshipId: map['internship_id']?.toString() ?? '',
      studentId: map['student_id']?.toString() ?? '',
      evaluatorId: map['evaluator_id']?.toString() ?? '',
      evaluatorName: map['evaluator_name']?.toString() ?? 'Industry Evaluator',
      technicalScore: (map['technical_score'] as num?)?.toDouble() ?? 0.0,
      workQualityScore: (map['work_quality_score'] as num?)?.toDouble() ?? 0.0,
      punctualityScore: (map['punctuality_score'] as num?)?.toDouble() ?? 0.0,
      presentationScore: (map['presentation_score'] as num?)?.toDouble() ?? 0.0,
      remarks: map['remarks']?.toString() ?? '',
      certificateStatus:
          map['certificate_status']?.toString() ??
          map['status']?.toString() ??
          'pending',
      certificateVerifiedAt: map['certificate_verified_at'] != null
          ? DateTime.tryParse(map['certificate_verified_at'].toString())
          : null,
      evaluatedAt: map['evaluated_at'] != null
          ? DateTime.tryParse(map['evaluated_at'].toString()) ?? DateTime.now()
          : (map['created_at'] != null
                ? DateTime.tryParse(map['created_at'].toString()) ??
                      DateTime.now()
                : DateTime.now()),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itr_id': itrId,
      'internship_id': internshipId,
      'student_id': studentId,
      'evaluator_id': evaluatorId,
      'evaluator_name': evaluatorName,
      'technical_score': technicalScore,
      'work_quality_score': workQualityScore,
      'punctuality_score': punctualityScore,
      'presentation_score': presentationScore,
      'total_score': totalScore,
      'grade': grade,
      'remarks': remarks,
      'certificate_status': certificateStatus,
      'certificate_verified_at': certificateVerifiedAt?.toIso8601String(),
      'evaluated_at': evaluatedAt.toIso8601String(),
    };
  }

  EvaluationModel copyWith({
    String? id,
    String? itrId,
    String? internshipId,
    String? studentId,
    String? evaluatorId,
    String? evaluatorName,
    double? technicalScore,
    double? workQualityScore,
    double? punctualityScore,
    double? presentationScore,
    String? remarks,
    String? certificateStatus,
    DateTime? certificateVerifiedAt,
    DateTime? evaluatedAt,
  }) {
    return EvaluationModel(
      id: id ?? this.id,
      itrId: itrId ?? this.itrId,
      internshipId: internshipId ?? this.internshipId,
      studentId: studentId ?? this.studentId,
      evaluatorId: evaluatorId ?? this.evaluatorId,
      evaluatorName: evaluatorName ?? this.evaluatorName,
      technicalScore: technicalScore ?? this.technicalScore,
      workQualityScore: workQualityScore ?? this.workQualityScore,
      punctualityScore: punctualityScore ?? this.punctualityScore,
      presentationScore: presentationScore ?? this.presentationScore,
      remarks: remarks ?? this.remarks,
      certificateStatus: certificateStatus ?? this.certificateStatus,
      certificateVerifiedAt:
          certificateVerifiedAt ?? this.certificateVerifiedAt,
      evaluatedAt: evaluatedAt ?? this.evaluatedAt,
    );
  }
}
