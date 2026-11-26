import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import '../../models/session_model.dart';
import '../../services/session_controller.dart';
import '../../widgets/audio_meter.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/status_badge.dart';
import 'widgets/qr_code_dialog.dart';

class SenderScreen extends StatefulWidget {
  const SenderScreen({super.key});

  @override
  State<SenderScreen> createState() => _SenderScreenState();
}

class _SenderScreenState extends State<SenderScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showGuide = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<SessionController>();
    final isError = controller.state == SessionState.error;
    final isGenerating = controller.sessionId == null && !isError;

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
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // First-Time Host Walkthrough Guide Banner
              if (_showGuide) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: const Color(0xFF6366F1).withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF6366F1).withValues(alpha: 0.3),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.lightbulb_rounded,
                              color: Color(0xFF6366F1), size: 20),
                          const SizedBox(width: 8),
                          const Text(
                            'Host Walkthrough Guide',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF6366F1),
                              fontSize: 14,
                            ),
                          ),
                          const Spacer(),
                          IconButton(
                            icon: const Icon(Icons.close, size: 16),
                            padding: EdgeInsets.zero,
                            constraints: const BoxConstraints(),
                            onPressed: () =>
                                setState(() => _showGuide = false),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        '1. Share your 6-letter Session ID or QR code with your friend.\n'
                        '2. Play media (YouTube, music player, games) on your phone normally.\n'
                        '3. Accept your friend\'s connection request when it appears below!',
                        style: TextStyle(fontSize: 13, height: 1.4),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Session ID Card (with Skeleton Shimmer when generating)
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
                      isGenerating
                          ? FadeTransition(
                              opacity: _pulseAnimation,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: 14, horizontal: 24),
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.primaryContainer
                                      .withValues(alpha: 0.4),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      'Connecting to Cloud...',
                                      style: TextStyle(
                                        color: theme.colorScheme.primary,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  controller.sessionId ?? 'FAILED',
                                  style: theme.textTheme.headlineMedium
                                      ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 4,
                                    color: isError
                                        ? Colors.red
                                        : theme.colorScheme.primary,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(Icons.copy_rounded, size: 20),
                                  tooltip: 'Copy Session ID',
                                  onPressed: () {
                                    if (controller.sessionId != null) {
                                      Clipboard.setData(
                                        ClipboardData(
                                            text: controller.sessionId!),
                                      );
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                              'Session ID copied to clipboard'),
                                          duration: Duration(seconds: 2),
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
                        onPressed: () async {
                          final status = await Permission.microphone.status;
                          if (status.isPermanentlyDenied) {
                            await controller.openSettings();
                          } else {
                            await controller.startSharing();
                          }
                        },
                        icon: const Icon(Icons.settings_rounded, size: 16),
                        label: const Text('Open Settings / Retry Permission'),
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
                              'Incoming Connection Request',
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
                              'Waiting for friend...',
                              style: TextStyle(color: Colors.grey, fontSize: 12),
                            ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      if (controller.participants.isEmpty)
                        Container(
                          padding: const EdgeInsets.all(20),
                          alignment: Alignment.center,
                          child: Column(
                            children: [
                              const Icon(Icons.headphones_rounded,
                                  size: 36, color: Colors.grey),
                              const SizedBox(height: 8),
                              Text(
                                'Share your Session ID or QR code with a friend',
                                textAlign: TextAlign.center,
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
                                backgroundColor: Color(0xFF6366F1),
                                foregroundColor: Colors.white,
                                child: Icon(Icons.person, size: 20),
                              ),
                              title: Text(participant.name),
                              subtitle:
                                  Text('Status: ${participant.status.name}'),
                              trailing: const Icon(
                                Icons.check_circle_rounded,
                                color: Colors.green,
                                size: 20,
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
