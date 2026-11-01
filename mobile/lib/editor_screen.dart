import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';

import 'download_controller.dart';
import 'download_models.dart';
import 'job_card.dart';
import 'preview_screen.dart';
import 'range_dialog.dart';
import 'studio_panels.dart';
import 'transcript_dialog.dart';
import 'render_progress_overlay.dart';
import 'rendered_clip_card.dart';
import 'delete_video_dialog.dart';
import 'marker_range_panel.dart';
import 'editor_workflow.dart';
import 'auto_cut_panel.dart';

class EditorScreen extends StatefulWidget {
  const EditorScreen({super.key, required this.job, required this.controller});
  final DownloadJob job;
  final DownloadController controller;
  @override
  State<EditorScreen> createState() => _EditorScreenState();
}

class _EditorScreenState extends State<EditorScreen> {
  late final player = VideoPlayerController.file(File(widget.job.path!));
  late final Future<void> initialized = player.initialize();
  final minimum = TextEditingController(text: '35'),
      maximum = TextEditingController(text: '180');
  final List<ClipSelection> picked = [];
  String language = 'auto', aspect = 'portrait', resolution = '720p';
  String framing = 'center';
  final analysisStart = TextEditingController(text: '0');
  final analysisEnd = TextEditingController();
  bool limitedAnalysis = false;
  int top = 10;
  int step = 0;
  bool automatic = false;
  bool combine = false, burn = true, startingRender = false;
  double draftStart = 0, draftEnd = 0;
  double get duration => widget.job.durationMs / 1000;
  DownloadController get controller => widget.controller;

  @override
  void initState() {
    super.initState();
    draftEnd = math.min(60, duration);
    analysisEnd.text = (duration / 60).toStringAsFixed(4);
    unawaited(load());
  }

  Future<void> load() async {
    await controller.openStudio(widget.job.id);
    if (!mounted || controller.snapshot.studio.id != widget.job.id) return;
    setState(() {
      picked.addAll(controller.snapshot.studio.lastRanges);
    });
  }

  @override
  void dispose() {
    player.dispose();
    analysisStart.dispose();
    analysisEnd.dispose();
    minimum.dispose();
    maximum.dispose();
    super.dispose();
  }

  bool selected(ClipSelection range) => picked.any(
    (item) =>
        (item.start - range.start).abs() < .001 &&
        (item.end - range.end).abs() < .001,
  );
  void toggle(ClipSelection range) => setState(() {
    if (selected(range)) {
      picked.removeWhere(
        (item) =>
            (item.start - range.start).abs() < .001 &&
            (item.end - range.end).abs() < .001,
      );
    } else if (picked.length < 12) {
      picked.add(range);
    }
  });
  Future<void> seek(double seconds) async {
    if (player.value.isInitialized) {
      await player.seekTo(Duration(milliseconds: (seconds * 1000).round()));
    }
  }

  Future<void> changeRange([int? index]) async {
    final input = index == null
        ? ClipSelection(
            start: draftStart,
            end: draftEnd,
            title: 'Rentang ${picked.length + 1}',
          )
        : picked[index];
    final range = await editRange(context, input, duration);
    if (range != null && mounted) {
      setState(() {
        if (index == null) {
          picked.add(range);
        } else {
          picked[index] = range;
        }
      });
    }
  }

