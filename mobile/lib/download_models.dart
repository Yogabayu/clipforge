enum DownloadStage {
  preparing,
  extracting,
  downloading,
  merging,
  validating,
  cancelling,
  completed,
  failed,
  cancelled,
  interrupted;

  bool get active => switch (this) {
    preparing ||
    extracting ||
    downloading ||
    merging ||
    validating ||
    cancelling => true,
    _ => false,
  };

  String get label => switch (this) {
    preparing => 'Menyiapkan',
    extracting => 'Membaca YouTube',
    downloading => 'Mengunduh',
    merging => 'Menggabungkan',
    validating => 'Memeriksa MP4',
    cancelling => 'Membatalkan',
    completed => 'Selesai',
    failed => 'Gagal',
    cancelled => 'Dibatalkan',
    interrupted => 'Terputus',
  };
}

Map<String, dynamic> jsonMap(Object? value) =>
    value is Map ? Map<String, dynamic>.from(value) : <String, dynamic>{};

class DownloadJob {
  DownloadJob.fromMap(Map<String, dynamic> map)
    : id = map['id'] as String? ?? '',
      url = map['url'] as String? ?? '',
      title = map['title'] as String? ?? 'Video YouTube',
      stage = DownloadStage.values.firstWhere(
        (stage) => stage.name == map['status'],
        orElse: () => DownloadStage.interrupted,
      ),
      message = map['message'] as String? ?? '',
      progress = ((map['progress'] as num?)?.toDouble() ?? 0).clamp(0, 100),
      path = map['path'] as String?,
      bytes = (map['bytes'] as num?)?.toInt() ?? 0,
      durationMs = (map['durationMs'] as num?)?.toInt() ?? 0,
      etaSeconds = (map['etaSeconds'] as num?)?.toInt() ?? -1,
      transfer = map['transfer'] as String? ?? '',
      logs = (map['logs'] as List? ?? []).whereType<String>().toList(),
      metrics = jsonMap(map['metrics'])
          .map((key, value) => MapEntry(key, (value as num).toInt()));

  final String id, url, title, message, transfer;
  final DownloadStage stage;
  final double progress;
  final String? path;
  final int bytes, durationMs, etaSeconds;
  final List<String> logs;
  final Map<String, int> metrics;
  bool get completed => stage == DownloadStage.completed && path != null;
}

class DownloadSnapshot {
  DownloadSnapshot({
    this.ready = false,
    this.engineMessage = 'Menyiapkan engine lokal…',
    this.current,
    this.history = const [],
    this.studio = const StudioState(),
  });

  factory DownloadSnapshot.fromMap(Map<String, dynamic> map) {
    final engine = jsonMap(map['engine']);
    return DownloadSnapshot(
      ready: engine['ready'] == true,
      engineMessage: engine['message'] as String? ?? 'Engine belum siap.',
      current: map['current'] == null
          ? null
          : DownloadJob.fromMap(jsonMap(map['current'])),
      history: (map['history'] as List? ?? [])
          .map((entry) => DownloadJob.fromMap(jsonMap(entry)))
          .toList(),
      studio: StudioState.fromMap(jsonMap(map['studio'])),
    );
  }

  final bool ready;
  final String engineMessage;
  final DownloadJob? current;
  final List<DownloadJob> history;
  final StudioState studio;
  bool get active => (current?.stage.active ?? false) || studio.active;
  DownloadSnapshot withStudio(StudioState value) => DownloadSnapshot(
    ready: ready,
    engineMessage: engineMessage,
    current: current,
    history: history,
    studio: value,
  );
}

class ClipSelection {
  const ClipSelection({
    required this.start,
    required this.end,
    required this.title,
  });
  factory ClipSelection.fromMap(Map<String, dynamic> map) => ClipSelection(
    start: (map['start'] as num).toDouble(),
    end: (map['end'] as num).toDouble(),
    title: map['title'] as String? ?? 'Klip',
  );
  final double start, end;
  final String title;
  double get duration => end - start;
  bool valid(double duration) =>
      start.isFinite &&
      end.isFinite &&
      start >= 0 &&
      end <= duration + .001 &&
      this.duration >= 1 &&
      this.duration <= 600;
  Map<String, Object> toMap() => {'start': start, 'end': end, 'title': title};
}

class StudioCandidate {
  StudioCandidate.fromMap(Map<String, dynamic> map)
    : range = ClipSelection.fromMap(map),
      score = (map['score'] as num?)?.toInt() ?? 0,
      reason = map['reason'] as String? ?? '',
      text = map['text'] as String? ?? '';
  final ClipSelection range;
  final int score;
  final String reason, text;
}

class StudioSegment {
  StudioSegment.fromMap(Map<String, dynamic> map)
    : start = (map['start'] as num).toDouble(),
      end = (map['end'] as num).toDouble(),
      text = map['text'] as String? ?? '';
  final double start, end;
  final String text;
}

class StudioClip {
  StudioClip.fromMap(Map<String, dynamic> map)
    : name = map['name'] as String,
      title = map['title'] as String? ?? 'Klip',
      path = map['path'] as String,
      bytes = (map['bytes'] as num).toInt(),
      durationMs = (map['durationMs'] as num).toInt();
  final String name, title, path;
  final int bytes, durationMs;
  // Native names begin with the render run UUID; all ranges in a run share it.
  String get renderBatch =>
      RegExp(r'^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}')
          .firstMatch(name)
          ?.group(0) ??
      name;
}

class StudioState {
  const StudioState({
    this.id = '',
    this.status = 'idle',
    this.message = '',
    this.progress = 0,
    this.segments = const [],
    this.candidates = const [],
    this.clips = const [],
    this.lastRanges = const [],
    this.metrics = const {},
  });
  factory StudioState.fromMap(Map<String, dynamic> map) => StudioState(
    id: map['id'] as String? ?? '',
    status: map['status'] as String? ?? 'idle',
    message: map['message'] as String? ?? '',
    progress: ((map['progress'] as num?)?.toDouble() ?? 0).clamp(0, 100),
    segments: (map['segments'] as List? ?? [])
        .map((item) => StudioSegment.fromMap(jsonMap(item)))
        .toList(),
    candidates: (map['candidates'] as List? ?? [])
        .map((item) => StudioCandidate.fromMap(jsonMap(item)))
        .toList(),
    clips: (map['clips'] as List? ?? [])
        .map((item) => StudioClip.fromMap(jsonMap(item)))
        .toList(),
    lastRanges: (map['lastRanges'] as List? ?? [])
        .map((item) => ClipSelection.fromMap(jsonMap(item)))
        .toList(),
    metrics: jsonMap(map['metrics'])
        .map((key, value) => MapEntry(key, (value as num).toInt())),
  );
  final String id, status, message;
  final double progress;
  final List<StudioSegment> segments;
  final List<StudioCandidate> candidates;
  final List<StudioClip> clips;
  final List<ClipSelection> lastRanges;
  final Map<String, int> metrics;
  bool get active => const {
    'model',
    'audio',
    'transcribing',
    'scoring',
    'rendering',
    'cancelling',
  }.contains(status);
}

String formatBytes(int bytes) => bytes < 1024 * 1024
    ? '${(bytes / 1024).toStringAsFixed(0)} KB'
    : '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';

String formatDuration(int milliseconds) {
  final seconds = milliseconds ~/ 1000;
  return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
}
