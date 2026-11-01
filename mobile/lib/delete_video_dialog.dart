import 'package:flutter/material.dart';

import 'download_models.dart';

Future<bool> confirmDeleteVideo(
  BuildContext context,
  String title, {
  required bool source,
}) async =>
    await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          source ? 'Hapus download dan klip terkait?' : 'Hapus klip render?',
        ),
        content: SingleChildScrollView(
          child: Text(
            '$title\n\n${source ? 'Video download, transkrip, dan semua klip render terkait akan dihapus permanen dari ClipForge.' : 'Klip ini akan dihapus permanen. Video download dan klip lain tetap tersedia.'}\n\nSalinan yang sudah diekspor ke galeri/Downloads tidak ikut dihapus.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hapus permanen'),
          ),
        ],
      ),
    ) ??
    false;

void showDeletionResult(BuildContext context, int? bytes, String? error) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          bytes == null
              ? error ?? 'Penghapusan gagal.'
              : '${formatBytes(bytes)} data video dihapus.',
        ),
      ),
    );
