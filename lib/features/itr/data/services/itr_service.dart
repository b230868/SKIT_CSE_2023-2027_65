import 'dart:typed_data';

import '../models/itr_model.dart';
import '../repositories/itr_repository.dart';

class ItrService {
  final ItrRepository repository;

  ItrService(this.repository);

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
}
