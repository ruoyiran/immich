import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/domain/models/store.model.dart';
import 'package:immich_mobile/domain/services/store.service.dart';
import 'package:immich_mobile/entities/store.entity.dart';
import 'package:immich_mobile/infrastructure/repositories/db.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/network.repository.dart';
import 'package:immich_mobile/infrastructure/repositories/store.repository.dart';
import 'package:immich_mobile/services/api.service.dart';

void main() {
  setUpAll(() async {
    final db = Drift(DatabaseConnection(NativeDatabase.memory(), closeStreamsSynchronously: true));
    await StoreService.init(storeRepository: DriftStoreRepository(db));
  });

  test('native HTTP client keeps production-sized sync streams alive while idle', () {
    expect(NetworkRepository.readTimeout, const Duration(minutes: 30));
  });

  test('native client bootstrap reuses the persisted session token', () async {
    await Store.put(StoreKey.accessToken, 'session-token');

    expect(ApiService.nativeAccessToken, 'session-token');
  });
}
