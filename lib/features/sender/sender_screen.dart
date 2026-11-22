import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../models/session_model.dart';
import '../../services/session_controller.dart';
import '../../widgets/audio_meter.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_badge.dart';
import 'widgets/qr_code_dialog.dart';

class SenderScreen extends StatelessWidget {
  const SenderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<SessionController>();
    final isError = controller.state == SessionState.error;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          _confirmExit(context, controller);
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Sharing Audio (Host)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => _confirmExit(context, controller),
          ),
          actions: [
            if (controller.sessionId != null)
              IconButton(
                icon: const Icon(Icons.qr_code_2_rounded),
                tooltip: 'Show QR Code',
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (_) => QrCodeDialog(
                      sessionId: controller.sessionId!,
                    ),
                  );
                },
              ),
          ],
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Session ID Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Text(
                        'SESSION ID',
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: Colors.grey,
                          letterSpacing: 1.5,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            controller.sessionId ?? (isError ? 'FAILED' : 'GENERATING...'),
                            style: theme.textTheme.headlineMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 4,
                              color: isError ? Colors.red : theme.colorScheme.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            icon: const Icon(Icons.copy_rounded, size: 20),
                            tooltip: 'Copy Session ID',
                            onPressed: () {
                              if (controller.sessionId != null) {
                                Clipboard.setData(
                                  ClipboardData(text: controller.sessionId!),
                                );
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Session ID copied to clipboard'),
                                  ),
                                );
                              }
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        alignment: WrapAlignment.center,
                        children: [
                          StatusBadge(
                            label: controller.isCapturing
                                ? 'Capturing Audio'
                                : 'Capture Idle',
                            icon: controller.isCapturing
                                ? Icons.mic_rounded
                                : Icons.mic_off_rounded,
                            color: controller.isCapturing
                                ? Colors.green
                                : Colors.grey,
                          ),
                          StatusBadge(
                            label: controller.connectionStats.transport,
                            icon: Icons.wifi_tethering_rounded,
                            color: Colors.blue,
                          ),
                          if (controller.activeAudioDevice != null)
                            StatusBadge(
                              label: controller.activeAudioDevice!.name,
                              icon: controller.activeAudioDevice!.isBluetooth
                                  ? Icons.bluetooth_audio_rounded
                                  : Icons.volume_up_rounded,
                              color: Colors.teal,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Signaling / Connection Error Banner
              if (controller.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.error_outline, color: Colors.red.shade800),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Connection Error',
                              style: TextStyle(
                                color: Colors.red.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        controller.errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade900,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 10),
                      OutlinedButton.icon(
                        onPressed: () => controller.startSharing(),
                        icon: const Icon(Icons.refresh_rounded, size: 16),
                        label: const Text('Retry Connection'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Warning Banner (e.g., if Instagram or protected app produces silence)
              if (controller.warningMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.orange.shade300),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade800),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          controller.warningMessage!,
                          style: TextStyle(
                            color: Colors.orange.shade900,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Incoming Connection Approval Dialog Banner
              if (controller.pendingRequest != null) ...[
                Card(
                  color: Colors.indigo.shade50,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                    side: BorderSide(color: Colors.indigo.shade300, width: 1.5),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.person_add_rounded,
                                color: Colors.indigo),
                            const SizedBox(width: 8),
                            Text(
                              'Connection Request',
                              style: theme.textTheme.titleMedium?.copyWith(
                                color: Colors.indigo.shade900,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${controller.pendingRequest!.name} wants to join and listen to your audio.',
                          style: TextStyle(color: Colors.indigo.shade800),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: () =>
                                    controller.rejectIncomingRequest(),
                                child: const Text('Decline'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: () =>
                                    controller.acceptIncomingRequest(),
                                child: const Text('Accept & Stream'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Real-Time Audio VU Meter & Waveform
              AudioMeterWidget(
                rmsDb: controller.diagnostics.rmsDb,
                peakAmplitude: controller.diagnostics.peakAmplitude,
                isSilence: controller.diagnostics.isSilence,
                bytesPerSec: controller.diagnostics.bytesPerSecond,
                isCapturing: controller.isCapturing,
              ),
              const SizedBox(height: 16),

              // Live Talk / Two-Way Voice Card (Host)
              Card(
                elevation: 1,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: controller.isMicEnabled
                            ? Colors.red.shade100
                            : Colors.grey.shade200,
                        child: Icon(
                          controller.isMicEnabled
                              ? Icons.mic_rounded
                              : Icons.mic_off_rounded,
                          color: controller.isMicEnabled
                              ? Colors.red.shade800
                              : Colors.grey.shade700,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Live Talk (Two-Way Voice)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                              ),
                            ),
                            Text(
                              controller.isMicEnabled
                                  ? 'Microphone is ON — listeners can hear you'
                                  : 'Microphone is OFF (Tap to speak)',
                              style: TextStyle(
                                color: controller.isMicEnabled
                                    ? Colors.red.shade800
                                    : Colors.grey.shade600,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: controller.isMicEnabled,
                        onChanged: (_) => controller.toggleMic(context),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Connected Participants Card
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
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Connected Listeners (${controller.participants.length})',
                            style: theme.textTheme.titleSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (controller.participants.isEmpty)
                            const Text(
                              'Waiting for friend to join...',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (controller.participants.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(24),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.headphones_rounded,
                                  size: 40, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                'Share the Session ID above with your friend',
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: Colors.grey,
                                ),
                              ),
                            ],
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: controller.participants.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final participant = controller.participants[index];
                            return ListTile(
                              leading: const CircleAvatar(
                                child: Icon(Icons.person, size: 20),
                              ),
                              title: Text(participant.name),
                              subtitle: Text('Status: ${participant.status.name}'),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    participant.isMicEnabled
                                        ? Icons.mic_rounded
                                        : Icons.mic_off_rounded,
                                    color: participant.isMicEnabled
                                        ? Colors.red
                                        : Colors.grey,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                    size: 20,
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Actions
              CustomButton(
                text: controller.isCapturing
                    ? 'Pause Audio Capture'
                    : 'Resume Audio Capture',
                icon: controller.isCapturing
                    ? Icons.pause_rounded
                    : Icons.play_arrow_rounded,
                isSecondary: true,
                onPressed: () => controller.toggleAudioCapture(),
              ),
              const SizedBox(height: 12),
              CustomButton(
                text: 'End Sharing Session',
                icon: Icons.call_end_rounded,
                isDestructive: true,
                onPressed: () => _confirmExit(context, controller),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmExit(BuildContext context, SessionController controller) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('End Audio Sharing?'),
        content: const Text(
          'This will stop audio capture and disconnect all connected friends.',
        ),
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
            child: const Text('End Session'),
          ),
        ],
      ),
    );
  }
}
