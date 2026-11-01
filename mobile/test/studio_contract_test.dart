import 'package:clipforge_mobile/download_controller.dart';
import 'package:clipforge_mobile/download_models.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  tearDown(
    () => messenger.setMockMethodCallHandler(DownloadController.methods, null),
  );
  test('studio operation blocks another download until terminal state', () {
    for (final status in [
      'model',
      'audio',
      'transcribing',
      'scoring',
      'rendering',
      'cancelling',
    ]) {
      expect(
        DownloadSnapshot.fromMap({
          'studio': {'status': status},
        }).active,
        isTrue,
      );
    }
    expect(
      DownloadSnapshot.fromMap({
        'studio': {'status': 'ready'},
      }).active,
      isFalse,
    );
  });
  test(
    'analysis defaults to ten while explicit top remains respected',
    () async {
      final calls = <MethodCall>[];
      messenger.setMockMethodCallHandler(DownloadController.methods, (
        call,
      ) async {
        calls.add(call);
        return null;
      });
      final controller = DownloadController();
      await controller.analyze('id');
      await controller.analyze('id', top: 2);
      expect(calls.first.arguments['top'], 10);
      expect(calls.last.arguments['top'], 2);
      expect(calls.every((call) => call.method == 'analyze'), isTrue);
      controller.dispose();
    },
  );
  test(
    'render only sends selected ranges and explicit output options',
    () async {
      MethodCall? sent;
      messenger.setMockMethodCallHandler(DownloadController.methods, (
        call,
      ) async {
        sent = call;
        return null;
      });
      final controller = DownloadController();
      await controller.render(
        'id',
        [const ClipSelection(start: 3, end: 8, title: 'Chosen')],
        combine: true,
        aspect: 'landscape',
        resolution: '1080p',
        framing: 'follow',
      );
      expect(sent!.method, 'render');
      expect(sent!.arguments['ranges'], [
        {'start': 3.0, 'end': 8.0, 'title': 'Chosen'},
      ]);
      expect(sent!.arguments['combine'], isTrue);
      expect(sent!.arguments['resolution'], '1080p');
      expect(sent!.arguments['framing'], 'follow');
      controller.dispose();
    },
  );
  test('analysis range is optional and uses source seconds', () async {
    final calls = <MethodCall>[];
    messenger.setMockMethodCallHandler(DownloadController.methods, (
      call,
    ) async {
      calls.add(call);
      return null;
    });
    final controller = DownloadController();
    await controller.analyze('id');
    expect(calls.last.arguments.containsKey('analysisStart'), isFalse);
    await controller.analyze('id', analysisStart: 600, analysisEnd: 1200);
    expect(calls.last.arguments['analysisStart'], 600);
    expect(calls.last.arguments['analysisEnd'], 1200);
    controller.dispose();
  });
  test('invalid manual ranges cannot enable rendering', () {
    expect(
      const ClipSelection(start: -1, end: 3, title: '').valid(19),
      isFalse,
    );
    expect(
      ClipSelection(start: double.nan, end: 3, title: '').valid(19),
      isFalse,
    );
    expect(
      const ClipSelection(start: 3, end: 3.5, title: '').valid(19),
      isFalse,
    );
    expect(
      const ClipSelection(start: 3, end: 20, title: '').valid(19),
      isFalse,
    );
    expect(const ClipSelection(start: 3, end: 8, title: '').valid(19), isTrue);
  });
}
