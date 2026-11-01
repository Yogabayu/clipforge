import 'dart:io';

import 'package:clipforge_mobile/download_controller.dart';
import 'package:clipforge_mobile/download_models.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('TEST_YOUTUBE_URL');
  testWidgets('physical Android: QuickJS, YouTube download, audio/video, seek', (
    tester,
  ) async {
    expect(
      url,
      isNotEmpty,
      reason: 'Pass --dart-define=TEST_YOUTUBE_URL=<public video>',
    );
    const methods = DownloadController.methods;
    Future<DownloadSnapshot> read() async => DownloadSnapshot.fromMap(
      jsonMap(await methods.invokeMethod<Object?>('snapshot')),
    );
    final engineDeadline = DateTime.now().add(const Duration(minutes: 2));
    var state = await read();
    while (!state.ready && DateTime.now().isBefore(engineDeadline)) {
      await Future<void>.delayed(const Duration(seconds: 1));
      state = await read();
    }
    expect(state.ready, isTrue, reason: state.engineMessage);
    await methods.invokeMethod<String>('start', {'url': url});
    final deadline = DateTime.now().add(const Duration(minutes: 15));
    do {
      await Future<void>.delayed(const Duration(seconds: 2));
      state = await read();
    } while (state.active && DateTime.now().isBefore(deadline));
    final job = state.current!;
    expect(
      job.completed,
      isTrue,
      reason: '${job.message}\n${job.logs.join('\n')}',
    );
    expect(job.bytes, greaterThan(0));
    expect(job.durationMs, greaterThan(0));
    final player = VideoPlayerController.file(File(job.path!));
    try {
      await player.initialize();
      await player.play();
      await Future<void>.delayed(const Duration(seconds: 2));
      expect(
        player.value.hasError,
        isFalse,
        reason: player.value.errorDescription,
      );
      expect(player.value.position.inMilliseconds, greaterThan(0));
      await player.seekTo(player.value.duration ~/ 2);
      await player.pause();
      expect(
        player.value.position.inMilliseconds,
        greaterThanOrEqualTo(player.value.duration.inMilliseconds ~/ 3),
      );
    } finally {
      await player.dispose();
    }
    // Audible output still needs listening on the physical device.
    // ignore: avoid_print
    print(
      'CLIPFORGE_DEVICE_PROOF ${job.metrics} bytes=${job.bytes} durationMs=${job.durationMs}',
    );
  }, timeout: const Timeout(Duration(minutes: 20)));
}
