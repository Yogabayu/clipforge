import 'package:flutter/material.dart';

import 'download_models.dart';
import 'job_card.dart';

class RenderedClipCard extends StatelessWidget {
  const RenderedClipCard({
    super.key,
    required this.clip,
    required this.isNew,
    required this.onPreview,
    this.onSave,
    this.onDelete,
    this.onUpload,
  });
  final StudioClip clip;
  final bool isNew;
  final VoidCallback? onPreview;
  final VoidCallback? onSave;
  final VoidCallback? onDelete;
  final VoidCallback? onUpload;

  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Text(
                clip.title,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            if (isNew)
              Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Semantics(
                  label: 'Video hasil render terbaru',
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDCFCE7),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'NEW',
                      style: TextStyle(
                        color: Color(0xFF166534),
                        fontSize: 11,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        Text('${formatBytes(clip.bytes)} · ${formatDuration(clip.durationMs)}'),
        Wrap(
          spacing: 8,
          children: [
            TextButton.icon(
              onPressed: onPreview,
              icon: const Icon(Icons.play_arrow),
              label: const Text('Preview'),
            ),
            TextButton.icon(
              onPressed: onSave,
              icon: const Icon(Icons.save_alt),
              label: const Text('Simpan ke HP'),
            ),
            TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              label: const Text('Hapus klip'),
            ),
            TextButton.icon(
              onPressed: onUpload,
              icon: const Icon(Icons.upload_outlined),
              label: const Text('Upload ke YouTube'),
            ),
          ],
        ),
      ],
    ),
  );
}
