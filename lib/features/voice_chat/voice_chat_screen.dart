import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../services/voice_chat_controller.dart';
import '../../widgets/custom_button.dart';

class VoiceChatScreen extends StatelessWidget {
  const VoiceChatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => VoiceChatController(),
      child: const _VoiceChatView(),
    );
  }
}

class _VoiceChatView extends StatefulWidget {
  const _VoiceChatView();

  @override
  State<_VoiceChatView> createState() => _VoiceChatViewState();
}

class _VoiceChatViewState extends State<_VoiceChatView> {
  final TextEditingController _roomInputController = TextEditingController();

  @override
  void dispose() {
    _roomInputController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final controller = context.watch<VoiceChatController>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) async {
        if (!didPop) {
          await controller.leaveRoom();
          if (context.mounted) Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Voice Chat Only (Microphone Test)'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              await controller.leaveRoom();
              if (context.mounted) Navigator.of(context).pop();
            },
          ),
        ),
        body: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Status Card
              Card(
                elevation: 2,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Icon(
                        controller.isConnected
                            ? Icons.mic_rounded
                            : controller.sessionId != null
                                ? Icons.hourglass_top_rounded
                                : Icons.mic_none_rounded,
                        size: 56,
                        color: controller.isConnected
                            ? Colors.green
                            : controller.sessionId != null
                                ? Colors.orange
                                : theme.colorScheme.primary,
                      ),
                      const SizedBox(height: 16),
                      Text(
                        controller.isConnected
                            ? 'Voice Chat Connected (Live)'
                            : controller.sessionId != null
                                ? 'Waiting for Participant...'
                                : 'Start or Join Voice Room',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        controller.isConnected
                            ? (controller.isRemoteSpeaking
                                ? '🎙️ Remote voice active & playing'
                                : 'Connected — speak into your microphone')
                            : 'Test pure microphone-to-microphone WebRTC streaming',
                        style: const TextStyle(color: Colors.grey, fontSize: 13),
                        textAlign: TextAlign.center,
                      ),
                      if (controller.sessionId != null) ...[
                        const SizedBox(height: 20),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primaryContainer.withValues(alpha: 0.3),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                'ROOM ID: ${controller.sessionId}',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 3,
                                ),
                              ),
                              const SizedBox(width: 12),
                              IconButton(
                                icon: const Icon(Icons.copy_rounded, size: 20),
                                onPressed: () {
                                  Clipboard.setData(ClipboardData(text: controller.sessionId!));
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Room ID copied to clipboard')),
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Error display
              if (controller.errorMessage != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.shade200),
                  ),
                  child: Text(
                    controller.errorMessage!,
                    style: TextStyle(color: Colors.red.shade900),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Controls when connected
              if (controller.isConnected) ...[
                Card(
                  elevation: 1,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Microphone Mute',
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        Switch(
                          value: !controller.isMicMuted,
                          onChanged: (_) => controller.toggleMute(),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
              ],

              // Join Room Section (if not in room)
              if (controller.sessionId == null) ...[
                CustomButton(
                  text: 'Start Voice Room (Host)',
                  icon: Icons.podcasts_rounded,
                  onPressed: () => controller.startVoiceRoom(context),
                ),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 20),
                TextField(
                  controller: _roomInputController,
                  textCapitalization: TextCapitalization.characters,
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold, letterSpacing: 3),
                  textAlign: TextAlign.center,
                  decoration: InputDecoration(
                    labelText: 'ROOM ID',
                    hintText: 'e.g. A9F2K4',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
                const SizedBox(height: 16),
                CustomButton(
                  text: 'Join Voice Room',
                  icon: Icons.login_rounded,
                  isSecondary: true,
                  onPressed: () => controller.joinVoiceRoom(context, _roomInputController.text),
                ),
              ] else ...[
                CustomButton(
                  text: 'Leave Room',
                  icon: Icons.logout_rounded,
                  isDestructive: true,
                  onPressed: () => controller.leaveRoom(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
