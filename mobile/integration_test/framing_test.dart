import 'dart:io';

import 'package:clipforge_mobile/download_controller.dart';
import 'package:clipforge_mobile/download_models.dart';
import 'package:clipforge_mobile/main.dart' as app;
import 'package:clipforge_mobile/editor_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets('physical phone renders center, face follow and full-frame blur', (
    tester,
  ) async {
    app.main();
    const methods = DownloadController.methods;
    Future<DownloadSnapshot> read() async => DownloadSnapshot.fromMap(
      jsonMap(await methods.invokeMethod<Object?>('snapshot')),
    );
    Future<DownloadSnapshot> wait(bool Function(DownloadSnapshot) done) async {
      final deadline = DateTime.now().add(const Duration(minutes: 8));
      var state = await read();
      while (!done(state) && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(seconds: 1));
        state = await read();
      }
      expect(done(state), isTrue, reason: state.studio.message);
      return state;
    }

    var state = await wait((s) => s.ready);
    expect(state.active, isFalse, reason: 'Do not interrupt user work.');
    final sources = [
      if (state.current != null) state.current!,
      ...state.history,
    ];
    final source = sources.firstWhere(
      (s) => s.completed && s.url.contains('jNQXAC9IVRw'),
    );
    await methods.invokeMethod<Object?>('studio', {'id': source.id});
    state = await read();
    final controller = DownloadController()..snapshot = state;
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: EditorScreen(job: source, controller: controller),
      ),
    );
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(
      find.text('Fokus gambar'),
      400,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Crop tengah').last);
    await tester.pumpAndSettle();
    expect(find.text('Ikuti orang (wajah)').last, findsOneWidget);
    expect(find.text('Video utuh + blur').last, findsOneWidget);
    await tester.tap(find.text('Ikuti orang (wajah)').last);
    await tester.pumpAndSettle();
    expect(find.textContaining('Mengikuti wajah utama.'), findsOneWidget);
    var count = state.studio.clips.length;
    for (final mode in ['center', 'follow', 'blur']) {
      await methods.invokeMethod<void>('render', {
        'id': source.id,
        'ranges': [
          {'start': 0.0, 'end': 4.0, 'title': 'Framing proof $mode'},
        ],
        'framing': mode,
        'aspect': 'portrait',
        'resolution': '720p',
        'burnSubtitles': mode == 'blur',
        'combine': false,
      });
      state = await wait((s) => !s.studio.active);
      expect(state.studio.status, 'ready', reason: state.studio.message);
      expect(state.studio.clips.length, ++count);
      final raw = jsonMap(
        await methods.invokeMethod<Object?>('studio', {'id': source.id}),
      );
      final report = jsonMap(raw['framingReport']);
      expect(report['mode'], mode);
      if (mode == 'follow') expect(report['detectedFrames'], greaterThan(0));
      final player = VideoPlayerController.file(
        File(state.studio.clips.last.path),
      );
      try {
        await player.initialize();
        expect(player.value.size.width, 720);
        expect(player.value.size.height, 1280);
        await player.play();
        await Future<void>.delayed(const Duration(milliseconds: 600));
        expect(player.value.position.inMilliseconds, greaterThan(0));
        expect(player.value.hasError, isFalse);
      } finally {
        await player.dispose();
      }
      // ignore: avoid_print
      print(
        'FRAMING_PROOF mode=$mode report=$report path=${state.studio.clips.last.path}',
      );
    }
  }, timeout: const Timeout(Duration(minutes: 30)));
}
