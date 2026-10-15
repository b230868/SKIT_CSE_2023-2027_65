import 'dart:typed_data';

import '../models/itr_model.dart';
import '../repositories/itr_repository.dart';
import '../repositories/itr_repository_provider.dart';

class ItrService {
  final ItrRepository repository;

  ItrService([ItrRepository? repo]) : repository = repo ?? itrRepository;

  Future<List<ItrModel>> getItrs() {
    return repository.getItrs();
  }

  Future<ItrModel?> getItrById(String id) {
    return repository.getItrById(id);
  }

  Future<void> submitItr(ItrModel itr) {
    return repository.submitItr(itr);
  }

  Future<void> updateItrStatus(String id, String status) {
    return repository.updateItrStatus(id, status);
  }

  Future<String> uploadProjectZip({
    required String itrId,
    required String fileName,
    required Uint8List fileBytes,
  }) {
    return repository.uploadProjectZip(
      itrId: itrId,
      fileName: fileName,
      fileBytes: fileBytes,
    );
  }

  Future<String> uploadProjectPresentation({
    required String itrId,
    required String fileName,
    required Uint8List fileBytes,
  }) {
    return repository.uploadProjectPresentation(
      itrId: itrId,
      fileName: fileName,
      fileBytes: fileBytes,
    );
  }

  Future<String?> getFileUrl(String filePath) {
    return repository.getFileUrl(filePath);
  }

  Future<void> deleteFile(String filePath) {
    return repository.deleteFile(filePath);
  }

  Future<List<ItrModel>> getIndustryItrs() {
    return repository.getIndustryItrs();
  }

  Future<ItrModel?> getItrByInternshipId(String internshipId) {
    return repository.getItrByInternshipId(internshipId);
  }

  Future<void> reviewItr({
    required String itrId,
    required String status,
    required String remarks,
    String? reviewerName,
  }) {
    return repository.reviewItr(
      itrId: itrId,
      status: status,
      remarks: remarks,
      reviewerName: reviewerName,
    );
  }
}
