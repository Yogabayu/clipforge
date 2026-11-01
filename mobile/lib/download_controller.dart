import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'download_models.dart';

class DownloadController extends ChangeNotifier {
  static const methods = MethodChannel('clipforge/downloads');
  static const events = EventChannel('clipforge/events');
  DownloadSnapshot snapshot = DownloadSnapshot();
  String? error;
  bool pending = false;
  bool _disposed = false;
  StreamSubscription<Object?>? _subscription;

  Future<void> initialize() async {
    _subscription ??= events.receiveBroadcastStream().listen(
      (event) {
        snapshot = DownloadSnapshot.fromMap(jsonMap(event));
        _changed();
      },
      onError: (Object exception) {
        error = exception.toString();
        _changed();
      },
    );
    await _command(() async {
      snapshot = DownloadSnapshot.fromMap(
        jsonMap(await methods.invokeMethod<Object?>('snapshot')),
      );
    });
  }

  Future<void> start(String url) => _command(() async {
    await methods.invokeMethod<String>('start', {'url': url.trim()});
  });
  Future<void> cancel() => _command(() => methods.invokeMethod<void>('cancel'));
  Future<void> retryEngine() =>
      _command(() => methods.invokeMethod<void>('initialize'));

  Future<bool> saveVideo(String id) => _save('saveVideo', {'id': id});
  Future<bool> saveDiagnostics() => _save('saveDiagnostics', null);

  Future<void> openStudio(String id) => _command(() async {
    final value = await methods.invokeMethod<Object?>('studio', {'id': id});
    snapshot = snapshot.withStudio(StudioState.fromMap(jsonMap(value)));
  });
  Future<void> analyze(
    String id, {
    String language = 'auto',
    int top = 10,
    double minDuration = 35,
    double maxDuration = 180,
    double? analysisStart,
    double? analysisEnd,
  }) => _command(
    () => methods.invokeMethod<void>('analyze', {
      'id': id,
      'language': language,
      'top': top,
      'minDuration': minDuration,
      'maxDuration': maxDuration,
      'analysisStart': ?analysisStart,
      'analysisEnd': ?analysisEnd,
    }),
  );
  Future<void> render(
    String id,
    List<ClipSelection> ranges, {
    bool combine = false,
    bool burnSubtitles = true,
    String aspect = 'portrait',
    String resolution = '720p',
    String framing = 'center',
  }) => _command(
    () => methods.invokeMethod<void>('render', {
      'id': id,
      'ranges': ranges.map((range) => range.toMap()).toList(),
      'combine': combine,
      'burnSubtitles': burnSubtitles,
      'aspect': aspect,
      'resolution': resolution,
      'framing': framing,
    }),
  );
  Future<bool> saveClip(String id, String name) =>
      _save('saveClip', {'id': id, 'name': name});

  Future<bool> openYouTubeUpload(String id, StudioClip clip) async {
    var opened = false;
    await _command(() async {
      await methods.invokeMethod<void>('openYouTubeUpload', {
        'id': id,
        'name': clip.name,
        'title': clip.title,
      });
      opened = true;
    });
    return opened;
  }

  Future<int?> deleteDownload(String id) =>
      _delete('deleteDownload', {'id': id});
  Future<int?> deleteClip(String id, String name) =>
      _delete('deleteClip', {'id': id, 'name': name});

  Future<int?> _delete(String method, Map<String, String> arguments) async {
    int? bytes;
    await _command(() async {
      bytes = await methods.invokeMethod<int>(method, arguments);
      snapshot = DownloadSnapshot.fromMap(
        jsonMap(await methods.invokeMethod<Object?>('snapshot')),
      );
    });
    return bytes;
  }

  Future<void> editTranscript(String id, int index, String text) => _command(
    () => methods.invokeMethod<void>('editTranscript', {
      'id': id,
      'index': index,
      'text': text,
    }),
  );

  Future<bool> _save(String method, Map<String, Object>? arguments) async {
    var saved = false;
    await _command(() async {
      saved = await methods.invokeMethod<bool>(method, arguments) ?? false;
    });
    return saved;
  }

  Future<void> _command(Future<void> Function() action) async {
    if (pending || _disposed) return;
    pending = true;
    error = null;
    _changed();
    try {
      await action();
    } on PlatformException catch (exception) {
      error = exception.message ?? exception.code;
    } catch (exception) {
      error = exception.toString();
    } finally {
      pending = false;
      _changed();
    }
  }

  void _changed() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_subscription?.cancel());
    super.dispose();
  }
}
