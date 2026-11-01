import 'package:clipforge_mobile/download_models.dart';
import 'package:clipforge_mobile/render_progress_overlay.dart';
import 'package:clipforge_mobile/rendered_clip_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'render modal updates in place, blocks dismissal, and closes on completion',
    (tester) async {
      final visible = ValueNotifier(true);
      final progress = ValueNotifier(0.1);
      addTearDown(visible.dispose);
      addTearDown(progress.dispose);
      var underlyingTaps = 0, cancellations = 0;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                child: const Text('Open editor'),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ValueListenableBuilder<bool>(
                      valueListenable: visible,
                      builder: (_, shown, _) => ValueListenableBuilder<double>(
                        valueListenable: progress,
                        builder: (_, amount, _) => RenderProgressOverlay(
                          visible: shown,
                          message: 'Render rentang 1/2',
                          progress: amount,
                          cancelling: false,
                          onCancel: () => cancellations++,
                          child: Scaffold(
                            body: TextButton(
                              onPressed: () => underlyingTaps++,
                              child: const Text('Underlying action'),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(find.text('10%'), findsOneWidget);
      progress.value = .6;
      await tester.pumpAndSettle();
      expect(find.text('60%'), findsOneWidget);
      await tester.tapAt(const Offset(8, 8));
      expect(underlyingTaps, 0);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Merender video'), findsOneWidget);
      await tester.tap(find.text('Batalkan render'));
      expect(cancellations, 1);
      visible.value = false;
      await tester.pumpAndSettle();
      expect(find.byType(Dialog), findsNothing);
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('Open editor'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'cancelling modal fits small screens and prevents repeated cancel',
    (tester) async {
      tester.view.physicalSize = const Size(320, 430);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: const MediaQueryData(textScaler: TextScaler.linear(1.8)),
            child: RenderProgressOverlay(
              visible: true,
              progress: null,
              cancelling: true,
              message: 'Menunggu proses render video selesai dibatalkan.',
              onCancel: () {},
              child: const Scaffold(),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(
        tester.widget<TextButton>(find.byType(TextButton)).onPressed,
        isNull,
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('latest render batch groups separate clips and combined output', () {
    StudioClip clip(String name) => StudioClip.fromMap({
      'name': name,
      'path': '/clip',
      'bytes': 1024,
      'durationMs': 2000,
    });
    const latest = 'bc7a1200-0000-4000-8000-000000000001';
    expect(
      clip('$latest-clip-1.mp4').renderBatch,
      clip('$latest-clip-2.mp4').renderBatch,
    );
    expect(clip('$latest-combined.mp4').renderBatch, latest);
    expect(
      clip('ac7a1200-0000-4000-8000-000000000001-clip-1.mp4').renderBatch,
      isNot(latest),
    );
    expect(clip('legacy.mp4').renderBatch, 'legacy.mp4');
  });

  testWidgets(
    'NEW badge appears only on flagged clip and preview still works',
    (tester) async {
      final clip = StudioClip.fromMap({
        'name': 'clip.mp4',
        'title': 'Hasil baru',
        'path': '/clip',
        'bytes': 1024,
        'durationMs': 2000,
      });
      var previews = 0;
      Future<void> show(bool fresh) => tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: RenderedClipCard(
              clip: clip,
              isNew: fresh,
              onPreview: () => previews++,
            ),
          ),
        ),
      );
      await show(true);
      expect(find.text('NEW'), findsOneWidget);
      await tester.tap(find.text('Preview'));
      expect(previews, 1);
      await show(false);
      expect(find.text('NEW'), findsNothing);
    },
  );
}
