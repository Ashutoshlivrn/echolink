import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../models/session_model.dart';
import '../../services/session_controller.dart';
import '../../widgets/audio_meter.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_badge.dart';
import 'widgets/qr_scanner_dialog.dart';

class ReceiverScreen extends StatefulWidget {
  const ReceiverScreen({super.key});

  @override
  State<ReceiverScreen> createState() => _ReceiverScreenState();
}

class _ReceiverScreenState extends State<ReceiverScreen> {
  final TextEditingController _sessionInputController = TextEditingController();

  @override
  void dispose() {
    _sessionInputController.dispose();
    super.dispose();
  }

  void _scanQrCode() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) => const QrScannerDialog(),
    );

    if (result != null && mounted) {
      final code = result['sessionId'] as String?;
      if (code != null && code.isNotEmpty) {
        _sessionInputController.text = code;
        final controller = context.read<SessionController>();
        controller.joinSession(code);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<SessionController>();
    final isConnected = controller.state == SessionState.streaming;
    final isWaiting = controller.state == SessionState.waitingApproval;
    final isConnecting = controller.state == SessionState.connecting;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmDisconnect(context, controller);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Listen to Audio (Friend)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _confirmDisconnect(context, controller),
          ),
          actions: [
            if (!isConnected && !isWaiting)
              IconButton(
                icon: const Icon(Icons.qr_code_scanner_rounded),
                tooltip: 'Scan QR Code',
                onPressed: _scanQrCode,
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Connection Status Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(
                        isConnected
                            ? Icons.headphones_rounded
                            : isWaiting
                                ? Icons.hourglass_top_rounded
                                : Icons.podcasts_rounded,
                        size: 48,
                        color: isConnected
                            ? Colors.green
                            : isWaiting
                                ? Colors.orange
                                : theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        isConnected
                            ? 'Streaming Audio Live'
                            : isWaiting
                                ? 'Waiting for Host Approval'
                                : isConnecting
                                    ? 'Connecting to Host...'
                                    : 'Enter Session ID to Join',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        isConnected
                            ? 'Audio from host is streaming into your earphones'
                            : isWaiting
                                ? 'Host was notified and must tap Accept'
                                : 'Ask your friend for their 6-letter Session ID',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: Colors.grey,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          if (controller.activeAudioDevice != null)
                            StatusBadge(
                              label: controller.activeAudioDevice!.name,
                              icon: controller.activeAudioDevice!.isBluetooth
                                  ? Icons.bluetooth_audio_rounded
                                  : Icons.volume_up_rounded,
                              color: controller.activeAudioDevice!.isBluetooth
                                  ? Colors.teal
                                  : Colors.grey,
                            ),
                          if (isConnected)
                            StatusBadge(
                              label: controller.connectionStats.transport,
                              icon: Icons.speed_rounded,
                              color: Colors.blue,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // If not joined yet, show input box
              if (!isConnected && !isWaiting) ...[
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextField(
                          controller: _sessionInputController,
                          textCapitalization: TextCapitalization.characters,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 3,
                          ),
                          textAlign: TextAlign.center,
                          decoration: InputDecoration(
                            labelText: 'SESSION ID',
                            hintText: 'e.g. A9F2K4',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.qr_code_scanner_rounded),
                              onPressed: _scanQrCode,
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        CustomButton(
                          text: 'Join Session',
                          icon: Icons.login_rounded,
                          isLoading: isConnecting,
                          onPressed: () {
                            controller.joinSession(_sessionInputController.text);
                          },
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Error display
              if (controller.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade800),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          controller.errorMessage!,
                          style: TextStyle(color: Colors.red.shade900),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Volume & Audio Controls (when connected)
              if (isConnected) ...[
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Earphone Playback Volume',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Icon(
                              controller.playerVolume == 0
                                  ? Icons.volume_off
                                  : Icons.volume_up,
                              color: theme.colorScheme.primary,
                            ),
                            Expanded(
                              child: Slider(
                                value: controller.playerVolume,
                                min: 0.0,
                                max: 1.0,
                                onChanged: (val) => controller.setVolume(val),
                              ),
                            ),
                            Text(
                              '${(controller.playerVolume * 100).toInt()}%',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Audio Receiving Waveform
                AudioMeterWidget(
                  rmsDb: controller.diagnostics.rmsDb,
                  peakAmplitude: controller.diagnostics.peakAmplitude,
                  isSilence: controller.diagnostics.isSilence,
                  bytesPerSec: controller.connectionStats.bytesReceived,
                  isCapturing: true,
                ),
                const SizedBox(height: 24),
              ],

              // Disconnect Button
              if (isConnected || isWaiting)
                CustomButton(
                  text: 'Disconnect',
                  icon: Icons.logout_rounded,
                  isDestructive: true,
                  onPressed: () => _confirmDisconnect(context, controller),
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmDisconnect(BuildContext context, SessionController controller) {
    if (controller.state == SessionState.idle) {
      Navigator.of(context).pop();
      return;
    }

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Disconnect from Session?'),
        content: const Text('You will stop receiving audio from the host.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () async {
              Navigator.of(ctx).pop();
              await controller.disconnectSession();
              if (context.mounted) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
  }
}
