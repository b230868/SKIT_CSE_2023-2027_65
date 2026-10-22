import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:prashikshan/core/storage/cache_service.dart';

void main() {
  late Directory hiveDirectory;

  setUp(() async {
    hiveDirectory = await Directory.systemTemp.createTemp('offline-cache-');
    Hive.init(hiveDirectory.path);
    await CacheService.init();
  });

  tearDown(() async {
    await Hive.close();
    await hiveDirectory.delete(recursive: true);
  });

  test('persists data separately for each signed-in owner', () async {
    await CacheService.cacheData(
      ownerId: 'owner-a',
      key: 'internships',
      data: [
        {'id': 'internship-a', 'title': 'Cached internship'},
      ],
    );

    expect(CacheService.getCachedData(ownerId: 'owner-a', key: 'internships'), [
      {'id': 'internship-a', 'title': 'Cached internship'},
    ]);
    expect(
      CacheService.getCachedData(ownerId: 'owner-b', key: 'internships'),
      isNull,
    );
  });

  test('clears only the selected owner cache', () async {
    await CacheService.cacheData(
      ownerId: 'owner-a',
      key: 'internships',
      data: ['private record'],
    );
    await CacheService.cacheData(
      ownerId: 'owner-b',
      key: 'internships',
      data: ['other record'],
    );

    await CacheService.clearOwnerCache('owner-a');

    expect(
      CacheService.getCachedData(ownerId: 'owner-a', key: 'internships'),
      isNull,
    );
    expect(CacheService.getCachedData(ownerId: 'owner-b', key: 'internships'), [
      'other record',
    ]);
  });
}
