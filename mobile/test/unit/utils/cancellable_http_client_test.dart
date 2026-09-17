import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';
import 'package:immich_mobile/utils/cancellable_http_client.dart';

void main() {
  late HttpServer server;
  late IOClient shared;

  Uri endpoint(String path) => Uri.parse('http://${server.address.host}:${server.port}$path');

  setUp(() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    shared = IOClient();
  });

  tearDown(() async {
    shared.close();
    await server.close(force: true);
  });

  test('cancellation aborts a stalled version response without closing the shared client', () async {
    final received = Completer<void>();
    server.listen((request) {
      if (request.uri.path == '/server/version') {
        received.complete();
      } else {
        request.response.write('healthy');
        unawaited(request.response.close());
      }
    });
    final cancellation = Completer<void>();
    final client = CancellableHttpClient(shared, cancellation.future);
    final response = client.get(endpoint('/server/version'));
    final assertion = expectLater(
      response.timeout(const Duration(seconds: 3)),
      throwsA(isA<http.RequestAbortedException>()),
    );
    await received.future;

    cancellation.complete();
    await assertion;
    client.close();

    expect((await shared.get(endpoint('/healthy'))).body, 'healthy');
  });

  test('cancellation aborts a stalled ack response after its request body was sent', () async {
    final body = Completer<String>();
    server.listen((request) async {
      body.complete(await utf8.decoder.bind(request).join());
    });
    final cancellation = Completer<void>();
    final client = CancellableHttpClient(shared, cancellation.future);
    final response = client.post(
      endpoint('/sync/ack'),
      headers: {'Authorization': 'Bearer session', 'Content-Type': 'application/json'},
      body: '{"ack":"batch-42"}',
    );
    final assertion = expectLater(
      response.timeout(const Duration(seconds: 3)),
      throwsA(isA<http.RequestAbortedException>()),
    );
    expect(await body.future, '{"ack":"batch-42"}');

    cancellation.complete();

    await assertion;
  });

  test('cancellation interrupts an already streaming response body', () async {
    server.listen((request) async {
      request.response.bufferOutput = false;
      request.response.contentLength = 2;
      request.response.add([1]);
      await request.response.flush();
    });
    final cancellation = Completer<void>();
    final client = CancellableHttpClient(shared, cancellation.future);
    final response = await client.send(http.Request('GET', endpoint('/sync/ack')));
    final firstByte = Completer<void>();
    final bytes = <int>[];
    final reading = response.stream.listen((chunk) {
      bytes.addAll(chunk);
      if (!firstByte.isCompleted) {
        firstByte.complete();
      }
    }).asFuture<void>();
    final assertion = expectLater(
      reading.timeout(const Duration(seconds: 3)),
      throwsA(isA<http.RequestAbortedException>()),
    );
    await firstByte.future.timeout(const Duration(seconds: 2));
    expect(bytes, [1]);

    cancellation.complete();

    await assertion;
  });

  for (final ownerCancels in [false, true]) {
    test('preserves both request and owner abort signals (owner: $ownerCancels)', () async {
      final received = Completer<void>();
      server.listen((_) => received.complete());
      final cancellation = Completer<void>();
      final requestCancellation = Completer<void>();
      final client = CancellableHttpClient(shared, cancellation.future);
      final response = client.send(
        http.AbortableRequest('GET', endpoint('/sync/ack'), abortTrigger: requestCancellation.future),
      );
      final assertion = expectLater(
        response.timeout(const Duration(seconds: 3)),
        throwsA(isA<http.RequestAbortedException>()),
      );
      await received.future;

      (ownerCancels ? cancellation : requestCancellation).complete();

      await assertion;
    });
  }

  test('preserves body bytes, authorization, length, and connection behavior', () async {
    final received = Completer<(HttpRequest, List<int>)>();
    server.listen((request) async {
      final body = await request.fold<List<int>>([], (bytes, chunk) => bytes..addAll(chunk));
      received.complete((request, body));
      request.response.statusCode = 302;
      request.response.headers.set(HttpHeaders.locationHeader, '/redirected');
      await request.response.close();
    });
    final client = CancellableHttpClient(shared, Completer<void>().future);
    final request = http.Request('POST', endpoint('/sync/ack'))
      ..bodyBytes = [0, 1, 127, 255]
      ..headers['authorization'] = 'Bearer session'
      ..headers['x-custom-header'] = 'custom-value'
      ..followRedirects = false
      ..maxRedirects = 2
      ..persistentConnection = false;

    final response = await client.send(request);
    final (sent, body) = await received.future;

    expect(response.statusCode, 302);
    expect(body, [0, 1, 127, 255]);
    expect(sent.headers.value(HttpHeaders.authorizationHeader), 'Bearer session');
    expect(sent.headers.value('x-custom-header'), 'custom-value');
    expect(sent.contentLength, 4);
    expect(sent.persistentConnection, isFalse);
    expect(response.request!.maxRedirects, 2);
    await response.stream.drain<void>();
  });

  test('copies multipart headers after finalization chooses the boundary', () async {
    final received = Completer<(ContentType?, String)>();
    server.listen((request) async {
      received.complete((request.headers.contentType, await latin1.decoder.bind(request).join()));
      await request.response.close();
    });
    final client = CancellableHttpClient(shared, Completer<void>().future);
    final request = http.MultipartRequest('POST', endpoint('/upload'))
      ..fields['description'] = 'test value'
      ..files.add(http.MultipartFile.fromBytes('file', [0, 1, 255], filename: 'photo.bin'));

    final response = await client.send(request);
    final (contentType, body) = await received.future;

    expect(contentType?.mimeType, 'multipart/form-data');
    final boundary = contentType?.parameters['boundary'];
    expect(boundary, isNotNull);
    expect(body, startsWith('--$boundary\r\n'));
    expect(body, contains('name="description"\r\n\r\ntest value\r\n'));
    expect(body, contains('filename="photo.bin"'));
    expect(body, contains(latin1.decode([0, 1, 255])));
    expect(body, endsWith('--$boundary--\r\n'));
    await response.stream.drain<void>();
  });
}
