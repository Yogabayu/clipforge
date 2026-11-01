import 'package:flutter/material.dart';

import 'download_models.dart';

class Surface extends StatelessWidget {
  const Surface({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(24),
      boxShadow: const [
        BoxShadow(
          color: Color(0x05000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
        BoxShadow(
          color: Color(0x08000000),
          blurRadius: 20,
          offset: Offset(0, 6),
        ),
      ],
    ),
    child: Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      clipBehavior: Clip.antiAlias,
      child: Padding(padding: const EdgeInsets.all(20), child: child),
    ),
  );
}

class JobCard extends StatelessWidget {
  const JobCard({
    super.key,
    required this.job,
    required this.onPreview,
    this.onSave,
    this.onCancel,
    this.onRetry,
    this.onEdit,
    this.onDelete,
  });
  final DownloadJob job;
  final VoidCallback? onPreview;
  final VoidCallback? onSave, onCancel, onRetry, onEdit;
  final VoidCallback? onDelete;

  @override
  Widget build(BuildContext context) {
    final transferring = job.stage == DownloadStage.downloading;
    final color = job.completed
        ? const Color(0xFF16A34A)
        : job.stage == DownloadStage.failed
        ? Theme.of(context).colorScheme.error
        : const Color(0xFF2563EB);
    return Surface(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(
                job.completed ? Icons.check_circle : Icons.downloading_rounded,
                color: color,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  job.stage.label,
                  style: TextStyle(fontWeight: FontWeight.w800, color: color),
                ),
              ),
              if (job.stage.active)
                Text(
                  '${job.progress.toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontFeatures: [FontFeature.tabularFigures()],
                    fontWeight: FontWeight.w700,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            job.title,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            job.message,
            style: const TextStyle(height: 1.5, color: Color(0xFF64748B)),
          ),
          if (job.stage.active) ...[
            const SizedBox(height: 18),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                minHeight: 6,
                value: transferring ? job.progress / 100 : null,
              ),
            ),
            const SizedBox(height: 10),
            if (transferring && job.transfer.isNotEmpty)
              Text(
                job.transfer,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  color: Color(0xFF64748B),
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            if (job.etaSeconds >= 0 && transferring)
              Text(
                'Sisa ±${job.etaSeconds} detik',
                style: const TextStyle(fontSize: 12),
              ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: onCancel,
              icon: const Icon(Icons.close),
              label: const Text('Batalkan'),
            ),
          ],
          if (job.completed) ...[
            const SizedBox(height: 12),
            Text(
              '${formatBytes(job.bytes)} · ${formatDuration(job.durationMs)} · MP4',
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 8,
              children: [
                if (onEdit != null)
                  FilledButton.icon(
                    onPressed: onEdit,
                    icon: const Icon(Icons.auto_awesome),
                    label: const Text('Editor / Auto Cut'),
                  ),
                FilledButton.icon(
                  onPressed: onPreview,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Preview'),
                ),
                OutlinedButton.icon(
                  onPressed: onSave,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('Simpan ke HP'),
                ),
              ],
            ),
          ],
          if (!job.stage.active && !job.completed)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Coba ulang'),
              ),
            ),
          if (!job.stage.active)
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline),
                style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error,
                ),
                label: const Text('Hapus download'),
              ),
            ),
          if (job.metrics.isNotEmpty || job.logs.isNotEmpty)
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text(
                'Detail & diagnostik',
                style: TextStyle(fontSize: 13),
              ),
              children: [
                for (final entry in job.metrics.entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            _metricLabel(entry.key),
                            style: const TextStyle(
                              fontSize: 12,
                              color: Color(0xFF64748B),
                            ),
                          ),
                        ),
                        Text(
                          entry.key.endsWith('Ms')
                              ? '${(entry.value / 1000).toStringAsFixed(1)} dtk'
                              : '${formatBytes(entry.value)}/s',
                          style: const TextStyle(
                            fontSize: 12,
                            fontFeatures: [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ),
                  ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 160,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      job.logs.join('\n'),
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 10,
                        height: 1.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  String _metricLabel(String key) =>
      const {
        'extractMs': 'Ekstraksi YouTube',
        'downloadMs': 'Download',
        'mergeMs': 'Merge audio/video',
        'validateMs': 'Validasi MP4',
        'totalMs': 'Total',
        'averageBytesPerSecond': 'Transfer rata-rata',
      }[key] ??
      key;
}
