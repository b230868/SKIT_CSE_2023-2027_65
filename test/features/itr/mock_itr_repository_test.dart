import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:prashikshan/features/itr/data/models/itr_model.dart';
import 'package:prashikshan/features/itr/data/repositories/itr_repository_provider.dart';
import 'package:prashikshan/features/itr/data/repositories/mock_itr_repository.dart';
import 'package:prashikshan/features/itr/data/services/itr_service.dart';

void main() {
  group('MockItrRepository & ItrService Tests', () {
    late MockItrRepository mockRepo;
    late ItrService service;

    setUp(() {
      mockRepo = MockItrRepository();
      ItrRepositoryProvider.setInstance(mockRepo);
      service = ItrService(mockRepo);
    });

    tearDown(() {
      ItrRepositoryProvider.reset();
    });

    test('getItrs returns mock ITR list', () async {
      final list = await service.getItrs();
      expect(list.length, equals(3));
      expect(list[0].id, equals('itr-001'));
      expect(list[0].studentName, equals('Rahul Sharma'));
    });

    test('getItrById returns correct item or null', () async {
      final found = await service.getItrById('itr-001');
      expect(found, isNotNull);
      expect(found!.internshipTitle, equals('Software Development Intern'));

      final notFound = await service.getItrById('non-existent');
      expect(notFound, isNull);
    });

    test('getItrByInternshipId returns matching ITR', () async {
      final found = await service.getItrByInternshipId('internship-001');
      expect(found, isNotNull);
      expect(found!.id, equals('itr-001'));
    });

    test('submitItr adds new or updates existing record', () async {
      final newItr = ItrModel(
        id: 'itr-new',
        internshipId: 'int-new',
        studentId: 'stud-new',
        studentName: 'New Student',
        internshipTitle: 'Cloud Intern',
        companyName: 'Cloud Solutions',
        status: 'submitted',
        workDone: 'Configured cloud infrastructure.',
      );

      await service.submitItr(newItr);
      final retrieved = await service.getItrById('itr-new');
      expect(retrieved, isNotNull);
      expect(retrieved!.workDone, equals('Configured cloud infrastructure.'));
    });

    test(
      'reviewItr updates status, remarks, and reviewer attribution',
      () async {
        await service.reviewItr(
          itrId: 'itr-001',
          status: 'approved',
          remarks: 'Excellent technical work and clean reporting.',
          reviewerName: 'Lead Supervisor',
        );

        final updated = await service.getItrById('itr-001');
        expect(updated, isNotNull);
        expect(updated!.status, equals('approved'));
        expect(
          updated.remarks,
          equals('Excellent technical work and clean reporting.'),
        );
        expect(updated.reviewerName, equals('Lead Supervisor'));
      },
    );

    test(
      'uploadProjectZip and uploadProjectPresentation return mock paths',
      () async {
        final bytes = Uint8List.fromList([1, 2, 3, 4]);
        final zipPath = await service.uploadProjectZip(
          itrId: 'itr-001',
          fileName: 'code.zip',
          fileBytes: bytes,
        );
        expect(zipPath, equals('mock/itr-001/project/code.zip'));

        final pptPath = await service.uploadProjectPresentation(
          itrId: 'itr-001',
          fileName: 'slides.pptx',
          fileBytes: bytes,
        );
        expect(pptPath, equals('mock/itr-001/presentation/slides.pptx'));
      },
    );

    test('ItrRepositoryProvider allows setting and resetting instances', () {
      final customRepo = MockItrRepository();
      ItrRepositoryProvider.setInstance(customRepo);
      expect(ItrRepositoryProvider.instance, equals(customRepo));

      ItrRepositoryProvider.reset();
      expect(ItrRepositoryProvider.instance, isNot(equals(customRepo)));
    });
  });
}
