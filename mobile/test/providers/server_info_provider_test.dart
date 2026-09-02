import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:immich_mobile/models/server_info/server_features.model.dart';
import 'package:immich_mobile/providers/server_info.provider.dart';
import 'package:mocktail/mocktail.dart';

import '../service.mocks.dart';

void main() {
  test('ignores server features returned after disposal', () async {
    final serverInfoService = MockServerInfoService();
    final serverFeatures = Completer<ServerFeatures?>();
    final notifier = ServerInfoNotifier(serverInfoService);

    when(() => serverInfoService.getServerFeatures()).thenAnswer((_) => serverFeatures.future);

    final pendingUpdate = notifier.getServerFeatures();
    notifier.dispose();
    serverFeatures.complete(const ServerFeatures(trash: true, map: true, oauthEnabled: false, passwordLogin: true));

    await expectLater(pendingUpdate, completes);
  });
}
