import 'dart:io';

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'download_models.dart';

class PreviewScreen extends StatefulWidget {
  PreviewScreen({super.key, required DownloadJob job})
    : title = job.title,
      path = job.path!;
  const PreviewScreen.file({
    super.key,
    required this.title,
    required this.path,
  });
  final String title, path;
  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final player = VideoPlayerController.file(File(widget.path));
  late final Future<void> initialized = player.initialize();

  @override
  void dispose() {
    player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.title, maxLines: 1, overflow: TextOverflow.ellipsis),
    ),
    body: SafeArea(
      child: FutureBuilder<void>(
        future: initialized,
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  'Preview gagal. File mungkin sudah dihapus.\n${snapshot.error}',
                ),
              ),
            );
          }
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: ColoredBox(
                  color: Colors.black,
                  child: AspectRatio(
                    aspectRatio: player.value.aspectRatio,
                    child: VideoPlayer(player),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              VideoProgressIndicator(
                player,
                allowScrubbing: true,
                padding: const EdgeInsets.symmetric(vertical: 18),
              ),
              ValueListenableBuilder<VideoPlayerValue>(
                valueListenable: player,
                builder: (context, value, _) => Column(
                  children: [
                    Text(
                      '${formatDuration(value.position.inMilliseconds)} / ${formatDuration(value.duration.inMilliseconds)}',
                    ),
                    const SizedBox(height: 12),
                    FilledButton.icon(
                      onPressed: () async {
                        if (value.isPlaying) {
                          await player.pause();
                        } else {
                          if (value.position >= value.duration) {
                            await player.seekTo(Duration.zero);
                          }
                          await player.play();
                        }
                      },
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                      label: Text(value.isPlaying ? 'Jeda' : 'Putar'),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Geser garis waktu untuk memeriksa seek. Audio mengikuti volume media HP.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Color(0xFF64748B), height: 1.5),
              ),
            ],
          );
        },
      ),
    ),
  );
}
