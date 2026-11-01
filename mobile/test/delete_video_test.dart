import 'package:clipforge_mobile/delete_video_dialog.dart';
import 'package:clipforge_mobile/download_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'source deletion explains cascade and waits for explicit confirmation',
    (tester) async {
      bool? confirmed;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () async {
                  confirmed = await confirmDeleteVideo(
                    context,
                    'My video',
                    source: true,
                  );
                },
                child: const Text('Delete'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(find.textContaining('semua klip render terkait'), findsOneWidget);
      expect(confirmed, isNull);
      await tester.tap(find.text('Batal'));
      await tester.pumpAndSettle();
      expect(confirmed, isFalse);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Hapus permanen'));
      await tester.pumpAndSettle();
      expect(confirmed, isTrue);
    },
  );

  test(
    'delete clip sends its exact identity and refreshes native state',
    () async {
      final calls = <MethodCall>[];
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(DownloadController.methods, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'deleteClip') return 1024;
        return {
          'history': [],
          'studio': {'id': 'source', 'clips': []},
        };
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          DownloadController.methods,
          null,
        ),
      );
      final controller = DownloadController();
      expect(await controller.deleteClip('source', 'clip.mp4'), 1024);
      expect(calls.first.arguments, {'id': 'source', 'name': 'clip.mp4'});
      expect(calls.last.method, 'snapshot');
      expect(controller.snapshot.studio.clips, isEmpty);
      expect(controller.pending, isFalse);
      controller.dispose();
    },
  );

  test(
    'native deletion refusal stays visible and does not report freed bytes',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      messenger.setMockMethodCallHandler(DownloadController.methods, (_) async {
        throw PlatformException(
          code: 'BUSY',
          message: 'Masih ada proses aktif.',
        );
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          DownloadController.methods,
          null,
        ),
      );
      final controller = DownloadController();
      expect(await controller.deleteDownload('source'), isNull);
      expect(controller.error, 'Masih ada proses aktif.');
      expect(controller.pending, isFalse);
      controller.dispose();
    },
  );
}
