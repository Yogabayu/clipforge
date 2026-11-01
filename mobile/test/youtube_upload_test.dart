import 'package:clipforge_mobile/download_controller.dart';
import 'package:clipforge_mobile/download_models.dart';
import 'package:clipforge_mobile/rendered_clip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final clip = StudioClip.fromMap({
    'name': 'clip.mp4',
    'title': 'My clip',
    'path': '/local/clip.mp4',
    'bytes': 1024,
    'durationMs': 2000,
  });
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(DownloadController.methods, null),
  );

  test(
    'YouTube handoff sends clip identity, not an arbitrary file path',
    () async {
      MethodCall? sent;
      messenger.setMockMethodCallHandler(DownloadController.methods, (
        call,
      ) async {
        sent = call;
        return null;
      });
      final controller = DownloadController();
      expect(await controller.openYouTubeUpload('source', clip), isTrue);
      expect(sent!.method, 'openYouTubeUpload');
      expect(sent!.arguments, {
        'id': 'source',
        'name': 'clip.mp4',
        'title': 'My clip',
      });
      controller.dispose();
    },
  );
  test(
    'unavailable receiving app is not reported as an upload success',
    () async {
      messenger.setMockMethodCallHandler(DownloadController.methods, (_) async {
        throw PlatformException(
          code: 'NO_APP',
          message: 'Pasang YouTube dahulu.',
        );
      });
      final controller = DownloadController();
      expect(await controller.openYouTubeUpload('source', clip), isFalse);
      expect(controller.error, 'Pasang YouTube dahulu.');
      expect(controller.pending, isFalse);
      controller.dispose();
    },
  );
  testWidgets('render card exposes YouTube upload action', (tester) async {
    var opened = 0;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RenderedClipCard(
            clip: clip,
            isNew: true,
            onPreview: () {},
            onUpload: () => opened++,
          ),
        ),
      ),
    );
    await tester.tap(find.text('Upload ke YouTube'));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });
}
