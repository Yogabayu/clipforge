import 'package:flutter/material.dart';

const _steps = ['Pilih klip', 'Atur video', 'Hasil'];

/// Navigation stays visible while long recommendations or settings scroll.
class EditorWorkflowHeader extends StatelessWidget {
  const EditorWorkflowHeader({
    super.key,
    required this.step,
    required this.clips,
    this.onChanged,
  });
  final int step, clips;
  final ValueChanged<int>? onChanged;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Langkah ${step + 1} dari 3',
        style: const TextStyle(color: Color(0xFF64748B)),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          for (var index = 0; index < _steps.length; index++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      vertical: 12,
                      horizontal: 4,
                    ),
                    backgroundColor: index == step
                        ? const Color(0xFFDBEAFE)
                        : null,
                    foregroundColor: index == step
                        ? const Color(0xFF1D4ED8)
                        : const Color(0xFF64748B),
                  ),
                  onPressed: onChanged == null || index == 1 && step == 0
                      ? null
                      : () => onChanged!(index),
                  child: Text(
                    '${index + 1}. ${_steps[index]}${index == 2 && clips > 0 ? ' ($clips)' : ''}',
                    textAlign: TextAlign.center,
                  ),
                ),
              ),
            ),
        ],
      ),
    ],
  );
}

class EditorWorkflowBar extends StatelessWidget {
  const EditorWorkflowBar({
    super.key,
    required this.step,
    required this.count,
    required this.enabled,
    required this.onNext,
    this.onBack,
  });
  final int step, count;
  final bool enabled;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  @override
  Widget build(BuildContext context) {
    if (step == 2) {
      return Material(
        color: Theme.of(context).colorScheme.surface,
        elevation: 8,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: OutlinedButton.icon(
              onPressed: onBack,
              icon: const Icon(Icons.content_cut),
              label: const Text('Buat klip lain'),
            ),
          ),
        ),
      );
    }
    return Material(
      color: Theme.of(context).colorScheme.surface,
      elevation: 8,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                count == 0
                    ? 'Pilih bagian video untuk melanjutkan'
                    : '$count klip dipilih',
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  if (step > 0) ...[
                    IconButton(
                      tooltip: 'Kembali ke Pilih klip',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Expanded(
                    child: FilledButton.icon(
                      key: Key(
                        step == 0 ? 'configure-button' : 'render-button',
                      ),
                      onPressed: enabled ? onNext : null,
                      icon: Icon(
                        step == 0
                            ? Icons.arrow_forward
                            : Icons.movie_creation_outlined,
                      ),
                      label: Text(
                        step == 0 ? 'Lanjut: atur video' : 'Render $count klip',
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
