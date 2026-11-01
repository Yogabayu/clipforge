import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'download_controller.dart';
import 'download_models.dart';
import 'job_card.dart';
import 'preview_screen.dart';
import 'editor_screen.dart';
import 'delete_video_dialog.dart';

class DownloadScreen extends StatefulWidget {
  const DownloadScreen({super.key});
  @override
  State<DownloadScreen> createState() => _DownloadScreenState();
}

class _DownloadScreenState extends State<DownloadScreen> {
  final controller = DownloadController();
  final url = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(controller.initialize());
  }

  @override
  void dispose() {
    controller.dispose();
    url.dispose();
    super.dispose();
  }

  Future<void> save(DownloadJob job) async {
    final saved = await controller.saveVideo(job.id);
    if (saved && mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Video tersimpan.')));
    }
  }

  Future<void> deleteDownload(DownloadJob job) async {
    if (!await confirmDeleteVideo(context, job.title, source: true) ||
        !mounted) {
      return;
    }
    final bytes = await controller.deleteDownload(job.id);
    if (mounted) showDeletionResult(context, bytes, controller.error);
  }

  void preview(DownloadJob job) => Navigator.of(context)
      .push<void>(MaterialPageRoute(builder: (_) => PreviewScreen(job: job)));

  void edit(DownloadJob job) => Navigator.of(context).push<void>(
    MaterialPageRoute(
      builder: (_) => EditorScreen(job: job, controller: controller),
    ),
  );

  Future<void> paste() async {
    final value = await Clipboard.getData(Clipboard.kTextPlain);
    if (mounted && value?.text != null) {
      setState(() {
        url.text = value!.text!;
      });
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final state = controller.snapshot;
      final job = state.current;
      final canStart = state.ready && !state.active && !controller.pending;
      final history = state.history
          .where((item) => item.id != job?.id)
          .toList();
      return Scaffold(
        appBar: AppBar(
          title: const Row(
            children: [
              Icon(Icons.movie_creation_outlined, color: Color(0xFF2563EB)),
              SizedBox(width: 10),
              Text('ClipForge', style: TextStyle(fontWeight: FontWeight.w800)),
            ],
          ),
          actions: [
            IconButton(
              tooltip: 'Lisensi',
              icon: const Icon(Icons.info_outline),
              onPressed: () => showLicensePage(
                context: context,
                applicationName: 'ClipForge Mobile',
                applicationVersion: '0.4.5',
                applicationLegalese: 'Download hanya konten yang diizinkan. Engine diproses lokal di Android.',
              ),
            ),
            const SizedBox(width: 8),
          ],
        ),
        body: SafeArea(
          child: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 680),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  const Text(
                    'Video YouTube,\nlangsung di HP.',
                    style: TextStyle(
                      fontSize: 32,
                      height: 1.15,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -1,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Tempel tautan. Download, preview, simpan.\nSeluruh proses berjalan lokal di Android.',
                    style: TextStyle(height: 1.6, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 24),
                  Surface(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'TAUTAN VIDEO',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.3,
                            color: Color(0xFF64748B),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          key: const Key('youtube-url'),
                          controller: url,
                          enabled: !state.active,
                          keyboardType: TextInputType.url,
                          autocorrect: false,
                          maxLines: 2,
                          minLines: 1,
                          decoration: InputDecoration(
                            hintText: 'https://youtu.be/…',
                            prefixIcon: const Icon(Icons.link),
                            suffixIcon: IconButton(
                              tooltip: 'Tempel tautan',
                              onPressed: state.active ? null : paste,
                              icon: const Icon(Icons.content_paste),
                            ),
                          ),
                          onSubmitted: (value) {
                            if (canStart) unawaited(controller.start(value));
                          },
                        ),
                        const SizedBox(height: 14),
                        const Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _Tag(
                              icon: Icons.high_quality_outlined,
                              text: 'Maks. 720p',
                            ),
                            _Tag(
                              icon: Icons.audiotrack_outlined,
                              text: 'MP4 + audio',
                            ),
                            _Tag(
                              icon: Icons.phone_android,
                              text: 'Tanpa server',
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        FilledButton.icon(
                          key: const Key('download-button'),
                          onPressed: canStart
                              ? () {
                                  FocusScope.of(context).unfocus();
                                  unawaited(controller.start(url.text));
                                }
                              : null,
                          icon: const Icon(Icons.download_rounded),
                          label: const Text('Download video'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 14),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        state.ready
                            ? Icons.check_circle
                            : Icons.settings_outlined,
                        size: 17,
                        color: state.ready
                            ? const Color(0xFF16A34A)
                            : const Color(0xFF64748B),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          state.engineMessage,
                          style: const TextStyle(
                            fontSize: 12,
                            height: 1.5,
                            color: Color(0xFF64748B),
                          ),
                        ),
                      ),
                      if (!state.ready)
                        IconButton(
                          tooltip: 'Periksa ulang engine',
                          onPressed: controller.pending
                              ? null
                              : controller.retryEngine,
                          icon: const Icon(Icons.refresh),
                        ),
                    ],
                  ),
                  if (controller.error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Surface(
                        child: Text(
                          controller.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    ),
                  if (state.studio.active) ...[
                    const SizedBox(height: 16),
                    Surface(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(state.studio.message),
                          const SizedBox(height: 10),
                          LinearProgressIndicator(
                            value: state.studio.progress / 100,
                          ),
                          TextButton(
                            onPressed: () {
                              final sources = [?job, ...state.history];
                              final matches = sources.where(
                                (source) => source.id == state.studio.id,
                              );
                              if (matches.isNotEmpty) edit(matches.first);
                            },
                            child: const Text('Lihat proses editor'),
                          ),
                        ],
                      ),
                    ),
                  ],
                  if (job != null) ...[
                    const SizedBox(height: 24),
                    JobCard(
                      job: job,
                      onEdit: job.completed && !controller.pending
                          ? () => edit(job)
                          : null,
                      onPreview: controller.pending ? null : () => preview(job),
                      onDelete: state.active || controller.pending
                          ? null
                          : () => deleteDownload(job),
                      onSave: controller.pending ? null : () => save(job),
                      onCancel:
                          controller.pending ||
                              job.stage == DownloadStage.cancelling
                          ? null
                          : controller.cancel,
                      onRetry: canStart
                          ? () {
                              url.text = job.url;
                              unawaited(controller.start(job.url));
                            }
                          : null,
                    ),
                  ],
                  const SizedBox(height: 28),
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Download sebelumnya',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: controller.pending
                            ? null
                            : () async {
                                final saved = await controller
                                    .saveDiagnostics();
                                if (saved && context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Log diagnostik tersimpan.',
                                      ),
                                    ),
                                  );
                                }
                              },
                        icon: const Icon(Icons.bug_report_outlined, size: 18),
                        label: const Text('Log'),
                      ),
                    ],
                  ),
                  if (history.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 24),
                      child: Column(
                        children: [
                          Icon(
                            Icons.video_library_outlined,
                            size: 32,
                            color: Color(0xFF94A3B8),
                          ),
                          SizedBox(height: 10),
                          Text(
                            'Hasil download akan muncul di sini.',
                            style: TextStyle(color: Color(0xFF64748B)),
                          ),
                        ],
                      ),
                    ),
                  for (final item in history)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.title,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              '${formatBytes(item.bytes)} · ${formatDuration(item.durationMs)}',
                              style: const TextStyle(color: Color(0xFF64748B)),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 8,
                              children: [
                                TextButton.icon(
                                  onPressed: controller.pending
                                      ? null
                                      : () => edit(item),
                                  icon: const Icon(Icons.auto_awesome),
                                  label: const Text('Editor / Auto Cut'),
                                ),
                                TextButton.icon(
                                  onPressed: controller.pending
                                      ? null
                                      : () => preview(item),
                                  icon: const Icon(Icons.play_arrow),
                                  label: const Text('Preview'),
                                ),
                                TextButton.icon(
                                  onPressed: controller.pending
                                      ? null
                                      : () => save(item),
                                  icon: const Icon(Icons.save_alt),
                                  label: const Text('Simpan'),
                                ),
                                TextButton.icon(
                                  onPressed: state.active || controller.pending
                                      ? null
                                      : () => deleteDownload(item),
                                  icon: const Icon(Icons.delete_outline),
                                  style: TextButton.styleFrom(
                                    foregroundColor: Theme.of(context)
                                        .colorScheme
                                        .error,
                                  ),
                                  label: const Text('Hapus download'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 20),
                  const Text(
                    'Download → transkripsi lokal → pilih rentang → render. Semua diproses di HP.',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

class _Tag extends StatelessWidget {
  const _Tag({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0xFFEFF6FF),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 15, color: const Color(0xFF2563EB)),
          const SizedBox(width: 5),
          Text(
            text,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: Color(0xFF1D4ED8),
            ),
          ),
        ],
      ),
    ),
  );
}
