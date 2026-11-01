import 'package:flutter/material.dart';

import 'download_models.dart';

Future<ClipSelection?> editRange(
  BuildContext context,
  ClipSelection range,
  double sourceDuration,
) => showDialog<ClipSelection>(
  context: context,
  builder: (_) => _RangeDialog(range: range, duration: sourceDuration),
);

class _RangeDialog extends StatefulWidget {
  const _RangeDialog({required this.range, required this.duration});
  final ClipSelection range;
  final double duration;
  @override
  State<_RangeDialog> createState() => _RangeDialogState();
}

class _RangeDialogState extends State<_RangeDialog> {
  final form = GlobalKey<FormState>();
  late final start = TextEditingController(
    text: widget.range.start.toStringAsFixed(3),
  );
  late final end = TextEditingController(
    text: widget.range.end.toStringAsFixed(3),
  );
  late final title = TextEditingController(text: widget.range.title);
  double number(String text) =>
      double.tryParse(text.replaceAll(',', '.')) ?? double.nan;
  @override
  void dispose() {
    start.dispose();
    end.dispose();
    title.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit rentang'),
    content: SizedBox(
      width: 340,
      child: Form(
        key: form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: title,
                maxLength: 120,
                decoration: const InputDecoration(labelText: 'Judul klip'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('range-start'),
                controller: start,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Awal (detik)'),
                validator: (_) {
                  final value = number(start.text);
                  return value.isFinite && value >= 0 && value < widget.duration
                      ? null
                      : 'Awal di luar video.';
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const Key('range-end'),
                controller: end,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: 'Akhir (detik)'),
                validator: (_) =>
                    ClipSelection(
                      start: number(start.text),
                      end: number(end.text),
                      title: '',
                    ).valid(widget.duration)
                    ? null
                    : 'Durasi 1–600 detik; akhir maksimal ${widget.duration.toStringAsFixed(2)}.',
              ),
            ],
          ),
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Batal'),
      ),
      FilledButton(
        onPressed: () {
          if (form.currentState!.validate()) {
            Navigator.pop(
              context,
              ClipSelection(
                start: number(start.text),
                end: number(end.text),
                title: title.text.trim().isEmpty ? 'Klip' : title.text.trim(),
              ),
            );
          }
        },
        child: const Text('Simpan rentang'),
      ),
    ],
  );
}
