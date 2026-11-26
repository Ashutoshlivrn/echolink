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

class _ReceiverScreenState extends State<ReceiverScreen>
    with SingleTickerProviderStateMixin {
  final TextEditingController _sessionInputController = TextEditingController();
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;
  bool _showGuide = true;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.5, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _sessionInputController.dispose();
    _pulseController.dispose();
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
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // First-Time Friend Walkthrough Guide Banner
              if (_showGuide && !isConnected) ...[
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.teal.shade50,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.teal.shade300),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.lightbulb_rounded,
                              color: Colors.teal.shade800, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Friend Walkthrough Guide',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              color: Colors.teal.shade900,
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
                      Text(
                        '1. Ask your friend for their 6-letter Session ID (or scan their QR code).\n'
                        '2. Enter the code and tap Join Session.\n'
                        '3. Once the host accepts your request, audio streams directly into your earphones!',
                        style: TextStyle(
                            fontSize: 13, height: 1.4, color: Colors.teal.shade900),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

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
                      isWaiting || isConnecting
                          ? FadeTransition(
                              opacity: _pulseAnimation,
                              child: CircleAvatar(
                                radius: 32,
                                backgroundColor: Colors.orange.shade100,
                                child: Icon(
                                  isWaiting
                                      ? Icons.hourglass_bottom_rounded
                                      : Icons.hourglass_top_rounded,
                                  size: 32,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            )
                          : CircleAvatar(
                              radius: 32,
                              backgroundColor: isConnected
                                  ? Colors.green.shade100
                                  : theme.colorScheme.primaryContainer,
                              child: Icon(
                                isConnected
                                    ? Icons.headphones_rounded
                                    : Icons.podcasts_rounded,
                                size: 32,
                                color: isConnected
                                    ? Colors.green.shade800
                                    : theme.colorScheme.primary,
                              ),
                            ),
                      const SizedBox(height: 16),
                      Text(
                        isConnected
                            ? 'Streaming Audio Live'
                            : isWaiting
                                ? 'Waiting for Host Approval...'
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

              // Signaling / Connection Error Banner
              if (controller.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade300),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline, color: Colors.red.shade800),
                      const SizedBox(width: 10),
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

              // Join Session Input (when not connected and not waiting)
              if (!isConnected && !isWaiting && !isConnecting) ...[
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
                        Text(
                          'Session Code',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextField(
                          controller: _sessionInputController,
                          textCapitalization: TextCapitalization.characters,
                          maxLength: 6,
                          decoration: InputDecoration(
                            hintText: 'e.g. A4B9X2',
                            prefixIcon: const Icon(Icons.vpn_key_rounded),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            counterText: '',
                          ),
                        ),
                        const SizedBox(height: 14),
                        CustomButton(
                          text: 'Join Session',
                          icon: Icons.login_rounded,
                          onPressed: () {
                            final code = _sessionInputController.text.trim();
                            if (code.length == 6) {
                              controller.joinSession(code);
                            } else {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                      'Please enter a valid 6-letter Session ID'),
                                ),
                              );
                            }
                          },
                        ),
                        const SizedBox(height: 8),
                        Center(
                          child: TextButton.icon(
                            onPressed: _scanQrCode,
                            icon: const Icon(Icons.qr_code_scanner_rounded),
                            label: const Text('Or Scan QR Code'),
                          ),
                        ),
                      ],
                    ),
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
        content: const Text('You will stop receiving audio from the host device.'),
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
