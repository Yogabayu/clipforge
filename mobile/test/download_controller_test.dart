import 'dart:async';

import 'package:clipforge_mobile/download_controller.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(DownloadController.methods, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('clipforge/events'),
      null,
    );
  });

  test(
    'duplicate start is suppressed while platform acknowledgement is pending',
    () async {
      final ack = Completer<String>();
      var starts = 0;
      messenger.setMockMethodCallHandler(DownloadController.methods, (
        call,
      ) async {
        expect(call.method, 'start');
        expect(call.arguments, {'url': 'https://youtu.be/BaW_jenozKc'});
        starts++;
        return ack.future;
      });
      final controller = DownloadController();
      final first = controller.start(' https://youtu.be/BaW_jenozKc ');
      await controller.start('https://youtu.be/BaW_jenozKc');
      ack.complete('id');
      await first;
      expect(starts, 1);
      expect(controller.pending, isFalse);
      controller.dispose();
    },
  );

  test('native errors remain visible and release pending lock', () async {
    messenger.setMockMethodCallHandler(DownloadController.methods, (_) async {
      throw PlatformException(
        code: 'CLIPFORGE',
        message: 'URL YouTube tidak valid.',
      );
    });
    final controller = DownloadController();
    await controller.start('invalid');
    expect(controller.error, 'URL YouTube tidak valid.');
    expect(controller.pending, isFalse);
    controller.dispose();
  });

  test('cancelled document picker does not report file saved', () async {
    messenger.setMockMethodCallHandler(
      DownloadController.methods,
      (_) async => false,
    );
    final controller = DownloadController();
    expect(await controller.saveVideo('id'), isFalse);
    controller.dispose();
  });
}
