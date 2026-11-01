import 'package:clipforge_mobile/download_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'platform snapshot decodes mixed numbers, metrics and completed files',
    () {
      final state = DownloadSnapshot.fromMap({
        'engine': {'ready': true, 'message': 'ready'},
        'current': {
          'id': '1',
          'status': 'completed',
          'progress': 100,
          'path': '/private/source.mp4',
          'metrics': {'extractMs': 1200, 'downloadMs': 2500.0},
          'logs': ['validated'],
        },
        'history': [],
      });
      expect(state.ready, isTrue);
      expect(state.active, isFalse);
      expect(state.current!.completed, isTrue);
      expect(state.current!.metrics['downloadMs'], 2500);
    },
  );

  test('active stages block another download until terminal state', () {
    for (final status in [
      'preparing',
      'extracting',
      'downloading',
      'merging',
      'validating',
      'cancelling',
    ]) {
      expect(
        DownloadSnapshot.fromMap({
          'current': {'status': status},
        }).active,
        isTrue,
      );
    }
    for (final status in [
      'failed',
      'cancelled',
      'completed',
      'interrupted',
      'unknown',
    ]) {
      expect(
        DownloadSnapshot.fromMap({
          'current': {'status': status},
        }).active,
        isFalse,
      );
    }
  });

  test('completion without a file cannot enable preview', () {
    expect(DownloadJob.fromMap({'status': 'completed'}).completed, isFalse);
    expect(DownloadJob.fromMap({'progress': 150}).progress, 100);
    expect(formatDuration(125000), '2:05');
    expect(formatBytes(1048576), '1.0 MB');
  });
}
