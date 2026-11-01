import 'package:clipforge_mobile/download_controller.dart';
import 'package:clipforge_mobile/main.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'dart:io';
import 'dart:ui' as ui;

void main() {
  testWidgets('ready form fits narrow Android and submits URL', (tester) async {
    const sdk = String.fromEnvironment('PREVIEW_FLUTTER_SDK');
    if (sdk.isNotEmpty) {
      await tester.runAsync(() async {
        for (final family in ['Roboto', 'MaterialIcons']) {
          final loader = FontLoader(family);
          final names = family == 'Roboto'
              ? ['Roboto-Regular.ttf', 'Roboto-Bold.ttf']
              : ['MaterialIcons-Regular.otf'];
          for (final name in names) {
            loader.addFont(
              File('$sdk/bin/cache/artifacts/material_fonts/$name')
                  .readAsBytes()
                  .then(ByteData.sublistView),
            );
          }
          await loader.load();
        }
      });
    }
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    String? submitted;
    messenger.setMockMethodCallHandler(DownloadController.methods, (
      call,
    ) async {
      if (call.method == 'start') {
        submitted = (call.arguments as Map)['url'] as String;
        return 'id';
      }
      return {
        'engine': {
          'ready': true,
          'message': 'yt-dlp 2026.10.26 · QuickJS + EJS · FFmpeg',
        },
        'history': [],
      };
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('clipforge/events'),
      (_) async => null,
    );
    await tester.pumpWidget(
      const RepaintBoundary(key: Key('ui-preview'), child: ClipForgeApp()),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.byKey(const Key('download-button')))
          .onPressed,
      isNotNull,
    );
    if (const bool.fromEnvironment('WRITE_UI_PREVIEW')) {
      final boundary = tester.renderObject<RenderRepaintBoundary>(
        find.byKey(const Key('ui-preview')),
      );
      await tester.runAsync(() async {
        final image = await boundary.toImage(pixelRatio: 2);
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        final file = File('build/review/downloader.png');
        await file.parent.create(recursive: true);
        await file.writeAsBytes(bytes!.buffer.asUint8List());
        image.dispose();
      });
    }
    await tester.enterText(
      find.byKey(const Key('youtube-url')),
      'https://youtu.be/BaW_jenozKc',
    );
    await tester.tap(find.byKey(const Key('download-button')));
    await tester.pumpAndSettle();
    expect(submitted, 'https://youtu.be/BaW_jenozKc');
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    messenger.setMockMethodCallHandler(DownloadController.methods, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('clipforge/events'),
      null,
    );
  });
  testWidgets('mobile form starts only after local engine is ready', (
    tester,
  ) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
      DownloadController.methods,
      (call) async => {
        'engine': {'ready': false, 'message': 'QuickJS belum siap'},
        'history': [],
      },
    );
    messenger.setMockMethodCallHandler(
      const MethodChannel('clipforge/events'),
      (_) async => null,
    );
    await tester.pumpWidget(const ClipForgeApp());
    await tester.pumpAndSettle();
    final button = tester.widget<FilledButton>(
      find.byKey(const Key('download-button')),
    );
    expect(button.onPressed, isNull);
    expect(find.text('QuickJS belum siap'), findsOneWidget);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    messenger.setMockMethodCallHandler(DownloadController.methods, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('clipforge/events'),
      null,
    );
  });
}
