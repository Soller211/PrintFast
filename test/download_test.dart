import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:printfast/adobe_fetch.dart';

void main() {
  test('download gives up on a server that stalls mid-response', () async {
    final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((req) {
      req.response
        ..contentLength = 1000
        ..write('%PDF-1.7'); // headers + a few bytes, then never finishes
      req.response.flush();
    });
    final tmp = await Directory.systemTemp.createTemp('printfast_dl');
    addTearDown(() async {
      await server.close(force: true);
      await tmp.delete(recursive: true);
    });

    await expectLater(
      download('http://127.0.0.1:${server.port}/x.pdf', '${tmp.path}/x.pdf', timeout: const Duration(seconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
  }, timeout: const Timeout(Duration(seconds: 10)));
}
