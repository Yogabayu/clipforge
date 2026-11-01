import 'package:flutter/material.dart';

/// Declarative modal: follows native state without pushing/popping editor routes.
class RenderProgressOverlay extends StatelessWidget {
  const RenderProgressOverlay({
    super.key,
    required this.child,
    required this.visible,
    required this.message,
    required this.progress,
    required this.cancelling,
    this.onCancel,
  });
  final Widget child;
  final bool visible, cancelling;
  final String message;
  final double? progress;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !visible,
    child: Stack(
      fit: StackFit.expand,
      children: [
        ExcludeSemantics(excluding: visible, child: child),
        if (visible) ...[
          const ModalBarrier(dismissible: false, color: Color(0x990F172A)),
          Center(
            child: Dialog(
              constraints: const BoxConstraints(maxWidth: 480),
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        cancelling ? 'Membatalkan proses…' : 'Merender video',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 16),
                      Text(message.isEmpty ? 'Menyiapkan render…' : message),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(value: progress?.clamp(0, 1)),
                      const SizedBox(height: 12),
                      Text(
                        progress == null
                            ? 'Mohon tunggu…'
                            : '${(progress! * 100).round()}%',
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      TextButton(
                        onPressed: cancelling ? null : onCancel,
                        child: Text(
                          cancelling
                              ? 'Menunggu proses berhenti…'
                              : 'Batalkan render',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
