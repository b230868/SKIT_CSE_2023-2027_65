import 'dart:typed_data';

import 'package:prashikshan/features/industry/data/models/evaluation_model.dart';

import '../models/itr_model.dart';
import 'itr_repository.dart';

class MockItrRepository implements ItrRepository {
  final List<ItrModel> _itrs = [
    ItrModel(
      id: 'itr-001',
      internshipId: 'internship-001',
      studentId: 'student-001',
      studentName: 'Rahul Sharma',
      internshipTitle: 'Software Development Intern',
      companyName: 'Demo Company',
      status: 'submitted',
      content: 'Completed internship project successfully.',
      workDone: 'Developed application features and implemented UI screens.',
      technologiesUsed: 'Flutter, Dart, Supabase',
      keyLearnings: 'State management, backend integration and teamwork.',
      challengesFaced:
          'Managing API integration and handling application states.',
      submittedAt: DateTime(2026, 8, 28),
      certificateStatus: 'pending',
    ),
    ItrModel(
      id: 'itr-002',
      internshipId: 'internship-002',
      studentId: 'student-002',
      studentName: 'Priya Singh',
      internshipTitle: 'Data Analytics Intern',
      companyName: 'Analytics Company',
      status: 'under_review',
      content: 'Worked on data analysis and reporting.',
      workDone: 'Cleaned datasets and created analytical reports.',
      technologiesUsed: 'Python, Excel, SQL',
      keyLearnings: 'Data cleaning and business analysis.',
      challengesFaced: 'Handling incomplete datasets.',
      submittedAt: DateTime(2026, 8, 29),
      certificateStatus: 'verified',
      evaluationScore: 90.0,
      evaluationGrade: 'A+',
    ),
    const ItrModel(
      id: 'itr-003',
      internshipId: 'internship-003',
      studentId: 'student-003',
      studentName: 'Aman Verma',
      internshipTitle: 'Flutter Development Intern',
      companyName: 'Tech Company',
      status: 'draft',
      certificateStatus: 'pending',
    ),
  ];

  final Map<String, EvaluationModel> _evaluations = {
    'itr-002': EvaluationModel(
      id: 'eval-002',
      itrId: 'itr-002',
      internshipId: 'internship-002',
      studentId: 'student-002',
      evaluatorId: 'evaluator-001',
      evaluatorName: 'Industry Supervisor',
      technicalScore: 22,
      workQualityScore: 23,
      punctualityScore: 24,
      presentationScore: 21,
      remarks: 'Consistently delivered quality work throughout the internship.',
      certificateStatus: 'verified',
      evaluatedAt: DateTime(2026, 9, 1),
    ),
  };

  @override
  Future<List<ItrModel>> getItrs() async {
    return List.unmodifiable(_itrs);
  }

  @override
  Future<ItrModel?> getItrById(String id) async {
    try {
      return _itrs.firstWhere((itr) => itr.id == id);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> submitItr(ItrModel itr) async {
    final index = _itrs.indexWhere((item) => item.id == itr.id);

    if (index == -1) {
      _itrs.add(itr);
    } else {
      _itrs[index] = itr;
    }
  }

  @override
  Future<void> updateItrStatus(String id, String status) async {
    final index = _itrs.indexWhere((itr) => itr.id == id);

    if (index == -1) return;

    final existingItr = _itrs[index];

    _itrs[index] = existingItr.copyWith(status: status);
  }

  @override
  Future<String> uploadProjectZip({
    required String itrId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final index = _itrs.indexWhere((itr) => itr.id == itrId);
    final path = 'mock/$itrId/project/$fileName';

    if (index != -1) {
      final existingItr = _itrs[index];
      _itrs[index] = existingItr.copyWith(projectZipPath: path);
    }

    return path;
  }

  @override
  Future<String> uploadProjectPresentation({
    required String itrId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final index = _itrs.indexWhere((itr) => itr.id == itrId);
    final path = 'mock/$itrId/presentation/$fileName';

    if (index != -1) {
      final existingItr = _itrs[index];
      _itrs[index] = existingItr.copyWith(presentationPath: path);
    }

    return path;
  }

  @override
  Future<String> uploadCertificate({
    required String itrId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    final index = _itrs.indexWhere((itr) => itr.id == itrId);
    final path = 'mock/$itrId/certificate/$fileName';

    if (index != -1) {
      final existingItr = _itrs[index];
      _itrs[index] = existingItr.copyWith(
        certificateUrl: path,
        certificateStatus: existingItr.certificateStatus ?? 'pending',
      );
    }

    return path;
  }

  @override
  Future<String?> getFileUrl(String filePath) async {
    return 'https://example.com/mock-storage/$filePath';
  }

  @override
  Future<void> deleteFile(String filePath) async {}

  @override
  Future<List<ItrModel>> getIndustryItrs() async {
    return List.unmodifiable(_itrs);
  }

  @override
  Future<ItrModel?> getItrByInternshipId(String internshipId) async {
    try {
      return _itrs.firstWhere(
        (itr) =>
            itr.internshipId == internshipId ||
            itr.internshipId == 'internship-$internshipId' ||
            itr.internshipId.endsWith(internshipId),
      );
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> reviewItr({
    required String itrId,
    required String status,
    required String remarks,
    String? reviewerName,
  }) async {
    final index = _itrs.indexWhere((itr) => itr.id == itrId);
    if (index == -1) return;

    final existing = _itrs[index];
    _itrs[index] = existing.copyWith(
      status: status,
      remarks: remarks,
      reviewerName:
          reviewerName ?? existing.reviewerName ?? 'Industry Supervisor',
    );
  }

  @override
  Future<void> saveEvaluation(EvaluationModel evaluation) async {
    _evaluations[evaluation.itrId] = evaluation;
    final index = _itrs.indexWhere((itr) => itr.id == evaluation.itrId);
    if (index != -1) {
      final existing = _itrs[index];
      _itrs[index] = existing.copyWith(
        evaluationScore: evaluation.totalScore,
        evaluationGrade: evaluation.grade,
        certificateStatus: evaluation.certificateStatus,
      );
    }
  }

  @override
  Future<EvaluationModel?> getEvaluationByItrId(String itrId) async {
    return _evaluations[itrId];
  }

  @override
  Future<void> updateCertificateStatus({
    required String itrId,
    required String status,
    String? certificateUrl,
  }) async {
    final index = _itrs.indexWhere((itr) => itr.id == itrId);
    if (index != -1) {
      final existing = _itrs[index];
      _itrs[index] = existing.copyWith(
        certificateStatus: status,
        certificateUrl: certificateUrl ?? existing.certificateUrl,
      );
    }

    final eval = _evaluations[itrId];
    if (eval != null) {
      _evaluations[itrId] = eval.copyWith(
        certificateStatus: status,
        certificateVerifiedAt: status == 'verified' ? DateTime.now() : null,
      );
    }
  }
}
