import 'dart:typed_data';

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
    ),
    const ItrModel(
      id: 'itr-003',
      internshipId: 'internship-003',
      studentId: 'student-003',
      studentName: 'Aman Verma',
      internshipTitle: 'Flutter Development Intern',
      companyName: 'Tech Company',
      status: 'draft',
    ),
  ];

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

    _itrs[index] = ItrModel(
      id: existingItr.id,
      internshipId: existingItr.internshipId,
      studentId: existingItr.studentId,
      studentName: existingItr.studentName,
      internshipTitle: existingItr.internshipTitle,
      companyName: existingItr.companyName,
      status: status,
      content: existingItr.content,
      workDone: existingItr.workDone,
      technologiesUsed: existingItr.technologiesUsed,
      keyLearnings: existingItr.keyLearnings,
      challengesFaced: existingItr.challengesFaced,
      documentPath: existingItr.documentPath,
      projectZipPath: existingItr.projectZipPath,
      presentationPath: existingItr.presentationPath,
      submittedAt: existingItr.submittedAt,
      reviewerName: existingItr.reviewerName,
      remarks: existingItr.remarks,
    );
  }

  @override
  Future<String> uploadProjectZip({
    required String itrId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    return 'mock/$itrId/project/$fileName';
  }

  @override
  Future<String> uploadProjectPresentation({
    required String itrId,
    required String fileName,
    required Uint8List fileBytes,
  }) async {
    return 'mock/$itrId/presentation/$fileName';
  }

  @override
  Future<String?> getFileUrl(String filePath) async {
    return filePath;
  }

  @override
  Future<void> deleteFile(String filePath) async {}
}
