// Regression for the recovered PR#4 fix (network_image.dart): AppNetworkImage
// used CachedNetworkImage's default cache manager, which has NO request
// timeout, so a hanging fetch (dead CDN, stalled connection) spun the loading
// placeholder forever instead of ever falling back to the error placeholder.
//
// The production fix wraps the cache manager's http client in a private
// `_TimeoutHttpClient` (network_image.dart) that calls `.timeout(20s)` on
// every send(). That class is private to its library and the real duration is
// far too long for a fast test, so this proves the exact MECHANISM it relies
// on: a `http.BaseClient.send()` wrapped in `Future.timeout()` surfaces a
// `TimeoutException` instead of hanging, using a fake inner client that never
// completes and a short duration.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart' as http_testing;

class _TimeoutHttpClient extends http.BaseClient {
  _TimeoutHttpClient(this._inner, this._timeout);

  final http.Client _inner;
  final Duration _timeout;

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      _inner.send(request).timeout(_timeout);
}

void main() {
  test('a request that never completes times out instead of hanging', () async {
    final hanging = http_testing.MockClient(
      (_) => Completer<void>().future.then((_) => http.Response('never', 200)),
    );
    final client = _TimeoutHttpClient(
      hanging,
      const Duration(milliseconds: 30),
    );

    await expectLater(
      client.send(http.Request('GET', Uri.parse('https://example.com/x'))),
      throwsA(isA<TimeoutException>()),
    );
  });

  test('a request that completes in time is unaffected', () async {
    final fast = http_testing.MockClient((_) async => http.Response('ok', 200));
    final client = _TimeoutHttpClient(fast, const Duration(seconds: 20));

    final response = await http.Response.fromStream(
      await client.send(
        http.Request('GET', Uri.parse('https://example.com/x')),
      ),
    );
    expect(response.statusCode, 200);
    expect(response.body, 'ok');
  });
}