  Future<void> analyze() async {
    final min = double.tryParse(minimum.text.replaceAll(',', '.'));
    final max = double.tryParse(maximum.text.replaceAll(',', '.'));
    if (min == null ||
        max == null ||
        !min.isFinite ||
        !max.isFinite ||
        min < 1 ||
        max <= min ||
        max > 600) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Durasi harus 1–600 detik; maksimum lebih besar dari minimum.',
          ),
        ),
      );
      return;
    }
    final start = limitedAnalysis
        ? double.tryParse(analysisStart.text.replaceAll(',', '.'))
        : 0.0;
    final end = limitedAnalysis
        ? double.tryParse(analysisEnd.text.replaceAll(',', '.'))
        : duration / 60;
    if (start == null ||
        end == null ||
        !start.isFinite ||
        !end.isFinite ||
        start < 0 ||
        end <= start ||
        end * 60 > duration + .01 ||
        (end - start) * 60 < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Rentang analisis harus di dalam video, minimal 1 detik.',
          ),
        ),
      );
      return;
    }
    await player.pause();
    await controller.analyze(
      widget.job.id,
      language: language,
      top: top,
      minDuration: min,
      maxDuration: max,
      analysisStart: limitedAnalysis ? start * 60 : null,
      analysisEnd: limitedAnalysis ? math.min(end * 60, duration) : null,
    );
  }

  Future<void> render(List<ClipSelection> ranges) async {
    final chosen = List<ClipSelection>.of(ranges);
    if (chosen.isEmpty ||
        chosen.length > 12 ||
        chosen.any((range) => !range.valid(duration))) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih rentang valid berdurasi 1–600 detik.'),
        ),
      );
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => startingRender = true);
    try {
      if (player.value.isInitialized) await player.pause();
      await controller.render(
        widget.job.id,
        chosen,
        combine: combine,
        burnSubtitles: burn && controller.snapshot.studio.segments.isNotEmpty,
        aspect: aspect,
        resolution: resolution,
        framing: framing,
      );
      if (mounted && controller.error == null) setState(() => step = 2);
    } finally {
      if (mounted) setState(() => startingRender = false);
    }
  }

  void goToStep(int next) {
    if (next != 0 && player.value.isInitialized) unawaited(player.pause());
    setState(() => step = next);
  }

  void configureMarkers(ClipSelection marker) {
    if (player.value.isInitialized) unawaited(player.pause());
    setState(() {
      picked
        ..clear()
        ..add(marker);
      step = 1;
    });
  }

  Future<void> deleteClip(StudioClip clip) async {
    if (!await confirmDeleteVideo(context, clip.title, source: false) ||
        !mounted) {
      return;
    }
    final bytes = await controller.deleteClip(widget.job.id, clip.name);
    if (mounted) showDeletionResult(context, bytes, controller.error);
  }

  Future<void> uploadClip(StudioClip clip) async {
    await player.pause();
    final opened = await controller.openYouTubeUpload(widget.job.id, clip);
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            opened
                ? 'Lanjutkan judul, privasi, dan konfirmasi upload di YouTube/Studio. Jangan hapus klip sampai unggah selesai.'
                : controller.error ?? 'Layar upload belum dapat dibuka.',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: controller,
    builder: (context, _) {
      final state = controller.snapshot.studio.id == widget.job.id
          ? controller.snapshot.studio
          : const StudioState();
      final locked =
          startingRender || controller.snapshot.active || controller.pending;
      final marker = ClipSelection(
        start: draftStart,
        end: draftEnd,
        title: 'Penanda manual',
      );
      final renderRanges = picked;
      final valid =
          renderRanges.isNotEmpty &&
          renderRanges.length <= 12 &&
          renderRanges.every((range) => range.valid(duration));
      final rendering =
          startingRender ||
          const {'rendering', 'cancelling'}.contains(state.status);
      final scanning = state.message.startsWith('Mendeteksi wajah');
      final preview = EditorVideo(
        range: marker,
        player: player,
        initialized: initialized,
        markStart: locked
            ? null
            : () => setState(() {
                draftStart = (player.value.position.inMilliseconds / 1000)
                    .clamp(0, duration)
                    .toDouble();
              }),
        markEnd: locked
            ? null
            : () => setState(() {
                draftEnd = (player.value.position.inMilliseconds / 1000)
                    .clamp(0, duration)
                    .toDouble();
              }),
      );
      return RenderProgressOverlay(
        visible: rendering,
        message:
            controller.error ??
            (startingRender ? 'Menyiapkan render…' : state.message),
        progress: startingRender || scanning || state.status == 'cancelling'
            ? null
            : state.progress / 100,
        cancelling: state.status == 'cancelling',
        onCancel: controller.pending || startingRender
            ? null
            : controller.cancel,
        child: Scaffold(
          appBar: AppBar(title: const Text('Editor & Auto Cut')),
          bottomNavigationBar: EditorWorkflowBar(
            step: step,
            count: picked.length,
            enabled:
                !locked &&
                (picked.isNotEmpty
                    ? valid
                    : step == 0 && !automatic && marker.valid(duration)),
            onBack: locked ? null : () => goToStep(0),
            onNext: () {
              if (step == 0) {
                if (picked.isEmpty) {
                  configureMarkers(marker);
                } else {
                  goToStep(1);
                }
              } else {
                render(renderRanges);
              }
            },
          ),
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 720),
                child: ListView(
                  key: ValueKey(step),
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
                  children: [
                    EditorWorkflowHeader(
                      step: step,
                      clips: state.clips.length,
                      onChanged: locked ? null : goToStep,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      widget.job.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (step == 0) ...[
                      SegmentedButton<bool>(
                        segments: const [
                          ButtonSegment(
                            value: false,
                            label: Text('Manual'),
                            icon: Icon(Icons.content_cut),
                          ),
                          ButtonSegment(
                            value: true,
                            label: Text('Auto Cut'),
                            icon: Icon(Icons.auto_awesome),
                          ),
                        ],
                        selected: {automatic},
                        onSelectionChanged: locked
                            ? null
                            : (value) =>
                                  setState(() => automatic = value.single),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        automatic
                            ? 'Cari rekomendasi, lalu centang bagian yang ingin dibuat.'
                            : 'Geser video ke bagian yang diinginkan. Tekan Set awal, lalu Set akhir.',
                      ),
                      const SizedBox(height: 12),
                      if (automatic)
                        ExpansionTile(
                          title: const Text('Lihat video sumber'),
                          children: [preview],
                        )
                      else
                        preview,
                      const SizedBox(height: 16),
                      if (!automatic)
                        MarkerRangePanel(
                          range: marker,
                          sourceDuration: duration,
                          locked: locked || startingRender,
                          actionLabel: picked.isEmpty
                              ? 'Gunakan penanda ini'
                              : 'Gunakan hanya penanda ini',
                          onContinue: () => configureMarkers(marker),
                          onAdd: picked.length >= 12
                              ? null
                              : () => changeRange(),
                        ),
                      const SizedBox(height: 16),
                      if (automatic) ...[
                        AutoCutPanel(
                          state: state,
                          locked: locked,
                          language: language,
                          top: top,
                          minimum: minimum,
                          maximum: maximum,
                          onLanguage: (value) =>
                              setState(() => language = value),
                          onTop: (value) => setState(() => top = value),
                          scope: Column(
                            children: [
                              SwitchListTile(
                                contentPadding: EdgeInsets.zero,
                                title: const Text('Analisis rentang tertentu'),
                                subtitle: Text(
                                  limitedAnalysis
                                      ? 'Hanya audio dalam rentang ini yang diproses.'
                                      : 'Seluruh video akan dianalisis.',
                                ),
                                value: limitedAnalysis,
                                onChanged: locked
                                    ? null
                                    : (value) => setState(
                                        () => limitedAnalysis = value,
                                      ),
                              ),
                              if (limitedAnalysis)
                                Row(
                                  children: [
                                    Expanded(
                                      child: TextField(
                                        controller: analysisStart,
                                        enabled: !locked,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Mulai (menit)',
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: TextField(
                                        controller: analysisEnd,
                                        enabled: !locked,
                                        keyboardType:
                                            const TextInputType.numberWithOptions(
                                              decimal: true,
                                            ),
                                        decoration: const InputDecoration(
                                          labelText: 'Selesai (menit)',
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 12),
                            ],
                          ),
                          onAnalyze: analyze,
                          onCancel: controller.cancel,
                        ),
                        const SizedBox(height: 20),
                        CandidatePanel(
                          candidates: state.candidates,
                          selected: selected,
                          toggle: toggle,
                          seek: seek,
                          enabled: !locked,
                        ),
                      ],
                    ],
                    if (controller.error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: Text(
                          controller.error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                          ),
                        ),
                      ),
                    const SizedBox(height: 24),
                    if (step == 1) ...[
                      const Text(
                        'Periksa klip dan tampilan video sebelum render.',
                      ),
                      const SizedBox(height: 16),
                      if (state.segments.isNotEmpty)
                        TranscriptPanel(
                          preview: EditorVideo(
                            player: player,
                            initialized: initialized,
                            markStart: null,
                            markEnd: null,
                            showMarkers: false,
                          ),
                          segments: state.segments,
                          seek: seek,
                          edit: locked
                              ? null
                              : (index) async {
                                  await player.pause();
                                  if (!context.mounted) return;
                                  final text = await editTranscriptText(
                                    context,
                                    state.segments[index].text,
                                  );
                                  if (text != null) {
                                    await controller.editTranscript(
                                      widget.job.id,
                                      index,
                                      text,
                                    );
                                  }
                                },
                        ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Klip dipilih (${picked.length}/12)',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: 'Tambah klip manual',
                            onPressed: locked || picked.length >= 12
                                ? null
                                : () => changeRange(),
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                      if (picked.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            'Belum ada klip. Kembali ke Pilih klip untuk menentukan bagian video.',
                          ),
                        ),
                      for (var index = 0; index < picked.length; index++)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            '${index + 1}. ${picked[index].title}',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${picked[index].start.toStringAsFixed(2)}–${picked[index].end.toStringAsFixed(2)} dtk',
                          ),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: 'Edit batas klip',
                                onPressed: locked
                                    ? null
                                    : () => changeRange(index),
                                icon: const Icon(Icons.edit_outlined),
                              ),
                              IconButton(
                                tooltip: 'Hapus dari pilihan',
                                onPressed: locked
                                    ? null
                                    : () => setState(() {
                                        picked.removeAt(index);
                                      }),
                                icon: const Icon(Icons.close),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 16),
                      Surface(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text(
                              'Tampilan video',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Row(
                              children: [
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: aspect,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Aspek',
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                        value: 'portrait',
                                        child: Text('9:16 · Shorts'),
                                      ),
                                      DropdownMenuItem(
                                        value: 'landscape',
                                        child: Text('16:9 · Lebar'),
                                      ),
                                    ],
                                    onChanged: locked
                                        ? null
                                        : (value) => setState(() {
                                            aspect = value!;
                                          }),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: DropdownButtonFormField<String>(
                                    initialValue: resolution,
                                    isExpanded: true,
                                    decoration: const InputDecoration(
                                      labelText: 'Resolusi',
                                    ),
                                    items: const ['720p', '1080p', '1440p']
                                        .map(
                                          (item) => DropdownMenuItem(
                                            value: item,
                                            child: Text(item),
                                          ),
                                        )
                                        .toList(),
                                    onChanged: locked
                                        ? null
                                        : (value) => setState(() {
                                            resolution = value!;
                                          }),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            DropdownButtonFormField<String>(
                              initialValue: framing,
                              isExpanded: true,
                              decoration: const InputDecoration(
                                labelText: 'Fokus gambar',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'follow',
                                  child: Text('Ikuti orang (wajah)'),
                                ),
                                DropdownMenuItem(
                                  value: 'center',
                                  child: Text('Crop tengah'),
                                ),
                                DropdownMenuItem(
                                  value: 'blur',
                                  child: Text('Video utuh + blur'),
                                ),
                              ],
                              onChanged: locked
                                  ? null
                                  : (value) => setState(() => framing = value!),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              framing == 'follow'
                                  ? 'Mengikuti wajah utama. Jika wajah tidak terlihat, kembali ke tengah. Proses tambahan saat render.'
                                  : framing == 'blur'
                                  ? 'Seluruh gambar tampil, dengan latar blur. Resolusi tinggi lebih berat.'
                                  : 'Potong tetap di tengah. Resolusi tinggi lebih berat untuk HP.',
                              style: TextStyle(
                                color: Color(0xFF64748B),
                                fontSize: 12,
                              ),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Gabung jadi satu video'),
                              value: combine,
                              onChanged: locked
                                  ? null
                                  : (value) => setState(() {
                                      combine = value;
                                    }),
                            ),
                            SwitchListTile(
                              contentPadding: EdgeInsets.zero,
                              title: const Text('Subtitle di video'),
                              subtitle: state.segments.isEmpty
                                  ? const Text(
                                      'Jalankan Auto Cut pada langkah Pilih klip untuk membuat subtitle.',
                                    )
                                  : null,
                              value: burn && state.segments.isNotEmpty,
                              onChanged: locked || state.segments.isEmpty
                                  ? null
                                  : (value) => setState(() {
                                      burn = value;
                                    }),
                            ),
                          ],
                        ),
                      ),
                    ],
                    if (step == 2) ...[
                      if (state.clips.isEmpty)
                        const Surface(
                          child: Text(
                            'Belum ada hasil. Pilih klip, atur tampilan, lalu tekan Render.',
                          ),
                        ),
                      Text(
                        'Klip selesai (${state.clips.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      for (final clip in state.clips.reversed)
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: RenderedClipCard(
                            clip: clip,
                            isNew:
                                clip.renderBatch ==
                                state.clips.last.renderBatch,
                            onDelete: locked ? null : () => deleteClip(clip),
                            onUpload: locked ? null : () => uploadClip(clip),
                            onPreview: controller.pending
                                ? null
                                : () => Navigator.push(
                                    context,
                                    MaterialPageRoute<void>(
                                      builder: (_) => PreviewScreen.file(
                                        title: clip.title,
                                        path: clip.path,
                                      ),
                                    ),
                                  ),
                            onSave: controller.pending
                                ? null
                                : () async {
                                    final saved = await controller.saveClip(
                                      widget.job.id,
                                      clip.name,
                                    );
                                    if (saved && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                            const SnackBar(
                                              content: Text('Klip tersimpan.'),
                                            ),
                                          );
                                    }
                                  },
                          ),
                        ),
                      if (state.metrics.isNotEmpty)
                        ExpansionTile(
                          title: const Text('Waktu pemrosesan'),
                          children: [
                            for (final entry in state.metrics.entries)
                              ListTile(
                                dense: true,
                                title: Text(entry.key),
                                trailing: Text(
                                  '${(entry.value / 1000).toStringAsFixed(1)} dtk',
                                ),
                              ),
                          ],
                        ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    },
  );
}
