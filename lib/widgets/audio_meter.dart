import 'dart:math';
import 'package:flutter/material.dart';

class AudioMeterWidget extends StatefulWidget {
  final double rmsDb;
  final int peakAmplitude;
  final bool isSilence;
  final int bytesPerSec;
  final bool isCapturing;

  const AudioMeterWidget({
    super.key,
    required this.rmsDb,
    required this.peakAmplitude,
    required this.isSilence,
    required this.bytesPerSec,
    required this.isCapturing,
  });

  @override
  State<AudioMeterWidget> createState() => _AudioMeterWidgetState();
}

class _AudioMeterWidgetState extends State<AudioMeterWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  final List<double> _waveformBars = List.generate(24, (_) => 0.1);
  final Random _random = Random();

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 100),
    )..addListener(_updateWaveform);
    _animController.repeat();
  }

  void _updateWaveform() {
    if (!mounted) return;
    setState(() {
      if (widget.isCapturing && !widget.isSilence) {
        // Normalize dB (-90 to 0) to (0.0 to 1.0)
        final normalized = ((widget.rmsDb + 90) / 90).clamp(0.1, 1.0);
        for (int i = 0; i < _waveformBars.length; i++) {
          final jitter = (_random.nextDouble() - 0.5) * 0.3;
          _waveformBars[i] = (normalized + jitter).clamp(0.08, 1.0);
        }
      } else {
        // Flatline
        for (int i = 0; i < _waveformBars.length; i++) {
          _waveformBars[i] = 0.08;
        }
      }
    });
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isSilent = widget.isSilence || !widget.isCapturing;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSilent
              ? Colors.grey.withValues(alpha: 0.3)
              : theme.colorScheme.primary.withValues(alpha: 0.5),
          width: 1.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    isSilent ? Icons.volume_mute : Icons.graphic_eq,
                    color: isSilent ? Colors.grey : theme.colorScheme.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Real-Time Audio Monitor',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: isSilent
                      ? Colors.orange.withValues(alpha: 0.2)
                      : Colors.green.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  isSilent ? 'SILENCE / IDLE' : 'ACTIVE AUDIO',
                  style: TextStyle(
                    color: isSilent ? Colors.orange : Colors.green,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          // Animated Waveform Bars
          SizedBox(
            height: 52,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: List.generate(_waveformBars.length, (index) {
                final height = _waveformBars[index] * 48;
                return AnimatedContainer(
                  duration: const Duration(milliseconds: 90),
                  width: 5,
                  height: max(4.0, height),
                  decoration: BoxDecoration(
                    color: isSilent
                        ? Colors.grey.withValues(alpha: 0.4)
                        : theme.colorScheme.primary,
                    borderRadius: BorderRadius.circular(3),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 12),
          // Telemetry Stats Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Level: ${widget.rmsDb.toStringAsFixed(1)} dBFS',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              Text(
                'Throughput: ${(widget.bytesPerSec / 1024).toStringAsFixed(1)} KB/s',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
              Text(
                'Peak: ${widget.peakAmplitude}',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.grey),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
