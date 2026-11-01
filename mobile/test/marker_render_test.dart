import 'dart:io';

import 'package:clipforge_mobile/clip_timeline.dart';

import 'package:clipforge_mobile/download_controller.dart';
import 'package:clipforge_mobile/download_models.dart';
import 'package:clipforge_mobile/editor_screen.dart';
import 'package:clipforge_mobile/marker_range_panel.dart';
import 'package:clipforge_mobile/main.dart';
import 'package:clipforge_mobile/studio_panels.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:video_player_platform_interface/video_player_platform_interface.dart';

class _VideoPlatform extends VideoPlayerPlatform {
  @override
  Future<void> init() async {}
  @override
  Future<int?> createWithOptions(VideoCreationOptions options) async => 1;
  @override
  Stream<VideoEvent> videoEventsFor(int playerId) => Stream.value(
    VideoEvent(
      eventType: VideoEventType.initialized,
      duration: const Duration(seconds: 30),
      size: const Size(1280, 720),
    ),
  );
  @override
  Widget buildViewWithOptions(VideoViewOptions options) => const SizedBox();
  @override
  Future<void> dispose(int playerId) async {}
  @override
  Future<void> play(int playerId) async {}
  @override
  Future<void> pause(int playerId) async {}
  @override
  Future<void> setLooping(int playerId, bool looping) async {}
  @override
  Future<void> setVolume(int playerId, double volume) async {}
  @override
  Future<void> setPlaybackSpeed(int playerId, double speed) async {}
  @override
  Future<void> seekTo(int playerId, Duration position) async {}
  @override
  Future<Duration> getPosition(int playerId) async => Duration.zero;
}

