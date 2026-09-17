import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../integration_test/test_utils/fake_immich_server.dart';

void main() {
  test('disconnect interrupts a partial response without closing the server', () async {
    final server = await FakeImmichServer.start();
    final client = HttpClient();
    try {
      final request = await client.postUrl(Uri.parse('${server.endpoint}/sync/stream'));
      final responseFuture = request.close();
      final stream = await server.streamOpened;
      stream.send(type: 'probe', data: {'id': 1}, ack: 'first');
      final response = await responseFuture;
      final failed = expectLater(response.drain<void>(), throwsA(isA<HttpException>()));
      stream.disconnect();
      await failed;

      final retry = await client.postUrl(Uri.parse('${server.endpoint}/sync/stream'));
      final retriedResponse = retry.close();
      final replacement = await server.streamOpenedNth(2);
      replacement.send(type: 'probe', data: {'id': 2}, ack: 'replacement');
      await replacement.close();
      final body = await utf8.decoder.bind(await retriedResponse).join();
      expect(body, contains('replacement'));
      expect(server.streamOpenCount, 2);
    } finally {
      client.close(force: true);
      await server.close();
    }
  }, timeout: const Timeout(Duration(seconds: 10)));
}
