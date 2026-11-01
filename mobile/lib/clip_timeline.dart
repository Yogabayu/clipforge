import 'package:flutter/material.dart';

import 'download_models.dart';

/// The playhead seeks independently; colored boundaries reflect Set awal/akhir.
class ClipTimeline extends StatelessWidget {
  const ClipTimeline({
    super.key,
    required this.positionMs,
    required this.durationMs,
    required this.onSeek,
    this.range,
  });
  final int positionMs, durationMs;
  final ClipSelection? range;
  final ValueChanged<double> onSeek;
  @override
  Widget build(BuildContext context) {
    final total = durationMs.toDouble().clamp(1, double.infinity).toDouble();
    return Column(
      children: [
        SizedBox(
          height: 48,
          child: Stack(
            children: [
              Positioned.fill(
                child: IgnorePointer(
                  child: CustomPaint(
                    painter: _Track(
                      start: range == null
                          ? null
                          : (range!.start * 1000 / total)
                                .clamp(0, 1)
                                .toDouble(),
                      end: range == null
                          ? null
                          : (range!.end * 1000 / total).clamp(0, 1).toDouble(),
                    ),
                  ),
                ),
              ),
              SliderTheme(
                data: SliderTheme.of(context).copyWith(
                  trackHeight: 8,
                  activeTrackColor: Colors.transparent,
                  inactiveTrackColor: Colors.transparent,
                  thumbColor: Colors.white,
                  thumbShape: const RoundSliderThumbShape(
                    enabledThumbRadius: 8,
                  ),
                  overlayShape: const RoundSliderOverlayShape(
                    overlayRadius: 22,
                  ),
                ),
                child: Slider(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  value: positionMs.toDouble().clamp(0, total),
                  max: total,
                  onChanged: onSeek,
                  semanticFormatterCallback: (value) =>
                      formatDuration(value.round()),
                ),
              ),
            ],
          ),
        ),
        if (range != null)
          Row(
            children: [
              Expanded(
                child: Text(
                  'Awal ${formatDuration((range!.start * 1000).round())}',
                  style: const TextStyle(
                    color: Color(0xFF34D399),
                    fontSize: 12,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  'Akhir ${formatDuration((range!.end * 1000).round())}',
                  textAlign: TextAlign.end,
                  style: const TextStyle(
                    color: Color(0xFFFBBF24),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _Track extends CustomPainter {
  const _Track({this.start, this.end});
  final double? start, end;
  @override
  void paint(Canvas canvas, Size size) {
    final width = (size.width - 32).clamp(0, double.infinity);
    final y = size.height / 2;
    final paint = Paint()..color = const Color(0xFF334155);
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromLTWH(16, y - 4, width.toDouble(), 8),
        const Radius.circular(4),
      ),
      paint,
    );
    if (start == null || end == null) return;
    final x1 = 16 + width * start!, x2 = 16 + width * end!;
    if (x2 > x1) {
      canvas.drawRect(
        Rect.fromLTRB(x1, y - 4, x2, y + 4),
        paint..color = const Color(0xFF3B82F6),
      );
    }
    for (final mark in [
      (x1, const Color(0xFF34D399)),
      (x2, const Color(0xFFFBBF24)),
    ]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(mark.$1 - 2, y - 13, 4, 26),
          const Radius.circular(2),
        ),
        paint..color = mark.$2,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _Track oldDelegate) =>
      oldDelegate.start != start || oldDelegate.end != end;
}