void main() {
  testWidgets(
    'invalid markers block selection; valid markers can replace a full list',
    (tester) async {
      for (final range in [
        const ClipSelection(start: 8, end: 3, title: ''),
        const ClipSelection(start: 0, end: .2, title: ''),
        const ClipSelection(start: 0, end: 601, title: ''),
        const ClipSelection(start: 1300, end: 1302, title: ''),
      ]) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: MarkerRangePanel(
                range: range,
                sourceDuration: 1200,
                locked: false,
                onContinue: () {},
              ),
            ),
          ),
        );
        expect(
          tester
              .widget<FilledButton>(find.byKey(const Key('use-markers')))
              .onPressed,
          isNull,
        );
      }
      var rendered = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: MarkerRangePanel(
              range: const ClipSelection(start: 3, end: 8, title: ''),
              sourceDuration: 30,
              locked: false,
              onContinue: () => rendered++,
              onAdd: null,
            ),
          ),
        ),
      );
      await tester.tap(find.text('Gunakan penanda ini'));
      expect(rendered, 1);
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
    },
  );
  for (final savedRanges in [false, true]) {
    testWidgets(
      'set markers renders those exact bounds, saved ranges=$savedRanges',
      (tester) async {
        final originalPlatform = VideoPlayerPlatform.instance;
        VideoPlayerPlatform.instance = _VideoPlatform();
        addTearDown(() => VideoPlayerPlatform.instance = originalPlatform);
        final messenger =
            TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
        MethodCall? render;
        messenger.setMockMethodCallHandler(DownloadController.methods, (
          call,
        ) async {
          if (call.method == 'studio') {
            return {
              'id': 'source',
              'status': 'ready',
              'lastRanges': savedRanges
                  ? [
                      {'start': 15, 'end': 20, 'title': 'Old selection'},
                    ]
                  : [],
            };
          }
          if (call.method == 'render') render = call;
          return null;
        });
        addTearDown(
          () => messenger.setMockMethodCallHandler(
            DownloadController.methods,
            null,
          ),
        );
        final controller = DownloadController()
          ..snapshot = DownloadSnapshot(ready: true);
        final job = DownloadJob.fromMap({
          'id': 'source',
          'title': 'Test',
          'path': '/source.mp4',
          'durationMs': 30000,
          'status': 'completed',
        });
        await tester.pumpWidget(
          MaterialApp(
            home: EditorScreen(job: job, controller: controller),
          ),
        );
        await tester.pumpAndSettle();
        final player = tester
            .widget<EditorVideo>(find.byType(EditorVideo))
            .player;
        await player.seekTo(const Duration(seconds: 3));
        await tester.ensureVisible(find.text('Set awal'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Set awal'));
        await tester.pump();
        await player.seekTo(const Duration(seconds: 8));
        await tester.tap(find.text('Set akhir'));
        await tester.pump();
        final timeline = tester.widget<ClipTimeline>(find.byType(ClipTimeline));
        expect(timeline.range!.start, 3.0);
        expect(timeline.range!.end, 8.0);
        await player.play();
        final useMarkers = find.byKey(const Key('use-markers'));
        await tester.scrollUntilVisible(
          useMarkers,
          200,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(useMarkers);
        await tester.pumpAndSettle();
        // Selecting markers must show settings first, never start rendering.
        expect(render, isNull);
        expect(player.value.isPlaying, isFalse);
        expect(find.text('Langkah 2 dari 3'), findsOneWidget);
        await tester.tap(find.byKey(const Key('render-button')));
        await tester.pumpAndSettle();
        expect(render, isNotNull);
        final ranges = render!.arguments['ranges'] as List;
        expect(ranges, hasLength(1));
        expect(ranges.single['start'], 3.0);
        expect(ranges.single['end'], 8.0);
        expect(find.text('Langkah 3 dari 3'), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        controller.dispose();
      },
    );
  }
  for (final width in [320.0, 360.0, 800.0]) {
    testWidgets('guided Auto Cut selects exact ranges at width $width', (
      tester,
    ) async {
      const screenshotFont = String.fromEnvironment('EDITOR_FONT');
      if (screenshotFont.isNotEmpty) {
        await tester.runAsync(() async {
          final loader = FontLoader('Roboto')
            ..addFont(
              Future.value(
                ByteData.sublistView(await File(screenshotFont).readAsBytes()),
              ),
            );
          await loader.load();
          final icons = FontLoader('MaterialIcons')
            ..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'));
          await icons.load();
        });
      }
      tester.view.physicalSize = Size(width, width == 800 ? 400 : 800);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final originalPlatform = VideoPlayerPlatform.instance;
      VideoPlayerPlatform.instance = _VideoPlatform();
      addTearDown(() => VideoPlayerPlatform.instance = originalPlatform);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(DownloadController.methods, (
        call,
      ) async {
        calls.add(call);
        if (call.method == 'studio') {
          return {
            'id': 'source',
            'status': 'ready',
            'candidates': [
              {
                'start': 2,
                'end': 7,
                'title': 'Bagian menarik',
                'score': 90,
                'reason': 'Pembahasan inti',
              },
            ],
            'clips': [
              {
                'name': 'old.mp4',
                'title': 'Klip sebelumnya',
                'path': '/old.mp4',
                'bytes': 2000000,
                'durationMs': 5000,
              },
            ],
          };
        }
        return null;
      });
      addTearDown(
        () => messenger.setMockMethodCallHandler(
          DownloadController.methods,
          null,
        ),
      );
      final controller = DownloadController()
        ..snapshot = DownloadSnapshot(ready: true);
      final job = DownloadJob.fromMap({
        'id': 'source',
        'title': 'Video sumber',
        'path': '/source.mp4',
        'durationMs': 30000,
        'status': 'completed',
      });
      await tester.pumpWidget(const MaterialApp(home: SizedBox()));
      final app = const ClipForgeApp().build(
        tester.element(find.byType(SizedBox).first),
      ) as MaterialApp;
      await tester.pumpWidget(
        MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: app.theme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(width == 320 ? 1.3 : 1)),
            child: child!,
          ),
          home: EditorScreen(job: job, controller: controller),
        ),
      );
      await tester.pumpAndSettle();
      Future<void> screenshot(String name) async {
        if (const bool.fromEnvironment('EDITOR_SCREENSHOTS') && width == 360) {
          await expectLater(
            find.byType(MaterialApp),
            matchesGoldenFile('../build/review/editor-$name.png'),
          );
        }
      }

      if (const bool.fromEnvironment('EDITOR_SCREENSHOTS') && width == 800) {
        await tester.ensureVisible(find.byType(EditorVideo));
        await tester.pumpAndSettle();
        await expectLater(
          find.byType(EditorVideo),
          matchesGoldenFile('../build/review/editor-landscape.png'),
        );
        await tester.drag(find.byType(Scrollable).first, const Offset(0, 1000));
        await tester.pumpAndSettle();
      }
      await screenshot('manual');
      await tester.tap(find.text('Auto Cut'));
      await tester.pumpAndSettle();
      expect(find.byType(MarkerRangePanel), findsNothing);
      expect(
        tester
            .widget<FilledButton>(find.byKey(const Key('configure-button')))
            .onPressed,
        isNull,
      );
      await screenshot('auto');
      await tester.scrollUntilVisible(
        find.byKey(const Key('analyze-button')),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('analyze-button')));
      await tester.pumpAndSettle();
      expect(
        calls.where((call) => call.method == 'analyze').single.arguments['top'],
        10,
      );
      await tester.scrollUntilVisible(
        find.byType(CheckboxListTile),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('configure-button')));
      await tester.pumpAndSettle();
      expect(find.text('Langkah 2 dari 3'), findsOneWidget);
      expect(calls.where((call) => call.method == 'render'), isEmpty);
      await screenshot('settings');
      // Render stays visible even after scrolling through output options.
      await tester.scrollUntilVisible(
        find.text('Fokus gambar'),
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await screenshot('output');
      await tester.tap(find.byKey(const Key('render-button')));
      await tester.pumpAndSettle();
      final sent = calls.where((call) => call.method == 'render').single;
      expect(sent.arguments['ranges'], [
        {'start': 2.0, 'end': 7.0, 'title': 'Bagian menarik'},
      ]);
      expect(find.text('Langkah 3 dari 3'), findsOneWidget);
      await screenshot('results');
      await tester.pumpWidget(const SizedBox());
      controller.dispose();
    });
  }
}
