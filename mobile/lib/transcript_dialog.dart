import 'package:flutter/material.dart';

Future<String?> editTranscriptText(BuildContext context, String initial) =>
    showDialog<String>(
      context: context,
      builder: (_) => _TranscriptDialog(initial),
    );

class _TranscriptDialog extends StatefulWidget {
  const _TranscriptDialog(this.initial);
  final String initial;
  @override
  State<_TranscriptDialog> createState() => _TranscriptDialogState();
}

class _TranscriptDialogState extends State<_TranscriptDialog> {
  late final input = TextEditingController(text: widget.initial);
  final form = GlobalKey<FormState>();
  @override
  void dispose() {
    input.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Koreksi subtitle'),
    content: Form(
      key: form,
      child: TextFormField(
        controller: input,
        autofocus: true,
        minLines: 3,
        maxLines: 7,
        maxLength: 2000,
        decoration: const InputDecoration(
          helperText: 'Dengarkan video, koreksi kata, lalu render ulang.',
          helperMaxLines: 2,
        ),
        validator: (value) => value == null || value.trim().isEmpty
            ? 'Teks tidak boleh kosong.'
            : null,
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
            Navigator.pop(context, input.text.trim());
          }
        },
        child: const Text('Simpan'),
      ),
    ],
  );
}
