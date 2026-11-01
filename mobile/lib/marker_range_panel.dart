import 'package:flutter/material.dart';

import 'download_models.dart';
import 'job_card.dart';

class MarkerRangePanel extends StatelessWidget {
  const MarkerRangePanel({
    super.key,
    required this.range,
    required this.sourceDuration,
    required this.locked,
    required this.onContinue,
    this.onAdd,
    this.actionLabel = 'Gunakan penanda ini',
  });
  final ClipSelection range;
  final double sourceDuration;
  final bool locked;
  final VoidCallback onContinue;
  final VoidCallback? onAdd;
  final String actionLabel;

  String get validation {
    if (range.valid(sourceDuration)) return '';
    if (range.end <= range.start) return 'Set akhir harus setelah Set awal.';
    if (range.duration < 1) return 'Pilih minimal 1 detik.';
    if (range.duration > 600) return 'Maksimal 10 menit per klip.';
    return 'Penanda harus berada di dalam video.';
  }

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Rentang dari penanda',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          'Awal ${range.start.toStringAsFixed(2)} dtk · Akhir ${range.end.toStringAsFixed(2)} dtk',
        ),
        const SizedBox(height: 8),
        Text(
          validation.isEmpty
              ? 'Durasi ${range.duration.toStringAsFixed(2)} detik. Lanjutkan untuk mengatur tampilan video.'
              : validation,
          style: TextStyle(
            fontSize: 12,
            color: validation.isEmpty
                ? const Color(0xFF64748B)
                : Theme.of(context).colorScheme.error,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('use-markers'),
          onPressed: locked || validation.isNotEmpty ? null : onContinue,
          icon: const Icon(Icons.movie_creation_outlined),
          label: Text(actionLabel),
        ),
        TextButton.icon(
          onPressed: locked || validation.isNotEmpty ? null : onAdd,
          icon: const Icon(Icons.playlist_add),
          label: const Text('Tambahkan ke daftar'),
        ),
      ],
    ),
  );
}
