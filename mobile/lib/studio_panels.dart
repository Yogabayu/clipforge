import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'download_models.dart';
import 'job_card.dart';
import 'clip_timeline.dart';

class EditorVideo extends StatelessWidget {
  const EditorVideo({
    super.key,
    required this.player,
    required this.initialized,
    required this.markStart,
    required this.markEnd,
    this.showMarkers = true,
    this.range,
  });
  final VideoPlayerController player;
  final Future<void> initialized;
  final VoidCallback? markStart, markEnd;
  final bool showMarkers;
  final ClipSelection? range;
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: initialized,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return const Surface(
          child: Text(
            'Preview tidak tersedia. Rentang masih bisa diisi manual.',
          ),
        );
      }
      if (snapshot.connectionState != ConnectionState.done) {
        return const SizedBox(
          height: 160,
          child: Center(child: CircularProgressIndicator()),
        );
      }
      return Container(
        decoration: BoxDecoration(
          color: const Color(0xFF101827),
          borderRadius: BorderRadius.circular(20),
        ),
        clipBehavior: Clip.antiAlias,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final preview = ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 300),
              child: ColoredBox(
                color: Colors.black,
                child: AspectRatio(
                  aspectRatio: player.value.aspectRatio,
                  child: VideoPlayer(player),
                ),
              ),
            );
            final controls = ValueListenableBuilder<VideoPlayerValue>(
              valueListenable: player,
              builder: (context, value, _) {
                final total = value.duration.inMilliseconds
                    .toDouble()
                    .clamp(1, double.infinity)
                    .toDouble();
                Future<void> nudge(int milliseconds) => player.seekTo(
                  Duration(
                    milliseconds: (value.position.inMilliseconds + milliseconds)
                        .clamp(0, total.toInt()),
                  ),
                );
                return Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          SizedBox(
                            width: 48,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatDuration(value.position.inMilliseconds),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: [FontFeature.tabularFigures()],
                                ),
                              ),
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: 'Mundur 1 detik',
                            color: Colors.white70,
                            onPressed: () => nudge(-1000),
                            icon: const Icon(Icons.arrow_back_rounded),
                          ),
                          IconButton.filled(
                            tooltip: value.isPlaying ? 'Jeda' : 'Putar',
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white,
                              foregroundColor: const Color(0xFF101827),
                            ),
                            onPressed: () => value.isPlaying
                                ? player.pause()
                                : player.play(),
                            icon: Icon(
                              value.isPlaying
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                            ),
                          ),
                          IconButton(
                            tooltip: 'Maju 1 detik',
                            color: Colors.white70,
                            onPressed: () => nudge(1000),
                            icon: const Icon(Icons.arrow_forward_rounded),
                          ),
                          const Spacer(),
                          SizedBox(
                            width: 48,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                formatDuration(value.duration.inMilliseconds),
                                style: const TextStyle(
                                  color: Colors.white54,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      ClipTimeline(
                        positionMs: value.position.inMilliseconds,
                        durationMs: value.duration.inMilliseconds,
                        range: showMarkers ? range : null,
                        onSeek: (position) => player.seekTo(
                          Duration(milliseconds: position.round()),
                        ),
                      ),
                      if (showMarkers) ...[
                        const Text(
                          'Geser timeline, lalu tandai batas klip',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.white54, fontSize: 12),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: _markerButton(
                                'Set awal',
                                Icons.first_page_rounded,
                                markStart,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _markerButton(
                                'Set akhir',
                                Icons.last_page_rounded,
                                markEnd,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                );
              },
            );
            final landscape =
                MediaQuery.orientationOf(context) == Orientation.landscape &&
                constraints.maxWidth >= 560;
            if (landscape) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Expanded(child: preview),
                  SizedBox(width: 300, child: controls),
                ],
              );
            }
            return Column(children: [preview, controls]);
          },
        ),
      );
    },
  );

  Widget _markerButton(String label, IconData icon, VoidCallback? onPressed) =>
      OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: Colors.white,
          disabledForegroundColor: Colors.white30,
          side: const BorderSide(color: Color(0xFF475569)),
          backgroundColor: const Color(0xFF1E293B),
          minimumSize: const Size(0, 52),
          padding: const EdgeInsets.symmetric(horizontal: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 20),
        label: Text(label),
      );
}

class CandidatePanel extends StatelessWidget {
  const CandidatePanel({
    super.key,
    required this.candidates,
    required this.selected,
    required this.toggle,
    required this.seek,
    required this.enabled,
  });
  final List<StudioCandidate> candidates;
  final bool Function(ClipSelection) selected;
  final void Function(ClipSelection) toggle;
  final void Function(double) seek;
  final bool enabled;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        'Rekomendasi Auto Cut (${candidates.length})',
        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      if (candidates.isEmpty)
        const Text(
          'Jalankan analisis atau tambahkan rentang manual.',
          style: TextStyle(color: Color(0xFF64748B)),
        ),
      for (final candidate in candidates)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Surface(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                CheckboxListTile(
                  contentPadding: EdgeInsets.zero,
                  controlAffinity: ListTileControlAffinity.leading,
                  value: selected(candidate.range),
                  onChanged: enabled ? (_) => toggle(candidate.range) : null,
                  title: Text(
                    candidate.range.title,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    '${formatDuration((candidate.range.start * 1000).round())}–${formatDuration((candidate.range.end * 1000).round())} · skor ${candidate.score}',
                  ),
                ),
                Text(
                  candidate.reason,
                  style: const TextStyle(
                    fontSize: 12,
                    color: Color(0xFF64748B),
                  ),
                ),
                TextButton.icon(
                  onPressed: () => seek(candidate.range.start),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Lihat awal'),
                ),
              ],
            ),
          ),
        ),
    ],
  );
}

class TranscriptPanel extends StatelessWidget {
  const TranscriptPanel({
    super.key,
    required this.segments,
    required this.seek,
    this.edit,
    this.preview,
  });
  final List<StudioSegment> segments;
  final void Function(double) seek;
  final void Function(int)? edit;
  final Widget? preview;
  @override
  Widget build(BuildContext context) => ExpansionTile(
    tilePadding: EdgeInsets.zero,
    title: Text('Periksa subtitle (${segments.length} segmen)'),
    children: [
      ?preview,
      if (segments.isEmpty)
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Belum ada ucapan yang ditranskripsikan.'),
        ),
      SizedBox(
        height: segments.isEmpty ? 0 : 260,
        child: ListView.builder(
          primary: false,
          itemCount: segments.length,
          itemBuilder: (context, index) {
            final segment = segments[index];
            return ListTile(
              dense: true,
              onTap: () => seek(segment.start),
              leading: Text(formatDuration((segment.start * 1000).round())),
              title: Text(segment.text),
              trailing: IconButton(
                tooltip: 'Koreksi subtitle',
                onPressed: edit == null ? null : () => edit!(index),
                icon: const Icon(Icons.edit_outlined),
              ),
            );
          },
        ),
      ),
    ],
  );
}
