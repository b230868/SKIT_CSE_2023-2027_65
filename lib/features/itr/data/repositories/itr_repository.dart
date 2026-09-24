import 'dart:typed_data';

import '../models/itr_model.dart';

abstract class ItrRepository {
  Future<List<ItrModel>> getItrs();

  Future<ItrModel?> getItrById(String id);

  Future<void> submitItr(ItrModel itr);

  Future<void> updateItrStatus(String id, String status);

  Future<String> uploadProjectZip({
    required String itrId,
    required String fileName,
    required Uint8List fileBytes,
  });

  Future<String> uploadProjectPresentation({
    required String itrId,
    required String fileName,
    required Uint8List fileBytes,
  });

  Future<String?> getFileUrl(String filePath);

  Future<void> deleteFile(String filePath);
}
