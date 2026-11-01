import 'dart:io';

import 'package:clipforge_mobile/download_controller.dart';
import 'package:clipforge_mobile/download_models.dart';
import 'package:clipforge_mobile/main.dart' as app;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:video_player/video_player.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  testWidgets(
    'physical Android: local transcript, candidates, selected renders and concat',
    (tester) async {
      app.main();
      const methods = DownloadController.methods;
      Future<DownloadSnapshot> read() async => DownloadSnapshot.fromMap(
        jsonMap(await methods.invokeMethod<Object?>('snapshot')),
      );
      Future<DownloadSnapshot> until(
        bool Function(DownloadSnapshot) done,
        Duration timeout,
      ) async {
        final deadline = DateTime.now().add(timeout);
        var state = await read();
        while (!done(state) && DateTime.now().isBefore(deadline)) {
          await Future<void>.delayed(const Duration(seconds: 1));
          state = await read();
        }
        expect(
          done(state),
          isTrue,
          reason:
              '${state.engineMessage}; ${state.studio.status}: ${state.studio.message}',
        );
        return state;
      }

      var state = await until(
        (state) => state.ready,
        const Duration(minutes: 2),
      );
      expect(
        state.active,
        isFalse,
        reason: 'Do not interrupt an existing user operation.',
      );
      final sources = [
        if (state.current != null) state.current!,
        ...state.history,
      ];
      final fixture = sources.where(
        (job) =>
            job.url.contains('jNQXAC9IVRw') &&
            job.completed &&
            job.durationMs < 30000,
      );
      String id;
      if (fixture.isNotEmpty) {
        id = fixture.first.id;
      } else {
        id = (await methods.invokeMethod<String>('start', {
          'url': 'https://www.youtube.com/watch?v=jNQXAC9IVRw',
        }))!;
        state = await until(
          (state) => !state.active,
          const Duration(minutes: 5),
        );
        expect(
          state.current!.completed,
          isTrue,
          reason: state.current!.message,
        );
      }
      await methods.invokeMethod<Object?>('studio', {'id': id});
      state = await read();
      final clipsBefore = state.studio.clips.length;
      await methods.invokeMethod<void>('analyze', {
        'id': id,
        'language': 'en',
        'top': 10,
        'minDuration': 35,
        'maxDuration': 180,
        'force': true,
      });
      state = await until(
        (state) => !state.studio.active,
        const Duration(minutes: 20),
      );
      expect(state.studio.status, 'ready', reason: state.studio.message);
      expect(state.studio.segments, isNotEmpty);
      expect(state.studio.candidates.length, inInclusiveRange(1, 10));
      expect(
        state.studio.clips.length,
        clipsBefore,
        reason: 'Analysis must never auto-render recommendations.',
      );
      final analysisMetrics = Map<String, int>.of(state.studio.metrics);
      final transcript = state.studio.segments
          .map((segment) => segment.text)
          .join(' ');
      const corrected = 'All right, so here we are in front of the elephants.';
      await methods.invokeMethod<void>('editTranscript', {
        'id': id,
        'index': 0,
        'text': corrected,
      });
      await methods.invokeMethod<Object?>('studio', {'id': id});
      state = await read();
      expect(state.studio.segments.first.text, corrected);
      final ranges = [
        {'start': 0.0, 'end': 2.0, 'title': 'Device proof 1'},
        {'start': 3.0, 'end': 5.0, 'title': 'Device proof 2'},
      ];
      await methods.invokeMethod<void>('render', {
        'id': id,
        'ranges': ranges,
        'combine': false,
        'burnSubtitles': true,
        'aspect': 'portrait',
        'resolution': '720p',
      });
      state = await until(
        (state) => !state.studio.active,
        const Duration(minutes: 8),
      );
      expect(state.studio.status, 'ready', reason: state.studio.message);
      expect(state.studio.clips.length, clipsBefore + 2);
      final portrait = state.studio.clips.last;
      final player = VideoPlayerController.file(File(portrait.path));
      try {
        await player.initialize();
        expect(player.value.size.width, 720);
        expect(player.value.size.height, 1280);
        await player.play();
        await Future<void>.delayed(const Duration(seconds: 1));
        expect(player.value.position.inMilliseconds, greaterThan(0));
        await player.seekTo(player.value.duration ~/ 2);
        await player.pause();
        expect(
          player.value.hasError,
          isFalse,
          reason: player.value.errorDescription,
        );
      } finally {
        await player.dispose();
      }
      await methods.invokeMethod<void>('render', {
        'id': id,
        'ranges': ranges,
        'combine': true,
        'burnSubtitles': false,
        'aspect': 'landscape',
        'resolution': '720p',
      });
      state = await until(
        (state) => !state.studio.active,
        const Duration(minutes: 8),
      );
      expect(state.studio.status, 'ready', reason: state.studio.message);
      expect(state.studio.clips.length, clipsBefore + 3);
      final combined = state.studio.clips.last;
      expect(combined.durationMs, inInclusiveRange(3500, 5000));
      final combinedPlayer = VideoPlayerController.file(File(combined.path));
      try {
        await combinedPlayer.initialize();
        expect(combinedPlayer.value.size.width, 1280);
        expect(combinedPlayer.value.size.height, 720);
      } finally {
        await combinedPlayer.dispose();
      }
      // ignore: avoid_print
      print(
        'CLIPFORGE_STUDIO_PROOF transcript=$transcript analysis=$analysisMetrics render=${state.studio.metrics} clips=${state.studio.clips.length - clipsBefore}',
      );
    },
    timeout: const Timeout(Duration(minutes: 40)),
  );
}
