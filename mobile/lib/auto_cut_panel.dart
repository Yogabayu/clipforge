import 'package:flutter/material.dart';

import 'download_models.dart';
import 'job_card.dart';

class AutoCutPanel extends StatelessWidget {
  const AutoCutPanel({
    super.key,
    required this.state,
    required this.locked,
    required this.language,
    required this.top,
    required this.minimum,
    required this.maximum,
    required this.onLanguage,
    required this.onTop,
    required this.onAnalyze,
    required this.onCancel,
    this.scope,
  });
  final Widget? scope;
  final StudioState state;
  final bool locked;
  final String language;
  final int top;
  final TextEditingController minimum, maximum;
  final ValueChanged<String> onLanguage;
  final ValueChanged<int> onTop;
  final VoidCallback onAnalyze;
  final VoidCallback? onCancel;
  @override
  Widget build(BuildContext context) => Surface(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          'Cari bagian menarik otomatis',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        const Text(
          'Pilih bahasa lalu mulai. Proses pertama mengunduh model ~190 MB. Setelah itu, analisis berjalan di HP.',
          style: TextStyle(fontSize: 12, height: 1.5, color: Color(0xFF64748B)),
        ),
        const SizedBox(height: 16),
        ?scope,
        DropdownButtonFormField<String>(
          initialValue: language,
          isExpanded: true,
          decoration: const InputDecoration(labelText: 'Bahasa ucapan'),
          items: const [
            DropdownMenuItem(value: 'auto', child: Text('Deteksi otomatis')),
            DropdownMenuItem(value: 'id', child: Text('Indonesia')),
            DropdownMenuItem(value: 'en', child: Text('English')),
          ],
          onChanged: locked ? null : (value) => onLanguage(value!),
        ),
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text('Atur rekomendasi'),
          subtitle: Text('$top klip · ${minimum.text}–${maximum.text} detik'),
          children: [
            DropdownButtonFormField<int>(
              initialValue: top,
              decoration: const InputDecoration(
                labelText: 'Jumlah rekomendasi',
              ),
              items: List.generate(
                12,
                (index) => DropdownMenuItem(
                  value: index + 1,
                  child: Text('${index + 1} klip'),
                ),
              ),
              onChanged: locked ? null : (value) => onTop(value!),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: minimum,
                    enabled: !locked,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Min. detik'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: maximum,
                    enabled: !locked,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Maks. detik'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          key: const Key('analyze-button'),
          onPressed: locked ? null : onAnalyze,
          icon: const Icon(Icons.auto_awesome),
          label: const Text('Cari rekomendasi klip'),
        ),
        if (state.message.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(
            state.message,
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
        ],
        if (state.active) ...[
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: const {'audio', 'scoring'}.contains(state.status)
                ? null
                : state.progress / 100,
          ),
          const SizedBox(height: 8),
          if (!const {'audio', 'scoring'}.contains(state.status))
            Text('${state.progress.toStringAsFixed(0)}%'),
          OutlinedButton(
            onPressed: state.status == 'cancelling' ? null : onCancel,
            child: const Text('Batalkan proses'),
          ),
        ],
      ],
    ),
  );
}
